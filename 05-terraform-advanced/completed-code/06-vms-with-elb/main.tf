terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "vm_resource_group" {
  name     = "rg-vm-emilesherrott-devops"
  location = "swedencentral"
}

resource "azurerm_virtual_network" "vm_vnet" {
  name                = "vnet-emilesherrott-devops"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.vm_resource_group.location
  resource_group_name = azurerm_resource_group.vm_resource_group.name
}

resource "azurerm_subnet" "public_subnets" {
  for_each             = { "1" = "10.0.1.0/24", "2" = "10.0.2.0/24" }
  name                 = "subnet-public-${each.key}"
  resource_group_name  = azurerm_resource_group.vm_resource_group.name
  virtual_network_name = azurerm_virtual_network.vm_vnet.name
  address_prefixes     = [each.value]
}

# --- One public IP and NIC per subnet ---

resource "azurerm_public_ip" "http_server_pips" {
  for_each            = azurerm_subnet.public_subnets
  name                = "pip-http-server-${each.key}"
  location            = azurerm_resource_group.vm_resource_group.location
  resource_group_name = azurerm_resource_group.vm_resource_group.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "http_server_nics" {
  for_each            = azurerm_subnet.public_subnets
  name                = "nic-http-server-${each.key}"
  location            = azurerm_resource_group.vm_resource_group.location
  resource_group_name = azurerm_resource_group.vm_resource_group.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = each.value.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.http_server_pips[each.key].id
  }
}

resource "azurerm_network_interface_security_group_association" "http_server_nics_nsg" {
  for_each                  = azurerm_network_interface.http_server_nics
  network_interface_id      = each.value.id
  network_security_group_id = azurerm_network_security_group.http_server_nsg.id
}

# --- Three VMs, one per subnet ---

resource "azurerm_linux_virtual_machine" "http_servers" {
  for_each              = azurerm_subnet.public_subnets
  name                  = "http-server-${each.key}"
  resource_group_name   = azurerm_resource_group.vm_resource_group.name
  location              = azurerm_resource_group.vm_resource_group.location
  size                  = "Standard_B2als_v2"
  admin_username        = "azureuser"
  network_interface_ids = [azurerm_network_interface.http_server_nics[each.key].id]

  admin_ssh_key {
    username   = "azureuser"
    public_key = file(var.azure_ssh_public_key)
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = data.azurerm_platform_image.ubuntu_latest.version
  }

  tags = {
    name = "http-server-${each.key}"
  }

  connection {
    type        = "ssh"
    host        = azurerm_public_ip.http_server_pips[each.key].ip_address
    user        = "azureuser"
    private_key = file(var.azure_ssh_private_key)
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update -y",
      "sudo apt-get install apache2 -y",
      "sudo systemctl start apache2",
      "echo Welcome - Virtual Server ${each.key} is at ${azurerm_public_ip.http_server_pips[each.key].ip_address} | sudo tee /var/www/html/index.html"
    ]
  }
}

# --- Load balancer ---

resource "azurerm_public_ip" "lb_pip" {
  name                = "pip-lb"
  location            = azurerm_resource_group.vm_resource_group.location
  resource_group_name = azurerm_resource_group.vm_resource_group.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_lb" "lb" {
  name                = "lb"
  location            = azurerm_resource_group.vm_resource_group.location
  resource_group_name = azurerm_resource_group.vm_resource_group.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "lb-frontend"
    public_ip_address_id = azurerm_public_ip.lb_pip.id
  }
}

resource "azurerm_lb_backend_address_pool" "lb_backend_pool" {
  loadbalancer_id = azurerm_lb.lb.id
  name            = "http-servers-pool"
}

resource "azurerm_network_interface_backend_address_pool_association" "http_server_nics_pool" {
  for_each                = azurerm_network_interface.http_server_nics
  network_interface_id    = each.value.id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.lb_backend_pool.id
}

resource "azurerm_lb_probe" "http_probe" {
  loadbalancer_id = azurerm_lb.lb.id
  name            = "http-probe"
  port            = 80
  protocol        = "Http"
  request_path    = "/"
}

resource "azurerm_lb_rule" "http_rule" {
  loadbalancer_id                = azurerm_lb.lb.id
  name                           = "http-rule"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "lb-frontend"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.lb_backend_pool.id]
  probe_id                       = azurerm_lb_probe.http_probe.id
}