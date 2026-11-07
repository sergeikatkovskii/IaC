variable "name" {
  type        = string
  description = "Globally unique, 3-24 characters."

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]{1,22}[a-zA-Z0-9]$", var.name))
    error_message = "A vault name is 3-24 letters, digits and hyphens, starting with a letter."
  }
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "tenant_id" {
  type = string
}

variable "allowed_subnet_ids" {
  type        = list(string)
  description = "Subnets admitted through the firewall: the cluster's nodes."
  default     = []
}

variable "operator_ip_ranges" {
  type        = list(string)
  description = "Addresses a person writes the vault's values from. An address, or a range in CIDR form."
  default     = []

  validation {
    condition     = alltrue([for r in var.operator_ip_ranges : !can(regex("REPLACE", upper(r)))])
    error_message = "operator_ip_ranges still holds a REPLACE placeholder: put the address the vault's values are written from."
  }

  validation {
    condition     = alltrue([for r in var.operator_ip_ranges : can(cidrhost(strcontains(r, "/") ? r : "${r}/32", 0))])
    error_message = "Each operator_ip_ranges entry is an IPv4 address or a range in CIDR form."
  }
}

variable "reader_principal_ids" {
  type        = map(string)
  description = "name => principal id that reads secrets (Key Vault Secrets User)."
  default     = {}
}

variable "writer_principal_ids" {
  type        = map(string)
  description = "name => principal id that writes secrets (Key Vault Secrets Officer)."
  default     = {}
}

variable "soft_delete_retention_days" {
  type    = number
  default = 90
}

variable "rbac_propagation_seconds" {
  type        = number
  description = "A role assignment takes up to a minute to reach the vault; a secret written sooner is refused."
  default     = 60
}

variable "tags" {
  type    = map(string)
  default = {}
}
