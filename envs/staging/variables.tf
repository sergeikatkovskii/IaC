# Env-root variables. A placeholder is refused here, at the file that holds it,
# before any module sees it (this repository's second rule).

variable "subscription_id" {
  type        = string
  description = "KAT-648 §8 Q1: the founder gives the subscriptions later."

  validation {
    condition     = !can(regex("REPLACE", var.subscription_id))
    error_message = "subscription_id is still a placeholder: the founder gives the subscription (KAT-648 §8 Q1)."
  }

  validation {
    condition     = can(regex("^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", var.subscription_id))
    error_message = "subscription_id is a subscription GUID."
  }
}

variable "subscription_name" {
  type        = string
  description = "KAT-648 §8 Q1: staging lives in AZ2-NonProd. The id is given at run time, never committed; this name is checked against it."
}

variable "location" {
  type        = string
  description = "KAT-648 §8 Q1: centralus recommended."
  default     = "centralus"
}

variable "resource_group_name" {
  type = string
}

variable "app_host" {
  type        = string
  description = "KAT-648 §8 Q2: the product's address."

  validation {
    condition     = !can(regex("(^|[/_.-])REPLACE([/_.-]|$)", var.app_host))
    error_message = "app_host is still a placeholder: the address is the founder's answer to KAT-648 §8 Q2."
  }
}

variable "mcp_host" {
  type        = string
  description = "KAT-648 §8 Q2: the MCP host's address."

  validation {
    condition     = !can(regex("(^|[/_.-])REPLACE([/_.-]|$)", var.mcp_host))
    error_message = "mcp_host is still a placeholder: the address is the founder's answer to KAT-648 §8 Q2."
  }
}

variable "admin_host" {
  type        = string
  description = "KAT-648 §8 Q2: the operator console's address."

  validation {
    condition     = !can(regex("(^|[/_.-])REPLACE([/_.-]|$)", var.admin_host))
    error_message = "admin_host is still a placeholder: the address is the founder's answer to KAT-648 §8 Q2."
  }
}

variable "dns_zone_name" {
  type        = string
  description = "A zone served from this subscription, or empty when DNS lives elsewhere."
  default     = ""
}

variable "operator_ip_ranges" {
  type        = list(string)
  description = "Where a person runs Terraform and writes the vault's values from."

  validation {
    condition     = length(var.operator_ip_ranges) > 0 && alltrue([for r in var.operator_ip_ranges : !can(regex("REPLACE", upper(r)))])
    error_message = "operator_ip_ranges is still a placeholder: list the addresses the vault's values are written from."
  }
}

variable "first_boot_open" {
  type        = bool
  description = "True only while first boot runs (KAT-648 T-004 and §8 Q10); false straight after."
  default     = false
}

variable "postgres_sku_name" {
  type        = string
  description = "KAT-648 §8 Q3."
  default     = "B_Standard_B2s"
}

variable "postgres_admin_password_version" {
  type        = number
  description = "Raise by one to rotate the database administrator's password."
  default     = 1
}

variable "cluster_sku_tier" {
  type    = string
  default = "Free"
}

variable "kubernetes_version" {
  type        = string
  description = "The Kubernetes minor, or null for AKS's default (KAT-648 T-005)."
  default     = null
}

variable "node_vm_size" {
  type    = string
  default = "Standard_D2as_v5"
}

variable "node_min_count" {
  type    = number
  default = 2
}

variable "node_max_count" {
  type    = number
  default = 3
}

variable "cluster_admin_object_ids" {
  type        = list(string)
  description = "Who may install the platform and grant rights in the cluster. Empty: whoever runs the apply."
  default     = []
}

variable "log_retention_days" {
  type    = number
  default = 30
}

variable "log_daily_quota_gb" {
  type    = number
  default = 1
}

variable "enable_sas_alert" {
  type        = bool
  description = "KAT-417's Alert 3: any SAS used at all. On since KAT-417 T-005."
  default     = true
}

variable "alert_email_receivers" {
  type        = map(string)
  description = "name => email address."
  default     = {}
}

variable "alert_webhook_url" {
  type        = string
  description = "Support-channel webhook. Pass via TF_VAR_alert_webhook_url, never a committed file."
  default     = ""
  sensitive   = true
}

variable "skip_query_validation" {
  type        = bool
  description = "True on a first apply: StorageBlobLogs does not exist until the first log lands."
  default     = true
}

variable "power_schedule" {
  type        = bool
  description = "KAT-648 T-005: turned off on a schedule and on demand (staging only)."
  default     = false
}

# KAT-650 T-001: the plan's AI deployment's capacity, in thousands of tokens a minute.
variable "ai_capacity" {
  type        = number
  description = "Drawn from this subscription's Foundry quota for the model (KAT-650 FR10). It costs nothing; tokens do."
}
