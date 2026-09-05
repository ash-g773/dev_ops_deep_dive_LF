output "my_azuread_user_complete_details" {
  value     = azuread_user.my_azuread_user
  sensitive = true
}