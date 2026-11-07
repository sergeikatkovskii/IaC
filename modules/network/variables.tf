variable "name_prefix" {
  type        = string
  description = "Prefix for every name in this module, such as katachi-staging."
}

variable "resource_group_name" {
  type        = string
  description = "Resource group the network lives in."
}

variable "location" {
  type        = string
  description = "Azure region."
}

variable "address_space" {
  type        = list(string)
  description = "The virtual network. It must not overlap the cluster's pod or service ranges."
  default     = ["10.40.0.0/16"]
}

variable "aks_subnet_prefix" {
  type        = string
  description = "The nodes' subnet. With Azure CNI overlay only nodes take addresses here; pods take theirs from the pod range."
  default     = "10.40.0.0/22"
}

variable "postgres_subnet_prefix" {
  type        = string
  description = "The database's subnet, delegated to PostgreSQL Flexible Server."
  default     = "10.40.8.0/24"
}

variable "tags" {
  type    = map(string)
  default = {}
}
