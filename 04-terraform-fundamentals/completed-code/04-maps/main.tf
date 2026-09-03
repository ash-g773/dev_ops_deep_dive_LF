terraform {
  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
  }
}

provider "azuread" {}

# UPDATED — square brackets [ ] become curly braces { }
variable "users" {
  default = {
    emile : { country: "England", department: "Training" },
    monia : { country : "Brazil", department: "Training" }
  }
}

resource "azuread_user" "my_azuread_users" {
  for_each            = var.users
  user_principal_name = "${each.key}@emilesherrottgmail.onmicrosoft.com"
  display_name        = each.key
  mail_nickname       = each.key
  password            = "ChangeMe123!ChangeMe"
  country             = each.value.country
  department = each.value.department
}