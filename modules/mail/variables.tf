variable "name_prefix" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "domain" {
  type        = string
  description = "The domain mail is sent from: staging's own zone (KAT-648 §8 Q2, Q5)."
}

variable "zone_name" {
  type        = string
  description = "The DNS zone served here that holds the domain's verification records (modules/edge's zone_name)."
}

variable "data_location" {
  type        = string
  description = "Where the mail services keep their data at rest: where the cluster runs."
  default     = "United States"
}

variable "sender" {
  type        = string
  description = "The one sender's username, before the @."
  default     = "donotreply"
}

variable "sender_display_name" {
  type    = string
  default = "Katachi"
}

variable "tags" {
  type    = map(string)
  default = {}
}
