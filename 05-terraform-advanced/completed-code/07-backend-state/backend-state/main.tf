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

resource "azurerm_resource_group" "backend_resource_group" {
  name     = "rg-backend-state-emilesherrott-devops"
  location = "uksouth"
}

resource "azurerm_storage_account" "organisation_backend_state" {
  name                     = "stdevappsbackendesherr"
  resource_group_name      = azurerm_resource_group.backend_resource_group.name
  location                 = azurerm_resource_group.backend_resource_group.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  blob_properties {
    versioning_enabled = true
  }
}

resource "azurerm_storage_container" "tfstate_container" {
  name                  = "tfstate"
  storage_account_name  = azurerm_storage_account.organisation_backend_state.name
  container_access_type = "private"
}