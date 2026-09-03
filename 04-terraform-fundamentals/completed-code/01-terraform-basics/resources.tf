resource "azurerm_resource_group" "my_resource_group" {
  name     = "rg-emilesherrott-devops"
  location = "uksouth"
}

resource "azurerm_storage_account" "my_storage_account" {
  name                     = "stemilesherrottdevops06"
  resource_group_name      = azurerm_resource_group.my_resource_group.name
  location                 = azurerm_resource_group.my_resource_group.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  blob_properties {
    versioning_enabled = true
  }
}


resource "azuread_user" "my_azuread_user" {
  user_principal_name = "${var.iam_user_name_prefix}@emilesherrottgmail.onmicrosoft.com"
  display_name        = var.iam_user_name_prefix
  mail_nickname       = "${var.iam_user_name_prefix}f"
  password            = "ChangeMe123!ChangeMe"
}