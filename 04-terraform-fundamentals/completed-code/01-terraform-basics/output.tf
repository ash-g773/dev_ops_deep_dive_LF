output "my_storage_account_versioning" {
  value = azurerm_storage_account.my_storage_account.blob_properties[0].versioning_enabled
}

output "my_storage_account_complete_details" {
  value     = azurerm_storage_account.my_storage_account
  sensitive = true
}