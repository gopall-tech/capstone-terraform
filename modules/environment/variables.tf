variable "env_name" {
  description = "Environment name (dev, qa, prod)"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "aks_node_count" {
  description = "Number of nodes in AKS cluster"
  type        = number
  default     = 2
}

variable "aks_vm_size" {
  description = "VM size for AKS nodes"
  type        = string
  default     = "Standard_DS2_v2"
}

variable "postgres_admin_login" {
  description = "PostgreSQL admin username"
  type        = string
}

variable "postgres_admin_password" {
  description = "PostgreSQL admin password"
  type        = string
  sensitive   = true
}

variable "apim_publisher_name" {
  description = "API Management publisher name"
  type        = string
}

variable "apim_publisher_email" {
  description = "API Management publisher email"
  type        = string
}
