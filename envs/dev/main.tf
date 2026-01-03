terraform {
  required_version = ">= 1.7.0"

  backend "azurerm" {
    resource_group_name  = "rg-gopal-tfstate"
    storage_account_name = "stgopaltfstate"
    container_name       = "tfstate-gopal"
    key                  = "gopal-dev.tfstate"
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
  }
}

provider "azurerm" {
  features {}
}

module "dev_environment" {
  source = "../../modules/environment"

  env_name                = "dev"
  location                = var.location
  aks_node_count          = 2
  aks_vm_size             = "Standard_DS2_v2"
  postgres_admin_login    = var.postgres_admin_login
  postgres_admin_password = var.postgres_admin_password
  apim_publisher_name     = var.apim_publisher_name
  apim_publisher_email    = var.apim_publisher_email
}

output "dev_outputs" {
  value = {
    resource_group   = module.dev_environment.resource_group_name
    aks_name         = module.dev_environment.aks_name
    acr_login_server = module.dev_environment.acr_login_server
    postgres_fqdn    = module.dev_environment.postgres_fqdn
    app_service_url  = "https://${module.dev_environment.app_service_default_hostname}"
    apim_gateway_url = module.dev_environment.apim_gateway_url
  }
}
