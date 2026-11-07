variable "name" {
  type        = string
  description = "Globally unique, 3-24 lowercase letters and digits."

  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.name))
    error_message = "A storage account name is 3-24 lowercase letters and digits."
  }
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "replication_type" {
  type    = string
  default = "LRS"

  validation {
    condition     = contains(["LRS", "ZRS", "GRS", "GZRS"], var.replication_type)
    error_message = "replication_type must be LRS, ZRS, GRS or GZRS."
  }
}

variable "allowed_subnet_ids" {
  type    = list(string)
  default = []
}

variable "operator_ip_ranges" {
  type        = list(string)
  description = "Addresses admitted through the firewall. Azure Storage takes a bare address, not a /31 or /32."
  default     = []

  validation {
    condition     = alltrue([for r in var.operator_ip_ranges : !can(regex("REPLACE", upper(r)))])
    error_message = "operator_ip_ranges still holds a REPLACE placeholder."
  }

  validation {
    condition     = alltrue([for r in var.operator_ip_ranges : can(cidrhost(strcontains(r, "/") ? r : "${r}/32", 0)) && !endswith(r, "/32") && !endswith(r, "/31")])
    error_message = "Each entry is an IPv4 address or a CIDR range of /30 or wider; Azure Storage refuses /31 and /32."
  }
}

variable "container_name" {
  type        = string
  description = "AZURE_STORAGE_CONTAINER_NAME's default in backend/app/core/config.py."
  default     = "tcm-attachments"
}

variable "delete_retention_days" {
  type    = number
  default = 7
}

variable "tags" {
  type    = map(string)
  default = {}
}
