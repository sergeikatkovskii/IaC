variable "name_prefix" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "resource_group_id" {
  type        = string
  description = "The only scope the role can be given in."
}

variable "location" {
  type = string
}

variable "cluster_id" {
  type = string
}

variable "server_id" {
  type        = string
  description = "The database server, started and stopped with the cluster."
}

variable "github_repository" {
  type    = string
  default = "sergeikatkovskii/tcm"
}

variable "github_environment" {
  type        = string
  description = "The environment this powers; its GitHub environment is <this>-power, with no reviewer, which a release never uses."
}

variable "tags" {
  type    = map(string)
  default = {}
}
