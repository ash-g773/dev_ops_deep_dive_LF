terraform {
  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
  }
}

provider "azuread" {}

resource "azuread_user" "my_azuread_users" {
  # NEW CONFIG
  count               = 3
  user_principal_name = "my_iam_user_${count.index}@emilesherrottgmail.onmicrosoft.com"
  display_name        = "my_iam_user_${count.index}"
  mail_nickname       = "my_iam_user_${count.index}"
  password            = "ChangeMe123!ChangeMe"
}