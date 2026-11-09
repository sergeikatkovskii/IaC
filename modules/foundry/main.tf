# KAT-650 T-001 — the plan's AI on Microsoft Foundry (tcm ARD-024 rule 1; the founder,
# 2026-11-08: "only Katachi owner set which model to use via MS Foundry"). One resource
# per environment: no key exists, only the cluster's subnet is answered, and the models
# are deployments the founder names here, never anything the product chooses.

resource "azurerm_cognitive_account" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  kind                = "AIServices"
  sku_name            = "S0"

  # Token sign-in needs a custom subdomain, and the resource's own name is unique enough.
  custom_subdomain_name = var.name

  # No key exists to leak: the backend signs in as its workload identity (FR2).
  local_auth_enabled = false

  # Public but default-deny, as the vault and the storage account are. A private
  # endpoint is not bought (feature §5a): with no key, it would guard little.
  public_network_access_enabled = true

  # A chat completion needs no outbound call from the resource itself.
  outbound_network_access_restricted = true
  fqdns                              = []

  network_acls {
    default_action = "Deny"
    bypass         = "None"
    # No address is admitted: a developer's machine has no plan AI (the founder,
    # KAT-650 §8 Q4). Only the cluster's subnet, by its service endpoint.
    ip_rules = []

    dynamic "virtual_network_rules" {
      for_each = toset(var.allowed_subnet_ids)
      content {
        subnet_id                            = virtual_network_rules.value
        ignore_missing_vnet_service_endpoint = false
      }
    }
  }

  tags = var.tags
}

# Each model the founder chose, named after itself (FR4). Global Standard is his answer
# to §8 Q6 and is pay-per-token, so a deployment costs nothing until it is called; its
# capacity is a rate limit drawn from the subscription's quota for that model (FR10).
# The default content filter applies, so no policy is named (FR6).
resource "azurerm_cognitive_deployment" "models" {
  for_each = var.deployments

  name                 = each.key
  cognitive_account_id = azurerm_cognitive_account.this.id

  model {
    format  = "OpenAI"
    name    = each.key
    version = each.value.version
  }

  sku {
    name     = "GlobalStandard"
    capacity = each.value.capacity
  }

  # T-001's ruling: the pinned version holds until Microsoft retires it, then moves.
  # NoAutoUpgrade would stop the plan's AI on the retirement day.
  version_upgrade_option = "OnceCurrentVersionExpired"
}

# The narrowest built-in role that calls a GPT model, held on this one resource by each
# unit whose code makes a platform AI call. Today that is the backend alone; tcm's
# test_only_the_backend_makes_a_platform_ai_call fails the day another unit's code does.
resource "azurerm_role_assignment" "inference" {
  for_each = var.inference_principal_ids

  scope                = azurerm_cognitive_account.this.id
  role_definition_name = "Cognitive Services OpenAI User"
  principal_id         = each.value
  principal_type       = "ServicePrincipal"
}
