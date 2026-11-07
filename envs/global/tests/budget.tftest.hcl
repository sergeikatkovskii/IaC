# KAT-648 T-005 Step 6 — the budget exists before anything else is created.
mock_provider "azurerm" {
  mock_data "azurerm_subscription" {
    defaults = {
      display_name = "AZ2-NonProd"
    }
  }
}

variables {
  subscription_id       = "00000000-0000-0000-0000-000000000000"
  subscription_name     = "AZ2-NonProd"
  operator_ip_ranges    = ["203.0.113.7"]
  state_account_name    = "katachitfstate"
  monthly_budget        = 150
  budget_contact_emails = ["ops@example.test"]
}

run "the_budget_warns_four_times" {
  command = plan

  assert {
    condition     = toset([for n in azurerm_consumption_budget_subscription.monthly.notification : "${n.threshold_type}:${n.threshold}"]) == toset(["Actual:50", "Actual:80", "Actual:100", "Forecasted:100"])
    error_message = "Mail at 50, 80 and 100 per cent of actual spend, and at 100 per cent forecast."
  }

  assert {
    condition     = azurerm_consumption_budget_subscription.monthly.amount == 150
    error_message = "The amount is the founder's ceiling (KAT-648 §8 Q7)."
  }
}

run "a_ceiling_of_nothing_is_refused" {
  command = plan

  variables {
    monthly_budget = 0
  }

  expect_failures = [var.monthly_budget]
}

run "a_placeholder_subscription_is_refused" {
  command = plan

  variables {
    subscription_id = "REPLACE-WITH-SUBSCRIPTION-GUID"
  }

  expect_failures = [var.subscription_id]
}

# KAT-648 T-005: applied once in each subscription, and never in the wrong one.
run "the_state_account_is_never_made_in_another_subscription" {
  command = plan

  variables {
    subscription_name = "AZ1-TCM"
  }

  expect_failures = [azurerm_resource_group.shared]
}

# KAT-648 T-005: the env roots keep their state here and sign in with Entra
# (use_azuread_auth), never with the account's key. Owning a subscription grants no
# right to the blobs inside an account, so the person who applies is given that right
# here, and the shared keys are off: nothing can sign in with one.
run "the_state_is_reached_with_entra_and_never_with_a_key" {
  command = plan

  assert {
    condition     = azurerm_storage_account.tfstate.shared_access_key_enabled == false
    error_message = "The state account takes no shared key: the backends sign in with Entra."
  }

  assert {
    condition     = azurerm_role_assignment.state_writer.role_definition_name == "Storage Blob Data Contributor"
    error_message = "The person who applies may read and write the state's blobs."
  }
}

# KAT-648 T-005, from trivy config (AZU-0012, AZU-0061): the state answers only the
# address the founder runs Terraform from, and is encrypted twice at rest (set only
# when the account is made).
run "the_state_account_answers_only_the_operator" {
  command = plan

  assert {
    condition     = azurerm_storage_account.tfstate.network_rules[0].default_action == "Deny" && toset(azurerm_storage_account.tfstate.network_rules[0].ip_rules) == toset(["203.0.113.7"])
    error_message = "Nothing reaches the state but the operator's address."
  }

  assert {
    condition     = azurerm_storage_account.tfstate.infrastructure_encryption_enabled == true
    error_message = "The state is encrypted at the infrastructure layer as well."
  }
}
