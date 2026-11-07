variable "name" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "dns_prefix" {
  type = string
}

variable "tenant_id" {
  type        = string
  description = "The Entra ID tenant that signs people and the pipeline in."
}

variable "admin_group_object_ids" {
  type        = list(string)
  description = "Entra groups that are cluster admins. Empty: admins are role assignments, made by the caller."
  default     = []
}

variable "kubernetes_version" {
  type        = string
  description = "null takes AKS's default; the patch channel keeps it current."
  default     = null
}

variable "sku_tier" {
  type        = string
  description = "Free has no uptime SLA. Standard has one, and costs per cluster-hour."
  default     = "Free"

  validation {
    condition     = contains(["Free", "Standard", "Premium"], var.sku_tier)
    error_message = "sku_tier must be Free, Standard or Premium."
  }
}

variable "node_vm_size" {
  type        = string
  description = "Not burstable, so KAT-109's load test measures the nodes and not their CPU credits."
  default     = "Standard_D2as_v5"

  validation {
    condition     = !startswith(var.node_vm_size, "Standard_B")
    error_message = "A burstable B-series node is refused: under load it runs out of CPU credits, and the load test would measure that instead of the product."
  }
}

variable "node_min_count" {
  type    = number
  default = 2

  # How many is the environment's to say (modules/environment): production two at
  # least, staging one at the founder's early shape (KAT-648 T-005, 2026-11-07).
  validation {
    condition     = var.node_min_count >= 1
    error_message = "At least one node."
  }
}

variable "node_max_count" {
  type    = number
  default = 3

  validation {
    condition     = var.node_max_count >= var.node_min_count
    error_message = "node_max_count must be at least node_min_count."
  }
}

variable "node_subnet_id" {
  type = string
}

variable "pod_cidr" {
  type        = string
  description = "Azure CNI overlay's pod range. The gateway's pods live here, so it is the product's trusted-proxy range (KAT-S9)."
  default     = "10.244.0.0/16"
}

variable "service_cidr" {
  type    = string
  default = "10.41.0.0/16"
}

variable "dns_service_ip" {
  type    = string
  default = "10.41.0.10"
}

variable "log_analytics_workspace_id" {
  type        = string
  description = "Where the cluster's audit log goes."
}

variable "tags" {
  type    = map(string)
  default = {}
}
