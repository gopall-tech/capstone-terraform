terraform {
  required_version = ">= 1.7.0"

  backend "azurerm" {
    resource_group_name  = "rg-gopal-tfstate"
    storage_account_name = "stgopaltfstate"
    container_name       = "tfstate-gopal"
    key                  = "gopal-qa.tfstate"
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

module "qa_environment" {
  source = "../../modules/environment"

  env_name                = "qa"
  location                = var.location
  aks_node_count          = 2
  aks_vm_size             = "Standard_DS2_v2"
  postgres_admin_login    = var.postgres_admin_login
  postgres_admin_password = var.postgres_admin_password
  apim_publisher_name     = var.apim_publisher_name
  apim_publisher_email    = var.apim_publisher_email
}

output "qa_outputs" {
  value = {
    resource_group   = module.qa_environment.resource_group_name
    aks_name         = module.qa_environment.aks_name
    acr_login_server = module.qa_environment.acr_login_server
    postgres_fqdn    = module.qa_environment.postgres_fqdn
    app_service_url  = "https://${module.qa_environment.app_service_default_hostname}"
    apim_gateway_url = module.qa_environment.apim_gateway_url
  }
}
