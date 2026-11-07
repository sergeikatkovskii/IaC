# KAT-648 T-005 Step 6 — the budget exists before anything else is created.
mock_provider "azurerm" {}

variables {
  subscription_id       = "00000000-0000-0000-0000-000000000000"
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
