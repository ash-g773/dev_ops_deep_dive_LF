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
  for_each             = { "1" = "10.0.1.0/24", "2" = "10.0.2.0/24", "3" = "10.0.3.0/24" }
  name                 = "subnet-public-${each.key}"
  resource_group_name  = azurerm_resource_group.vm_resource_group.name
  virtual_network_name = azurerm_virtual_network.vm_vnet.name
  address_prefixes     = [each.value]
}



resource "azurerm_public_ip" "http_server_pip" {
  name                = "pip-http-server"
  location            = azurerm_resource_group.vm_resource_group.location
  resource_group_name = azurerm_resource_group.vm_resource_group.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "http_server_nic" {
  name                = "nic-http-server"
  location            = azurerm_resource_group.vm_resource_group.location
  resource_group_name = azurerm_resource_group.vm_resource_group.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.public_subnets["1"].id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.http_server_pip.id
  }
}

resource "azurerm_network_interface_security_group_association" "http_server_nic_nsg" {
  network_interface_id      = azurerm_network_interface.http_server_nic.id
  network_security_group_id = azurerm_network_security_group.http_server_nsg.id
}

# NEW CONFIG
resource "azurerm_linux_virtual_machine" "http_server" {
  name                  = "http-server"
  resource_group_name   = azurerm_resource_group.vm_resource_group.name
  location              = azurerm_resource_group.vm_resource_group.location
  size                  = "Standard_B2als_v2"
  admin_username        = "azureuser"
  network_interface_ids = [azurerm_network_interface.http_server_nic.id]

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

  connection {
    type        = "ssh"
    host        = azurerm_public_ip.http_server_pip.ip_address
    user        = "azureuser"
    private_key = file(var.azure_ssh_private_key)
  }

provisioner "remote-exec" {
  inline = [
    "sudo apt-get update -y",
    "sudo apt-get install apache2 -y",
    "sudo systemctl start apache2",


    "echo '<h1>Welcome to http-server</h1>' | sudo tee /var/www/html/index.html",
    "echo '<p>This server is at ${azurerm_public_ip.http_server_pip.ip_address} and was provisioned on '$(date)'</p>' | sudo tee -a /var/www/html/index.html",

    "echo OK | sudo tee /var/www/html/health.html"
  ]
}
}



