terraform {
  required_version = ">= 1.7.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
  }
}

locals {
  # Resource naming
  rg_name        = "rg-gopal-${var.env_name}"
  aks_name       = "aks-gopal-${var.env_name}"
  acr_name       = "gopal${var.env_name}acr"
  pg_server_name = "gopalpg${var.env_name}"
  pg_db_name     = "gopalapp${var.env_name}"
  app_plan_name  = "asp-gopal-${var.env_name}"
  app_name       = "app-gopal-ui-${var.env_name}"
  apim_name      = "apim-gopal-${var.env_name}"

  # Common tags
  common_tags = {
    environment = var.env_name
    project     = "gopal-capstone"
    owner       = "gopal"
    managed_by  = "terraform"
  }
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = local.rg_name
  location = var.location
  tags     = local.common_tags
}

# Azure Container Registry
resource "azurerm_container_registry" "main" {
  name                = local.acr_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Basic"
  admin_enabled       = true

  tags = local.common_tags
}

# AKS Cluster
resource "azurerm_kubernetes_cluster" "main" {
  name                = local.aks_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = "gopal-${var.env_name}"

  default_node_pool {
    name       = "default"
    node_count = var.aks_node_count
    vm_size    = var.aks_vm_size
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin = "azure"
    network_policy = "azure"
  }

  tags = local.common_tags
}

# Grant AKS access to ACR
resource "azurerm_role_assignment" "aks_acr" {
  principal_id                     = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.main.id
  skip_service_principal_aad_check = true
}

# PostgreSQL Flexible Server
resource "azurerm_postgresql_flexible_server" "main" {
  name                   = local.pg_server_name
  resource_group_name    = azurerm_resource_group.main.name
  location               = azurerm_resource_group.main.location
  version                = "15"
  administrator_login    = var.postgres_admin_login
  administrator_password = var.postgres_admin_password
  storage_mb             = 32768
  sku_name               = "B_Standard_B1ms"

  tags = local.common_tags
}

# PostgreSQL Firewall Rule - Allow Azure Services
resource "azurerm_postgresql_flexible_server_firewall_rule" "azure_services" {
  name             = "allow-azure-services"
  server_id        = azurerm_postgresql_flexible_server.main.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# PostgreSQL Database
resource "azurerm_postgresql_flexible_server_database" "main" {
  name      = local.pg_db_name
  server_id = azurerm_postgresql_flexible_server.main.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

# App Service Plan
resource "azurerm_service_plan" "main" {
  name                = local.app_plan_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  os_type             = "Linux"
  sku_name            = "B1"

  tags = local.common_tags
}

# Linux Web App (Frontend)
resource "azurerm_linux_web_app" "main" {
  name                = local.app_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_service_plan.main.location
  service_plan_id     = azurerm_service_plan.main.id

  site_config {
    always_on = false

    application_stack {
      docker_image     = "${azurerm_container_registry.main.login_server}/gopal-frontend"
      docker_image_tag = var.env_name
    }
  }

  app_settings = {
    DOCKER_REGISTRY_SERVER_URL          = "https://${azurerm_container_registry.main.login_server}"
    DOCKER_REGISTRY_SERVER_USERNAME     = azurerm_container_registry.main.admin_username
    DOCKER_REGISTRY_SERVER_PASSWORD     = azurerm_container_registry.main.admin_password
    WEBSITES_ENABLE_APP_SERVICE_STORAGE = "false"
  }

  tags = local.common_tags
}

# API Management
resource "azurerm_api_management" "main" {
  name                = local.apim_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  publisher_name      = var.apim_publisher_name
  publisher_email     = var.apim_publisher_email
  sku_name            = "Developer_1"

  tags = local.common_tags
}
