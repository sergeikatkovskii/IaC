# KAT-650 T-001 — the plan's AI on Microsoft Foundry (tcm ARD-024 rule 1): one resource
# that holds no key and answers only the cluster, a deployment named after its model, and
# one role to call it.
mock_provider "azurerm" {
  # The account's id is Azure's to give. It is given at plan, so the deployment and the
  # role assignment can be read, and shaped as Azure's, because the provider still
  # validates what a mock answers.
  mock_resource "azurerm_cognitive_account" {
    override_during = plan
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/katachi-test/providers/Microsoft.CognitiveServices/accounts/kat-test-ai-01"
    }
  }
}

variables {
  name                = "kat-test-ai-01"
  resource_group_name = "katachi-test"
  location            = "centralus"
  allowed_subnet_ids  = ["/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/katachi-test/providers/Microsoft.Network/virtualNetworks/vnet/subnets/aks"]
  deployments = {
    "gpt-6-luna" = { version = "2026-09-22", capacity = 50 }
  }
  default_model = "gpt-6-luna"
}

run "the_account_holds_no_key" {
  command = plan

  assert {
    condition     = azurerm_cognitive_account.this.kind == "AIServices" && azurerm_cognitive_account.this.sku_name == "S0"
    error_message = "A Foundry resource (kind AIServices), the standard tier, which bills only for what it serves."
  }

  assert {
    condition     = azurerm_cognitive_account.this.local_auth_enabled == false
    error_message = "Local keys are off, so no key exists to leak; the backend signs in as its workload identity (KAT-650 FR2)."
  }

  assert {
    condition     = azurerm_cognitive_account.this.custom_subdomain_name == "kat-test-ai-01"
    error_message = "A custom subdomain is what token sign-in needs, and it is the resource's own name."
  }
}

run "the_account_answers_only_the_cluster" {
  command = plan

  assert {
    condition     = azurerm_cognitive_account.this.public_network_access_enabled == true && azurerm_cognitive_account.this.network_acls[0].default_action == "Deny"
    error_message = "A public endpoint that denies by default (FR9): a private endpoint is not bought (feature §5a)."
  }

  assert {
    condition     = azurerm_cognitive_account.this.network_acls[0].bypass == "None"
    error_message = "No Azure service is let through on Microsoft's say-so; nothing but the cluster calls this."
  }

  assert {
    condition     = length(azurerm_cognitive_account.this.network_acls[0].ip_rules) == 0
    error_message = "No address is admitted: a developer's machine has no plan AI (the founder, KAT-650 §8 Q4)."
  }

  assert {
    condition     = toset([for r in azurerm_cognitive_account.this.network_acls[0].virtual_network_rules : r.subnet_id]) == toset(var.allowed_subnet_ids)
    error_message = "Exactly the subnets given are admitted, through their Microsoft.CognitiveServices service endpoint."
  }

  assert {
    condition     = alltrue([for r in azurerm_cognitive_account.this.network_acls[0].virtual_network_rules : r.ignore_missing_vnet_service_endpoint == false])
    error_message = "A subnet without the service endpoint is an error at apply, never a rule that silently admits nothing."
  }
}

run "the_account_calls_nothing_out" {
  command = plan

  assert {
    condition     = azurerm_cognitive_account.this.outbound_network_access_restricted == true && length(azurerm_cognitive_account.this.fqdns) == 0
    error_message = "The resource makes no outbound call of its own: a chat completion needs none."
  }
}

run "each_deployment_is_named_after_its_model" {
  command = plan

  variables {
    deployments = {
      "gpt-6-luna"   = { version = "2026-09-22", capacity = 50 }
      "gpt-5.6-luna" = { version = "2026-07-09", capacity = 10 }
    }
  }

  assert {
    condition     = length(azurerm_cognitive_deployment.models) == 2
    error_message = "One deployment per entry."
  }

  assert {
    condition     = alltrue([for name, d in azurerm_cognitive_deployment.models : d.name == name && d.model[0].name == name])
    error_message = "A deployment is named after its model, so the product's setting names both (KAT-650 FR4)."
  }

  assert {
    condition     = alltrue([for name, d in azurerm_cognitive_deployment.models : d.model[0].format == "OpenAI" && d.model[0].version == var.deployments[name].version])
    error_message = "An OpenAI-format model at the version the founder pinned."
  }

  assert {
    condition     = alltrue([for name, d in azurerm_cognitive_deployment.models : d.sku[0].name == "GlobalStandard" && d.sku[0].capacity == var.deployments[name].capacity])
    error_message = "Global Standard, the founder's answer to §8 Q6, at the capacity given: a rate limit in thousands of tokens a minute, which costs nothing."
  }

  assert {
    condition     = alltrue([for d in values(azurerm_cognitive_deployment.models) : d.version_upgrade_option == "OnceCurrentVersionExpired"])
    error_message = "The pinned version holds until Microsoft retires it, and then moves rather than stopping the AI (T-001's ruling)."
  }

  assert {
    condition     = alltrue([for d in values(azurerm_cognitive_deployment.models) : d.cognitive_account_id == azurerm_cognitive_account.this.id])
    error_message = "Every deployment is on this resource."
  }
}

run "one_role_per_holder_on_the_account" {
  command = plan

  variables {
    inference_principal_ids = {
      backend = "aaaaaaaa-0000-0000-0000-000000000001"
    }
  }

  assert {
    condition     = length(azurerm_role_assignment.inference) == 1 && azurerm_role_assignment.inference["backend"].principal_id == "aaaaaaaa-0000-0000-0000-000000000001"
    error_message = "The holder given holds the role once, as itself."
  }

  assert {
    condition     = azurerm_role_assignment.inference["backend"].role_definition_name == "Cognitive Services OpenAI User"
    error_message = "The narrowest built-in role that calls a GPT model. Cognitive Services User is wider, and needed only for Claude (KAT-650 FR2)."
  }

  assert {
    condition     = azurerm_role_assignment.inference["backend"].scope == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/katachi-test/providers/Microsoft.CognitiveServices/accounts/kat-test-ai-01" && azurerm_role_assignment.inference["backend"].principal_type == "ServicePrincipal"
    error_message = "Held on this one resource, never on the resource group or wider, by a managed identity."
  }

  assert {
    condition     = toset(output.holder_names) == toset(["backend"])
    error_message = "The holders come out by name, for the environment's test."
  }
}

run "no_holder_no_role" {
  command = plan

  assert {
    condition     = length(azurerm_role_assignment.inference) == 0 && length(output.holder_names) == 0
    error_message = "With no holder given, nothing holds the role."
  }
}

run "the_default_must_be_deployed" {
  command = plan

  variables {
    default_model = "gpt-4o"
  }

  expect_failures = [var.default_model]
}

run "a_capacity_below_one_is_refused" {
  command = plan

  variables {
    deployments = {
      "gpt-6-luna" = { version = "2026-09-22", capacity = 0 }
    }
  }

  expect_failures = [var.deployments]
}

run "the_url_is_the_resources_own" {
  command = plan

  assert {
    condition     = output.url == "https://kat-test-ai-01.services.ai.azure.com/"
    error_message = "AI_FOUNDRY_URL is the resource's own address; the product adds openai/v1/ for GPT and anthropic/ for Claude (KAT-650 FR3)."
  }

  assert {
    condition     = output.default_model == "gpt-6-luna"
    error_message = "AI_MODEL_DEFAULT is the deployment every action uses unless its own setting names another."
  }
}
