output "terraform_state_storage_account" {
  description = "Storage account name for Terraform state"
  value       = azurerm_storage_account.tfstate.name
}

output "terraform_state_container" {
  description = "Container name for Terraform state files"
  value       = azurerm_storage_container.tfstate.name
}

output "resource_group" {
  description = "Resource group containing Terraform state storage"
  value       = azurerm_resource_group.tfstate.name
}
