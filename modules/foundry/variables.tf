variable "name" {
  type        = string
  description = "The resource's name, which is also its custom subdomain: unique across Azure, 2-64 lowercase letters, digits and hyphens."

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{0,62}[a-z0-9]$", var.name))
    error_message = "A Foundry resource name is 2-64 lowercase letters, digits and hyphens, and starts and ends with a letter or digit."
  }
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "allowed_subnet_ids" {
  type        = list(string)
  description = "The subnets admitted through the resource's network rule. Each needs the Microsoft.CognitiveServices service endpoint (modules/network)."
  default     = []
}

variable "deployments" {
  type = map(object({
    version  = string
    capacity = number
  }))
  description = "model name => its pinned version and its capacity in thousands of tokens a minute. Each deployment is named after its model (tcm KAT-650 FR4). The founder chooses these; nothing in the product does (FR1)."

  validation {
    condition     = length(var.deployments) > 0
    error_message = "At least one model is deployed."
  }

  validation {
    condition     = alltrue([for d in values(var.deployments) : d.capacity >= 1 && floor(d.capacity) == d.capacity])
    error_message = "A capacity is a whole number of thousands of tokens a minute, at least 1."
  }

  validation {
    condition     = alltrue([for name in keys(var.deployments) : can(regex("^[a-z0-9][a-z0-9.-]*$", name))])
    error_message = "A deployment is named after its model, which is lowercase letters, digits, dots and hyphens."
  }
}

variable "default_model" {
  type        = string
  description = "The deployment every AI action uses unless its own setting names another: AI_MODEL_DEFAULT in tcm's environment.env."

  validation {
    condition     = contains(keys(var.deployments), var.default_model)
    error_message = "The default model has to be one of the deployments, or every AI action would call a deployment that does not exist."
  }
}

variable "inference_principal_ids" {
  type        = map(string)
  description = "unit => principal id of each unit whose code makes a platform AI call; each holds Cognitive Services OpenAI User on this resource, and nothing else does (tcm KAT-650 FR2)."
  default     = {}
}

variable "tags" {
  type    = map(string)
  default = {}
}
