variable "location" {
  description = "Azure region"
  type        = string
  default     = "australiacentral"
}

variable "postgres_admin_login" {
  description = "PostgreSQL admin username"
  type        = string
  default     = "gopalpgadmindev"
}

variable "postgres_admin_password" {
  description = "PostgreSQL admin password"
  type        = string
  sensitive   = true
}

variable "apim_publisher_name" {
  description = "API Management publisher name"
  type        = string
  default     = "Gopal Walia"
}

variable "apim_publisher_email" {
  description = "API Management publisher email"
  type        = string
  default     = "gopal@example.com"
}
