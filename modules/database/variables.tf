variable "name" {
  type        = string
  description = "Globally unique, 3-63 lowercase letters, digits and hyphens."

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", var.name))
    error_message = "A server name is 3-63 lowercase letters, digits and hyphens."
  }
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "sku_name" {
  type        = string
  description = "A tier whose user-connection limit has been measured (KAT-648 §8 Q3). B2s allows 414; the manifests can open 120."
  default     = "B_Standard_B2s"

  validation {
    condition     = contains(["B_Standard_B1ms", "B_Standard_B2s"], var.sku_name)
    error_message = "Only a tier whose connection limit was measured: B_Standard_B1ms (35) or B_Standard_B2s (414). Measure a new tier and add it to max_user_connections first."
  }
}

variable "postgres_version" {
  type        = string
  description = "The development database's major version (15, measured 2026-11-05), so what is tested is what runs."
  default     = "15"
}

variable "storage_mb" {
  type    = number
  default = 32768
}

variable "backup_retention_days" {
  type    = number
  default = 7

  validation {
    condition     = var.backup_retention_days >= 7 && var.backup_retention_days <= 35
    error_message = "backup_retention_days must be between 7 and 35."
  }
}

variable "delegated_subnet_id" {
  type = string
}

variable "private_dns_zone_id" {
  type = string
}

variable "admin_login" {
  type    = string
  default = "katachiadmin"
}

variable "admin_password_version" {
  type        = number
  description = "Raise by one to rotate the administrator's password. The new value goes to the server and the vault in the same apply."
  default     = 1
}

variable "admin_vault_id" {
  type        = string
  description = "The vault only db-bootstrap reads. Never the units' vault."
}

variable "admin_secret_name" {
  type    = string
  default = "db-admin-password"
}

variable "tags" {
  type    = map(string)
  default = {}
}
