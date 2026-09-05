resource "azurerm_network_security_group" "http_server_nsg" {
  name                = "http-server-nsg"
  location            = azurerm_resource_group.vm_resource_group.location
  resource_group_name = azurerm_resource_group.vm_resource_group.name
  tags = {
    name = "http-server-nsg"
  }
}

resource "azurerm_network_security_rule" "http_ingress" {
  name                        = "AllowHTTP"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "0.0.0.0/0"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.vm_resource_group.name
  network_security_group_name = azurerm_network_security_group.http_server_nsg.name
}

resource "azurerm_network_security_rule" "ssh_ingress" {
  name                        = "AllowSSH"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "0.0.0.0/0"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.vm_resource_group.name
  network_security_group_name = azurerm_network_security_group.http_server_nsg.name
}
