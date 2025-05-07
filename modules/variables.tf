variable "values_path" {
  description = "Path to the values YAML file"
  type        = string
} 

variable "POSTGRESQL_USERNAME" {
  description = "PostgreSQL Username"
  type        = string
}

variable "POSTGRESQL_PASSWORD" {
  description = "PostgreSQL Password"
  type        = string
}

variable "POSTGRESQL_DATABASE" {
  description = "PostgreSQL Database"
  type        = string
}

variable "POSTGRESQL_REPLICATION_PASSWORD" {
  description = "PostgreSQL Replication Password"
  type        = string
}
