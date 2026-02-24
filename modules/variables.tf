variable "values_path" {
  description = "Path to the values YAML file"
  type        = string

  validation {
    condition     = can(regex("\\.(ya?ml)$", var.values_path))
    error_message = "The values_path must point to a YAML file (.yaml or .yml)."
  }
}

variable "POSTGRESQL_USERNAME" {
  description = "PostgreSQL Username"
  type        = string
  default     = "postgres"
}

variable "POSTGRESQL_PASSWORD" {
  description = "PostgreSQL Password"
  type        = string
  default     = ""
  sensitive   = true
}

variable "POSTGRESQL_DATABASE" {
  description = "PostgreSQL Database"
  type        = string
  default     = "app"
}

variable "POSTGRESQL_REPLICATION_PASSWORD" {
  description = "PostgreSQL Replication Password"
  type        = string
  default     = ""
  sensitive   = true
}

variable "REDIS_PASSWORD" {
  description = "Redis Password (leave empty for no authentication)"
  type        = string
  default     = ""
  sensitive   = true
}
