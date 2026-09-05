data "azurerm_platform_image" "ubuntu_latest" {
  location  = azurerm_resource_group.vm_resource_group.location
  publisher = "Canonical"
  offer     = "ubuntu-24_04-lts"
  sku       = "server"
}