# KAT-648 T-005 Step 6 — the budget comes first. It lives here, in the root applied
# before any environment, so nothing that costs money exists without it.

locals {
  budget_alerts = [
    { threshold = 50, type = "Actual" },
    { threshold = 80, type = "Actual" },
    { threshold = 100, type = "Actual" },
    { threshold = 100, type = "Forecasted" },
  ]
}

resource "azurerm_consumption_budget_subscription" "monthly" {
  name            = "katachi-monthly"
  subscription_id = "/subscriptions/${var.subscription_id}"
  amount          = var.monthly_budget
  time_grain      = "Monthly"

  # Azure wants the first day of a month. The month it starts in does not matter
  # after the first apply, so a later plan leaves it alone.
  time_period {
    start_date = formatdate("YYYY-MM-01'T'00:00:00Z", plantimestamp())
  }

  dynamic "notification" {
    for_each = local.budget_alerts

    content {
      enabled        = true
      threshold      = notification.value.threshold
      threshold_type = notification.value.type
      operator       = "GreaterThanOrEqualTo"
      contact_emails = var.budget_contact_emails
    }
  }

  lifecycle {
    ignore_changes = [time_period]
  }
}
