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

provider "azuread" {

}

variable "iam_user_name_prefix" {
  type    = string
  default = "my_iam_user"
}