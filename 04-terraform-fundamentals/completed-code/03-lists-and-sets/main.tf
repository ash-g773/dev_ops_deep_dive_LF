terraform {
  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
  }
}

provider "azuread" {}

variable "names" {
  default = ["mudathir", "guled"]
}

resource "azuread_user" "my_azuread_users" {

  for_each            = toset(var.names)
  user_principal_name = "${each.value}@emilesherrottgmail.onmicrosoft.com"
  display_name        = each.value
  mail_nickname       = each.value
  password            = "ChangeMe123!ChangeMe"
}