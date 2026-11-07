variable "name" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "dns_zone_name" {
  type        = string
  description = "A zone this subscription serves, or empty to manage DNS elsewhere (KAT-648 §8 Q2)."
  default     = ""
}

variable "app_host" {
  type        = string
  description = "The product's address (KAT-648 §8 Q2)."

  validation {
    condition     = !can(regex("(^|[/_.-])REPLACE([/_.-]|$)", var.app_host))
    error_message = "app_host is still a placeholder: the address is the founder's answer to KAT-648 §8 Q2."
  }

  validation {
    condition     = var.dns_zone_name == "" || var.app_host == var.dns_zone_name || endswith(var.app_host, ".${var.dns_zone_name}")
    error_message = "app_host must be inside dns_zone_name."
  }
}

variable "mcp_host" {
  type        = string
  description = "The MCP host's address (KAT-648 §8 Q2)."

  validation {
    condition     = !can(regex("(^|[/_.-])REPLACE([/_.-]|$)", var.mcp_host))
    error_message = "mcp_host is still a placeholder: the address is the founder's answer to KAT-648 §8 Q2."
  }

  validation {
    condition     = var.dns_zone_name == "" || var.mcp_host == var.dns_zone_name || endswith(var.mcp_host, ".${var.dns_zone_name}")
    error_message = "mcp_host must be inside dns_zone_name."
  }
}

variable "admin_host" {
  type        = string
  description = "The operator console's address (KAT-648 §8 Q2): one more name on the certificate, and one more route."

  validation {
    condition     = !can(regex("(^|[/_.-])REPLACE([/_.-]|$)", var.admin_host))
    error_message = "admin_host is still a placeholder: the address is the founder's answer to KAT-648 §8 Q2."
  }

  validation {
    condition     = var.dns_zone_name == "" || var.admin_host == var.dns_zone_name || endswith(var.admin_host, ".${var.dns_zone_name}")
    error_message = "admin_host must be inside dns_zone_name."
  }
}

variable "cluster_principal_id" {
  type        = string
  description = "The cluster's own identity, which attaches its load balancer to this address."
}

variable "tags" {
  type    = map(string)
  default = {}
}
