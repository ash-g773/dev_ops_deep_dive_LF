terraform {
  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "rg-backend-state-emilesherrott-devops"
    storage_account_name = "stdevappsbackendesherr"
    container_name       = "tfstate"
    key = "dev/07-backend-state/users/backend-state.tfstate"
  }
}

provider "azuread" {}


# REMEMBER: YOUR tenant domain, not mine
resource "azuread_user" "my_azuread_user" {
  user_principal_name = "my_iam_user_def@emilesherrottgmail.onmicrosoft.com"
  display_name        = "my_iam_user_def"
  mail_nickname       = "my_iam_user_def"
  password            = "ChangeMe123!ChangeMe"
}