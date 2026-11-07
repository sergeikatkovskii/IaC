# One environment's values. envs/staging and envs/production set these from their
# own terraform.tfvars; nothing else about the two differs.

variable "environment" {
  type        = string
  description = "KAT-S10's ENVIRONMENT: a development cluster is staging."

  validation {
    condition     = contains(["staging", "production"], var.environment)
    error_message = "environment must be staging or production (KAT-S10)."
  }
}

variable "subscription_name" {
  type        = string
  description = "The subscription this environment lives in, by its name (KAT-648 §8 Q1: staging AZ2-NonProd, production AZ1-TCM, as Azure names them). Nothing is planned in any other."
}

variable "location" {
  type        = string
  description = "Azure region (KAT-648 §8 Q1; centralus recommended)."
  default     = "centralus"
}

variable "resource_group_name" {
  type = string
}

variable "app_host" {
  type        = string
  description = "The product's address (KAT-648 §8 Q2)."

  validation {
    condition     = !can(regex("(^|[/_.-])REPLACE([/_.-]|$)", var.app_host))
    error_message = "app_host is still a placeholder: the address is the founder's answer to KAT-648 §8 Q2."
  }
}

variable "mcp_host" {
  type        = string
  description = "The MCP host's address (KAT-648 §8 Q2)."

  validation {
    condition     = !can(regex("(^|[/_.-])REPLACE([/_.-]|$)", var.mcp_host))
    error_message = "mcp_host is still a placeholder: the address is the founder's answer to KAT-648 §8 Q2."
  }
}

variable "admin_host" {
  type        = string
  description = "The operator console's address (KAT-648 §8 Q2)."

  validation {
    condition     = !can(regex("(^|[/_.-])REPLACE([/_.-]|$)", var.admin_host))
    error_message = "admin_host is still a placeholder: the address is the founder's answer to KAT-648 §8 Q2."
  }
}

variable "dns_zone_name" {
  type        = string
  description = "A zone this subscription serves, or empty when DNS is managed elsewhere."
  default     = ""
}

variable "operator_ip_ranges" {
  type        = list(string)
  description = "Addresses a person writes the vault's values and runs Terraform from."

  validation {
    condition     = alltrue([for r in var.operator_ip_ranges : !can(regex("REPLACE", upper(r)))])
    error_message = "operator_ip_ranges still holds a REPLACE placeholder."
  }
}

variable "first_boot_open" {
  type        = bool
  description = "True only while first boot runs; db-bootstrap can sign in only then (KAT-648 §8 Q10)."
  default     = false
}

variable "postgres_sku_name" {
  type        = string
  description = "KAT-648 §8 Q3: at least B2s, because B1ms's 35 user connections cannot hold the pools."
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
  description = "The Kubernetes minor (\"1.35\"), or null for AKS's default. The patch channel keeps it current; a minor moves with minikube's profile and the pipeline's kubectl (KAT-648 T-005)."
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
  description = "Who administers the cluster: runs the platform playbook and grants rights. Empty: whoever runs the apply."
  default     = []
}

variable "registry_sku" {
  type    = string
  default = "Basic"
}

variable "github_repository" {
  type    = string
  default = "sergeikatkovskii/tcm"
}

variable "log_retention_days" {
  type    = number
  default = 30
}

variable "log_daily_quota_gb" {
  type    = number
  default = 1
}

# ── storage-detection (KAT-417), unchanged in meaning ─────────────────────────

variable "enable_sas_alert" {
  type    = bool
  default = true
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
  type    = bool
  default = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
