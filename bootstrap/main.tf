terraform {
  required_version = ">= 1.7.0"
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

variable "location" {
  description = "Azure region"
  type        = string
  default     = "australiacentral"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "gopal"
}

# Resource Group for Terraform State
resource "azurerm_resource_group" "tfstate" {
  name     = "rg-${var.project_name}-tfstate"
  location = var.location

  tags = {
    environment = "shared"
    project     = "${var.project_name}-capstone"
    managed_by  = "terraform"
  }
}

# Storage Account for Terraform State
resource "azurerm_storage_account" "tfstate" {
  name                     = "st${var.project_name}tfstate"
  resource_group_name      = azurerm_resource_group.tfstate.name
  location                 = azurerm_resource_group.tfstate.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"

  tags = {
    environment = "shared"
    project     = "${var.project_name}-capstone"
    managed_by  = "terraform"
  }
}

# Container for Terraform State Files
resource "azurerm_storage_container" "tfstate" {
  name                  = "tfstate-${var.project_name}"
  storage_account_name  = azurerm_storage_account.tfstate.name
  container_access_type = "private"
}

output "storage_account_name" {
  value = azurerm_storage_account.tfstate.name
}

output "container_name" {
  value = azurerm_storage_container.tfstate.name
}

output "resource_group_name" {
  value = azurerm_resource_group.tfstate.name
}
