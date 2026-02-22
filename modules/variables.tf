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

  validation {
    condition     = length(var.POSTGRESQL_USERNAME) > 0
    error_message = "PostgreSQL username must not be empty."
  }
}

variable "POSTGRESQL_PASSWORD" {
  description = "PostgreSQL Password"
  type        = string
  sensitive   = true
}

variable "POSTGRESQL_DATABASE" {
  description = "PostgreSQL Database"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]*$", var.POSTGRESQL_DATABASE))
    error_message = "Database name must start with a letter and contain only alphanumeric characters and underscores."
  }
}

variable "POSTGRESQL_REPLICATION_PASSWORD" {
  description = "PostgreSQL Replication Password"
  type        = string
  sensitive   = true
}

variable "REDIS_PASSWORD" {
  description = "Redis Password (leave empty for no authentication)"
  type        = string
  default     = ""
  sensitive   = true
}
