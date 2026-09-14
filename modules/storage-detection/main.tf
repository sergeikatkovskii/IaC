# KAT-417 T-004 — storage detection.
#
# Three alerts, each backing one control in ARD-039. An alert that does not back a
# specific control is an alert nobody will know what to do with:
#
#   Alert 1  anonymous success          <- §4, the container is private
#   Alert 2  container-scoped ListBlobs <- §5, the SAS carries no `list`
#   Alert 3  SAS from outside egress    <- §3, the account is not on the internet
#
# Deliberately NOT here: request-rate and throttling. That is a capacity signal, it
# belongs with KAT-211's uptime and error tracking, and mixing capacity into a
# security channel is how a security channel gets ignored.

locals {
  suffix = var.environment

  # The categories live on the blob service, not on the account.
  blob_service_id = "${var.storage_account_id}/blobServices/default"

  workspace_id = var.log_analytics_workspace_id != "" ? var.log_analytics_workspace_id : azurerm_log_analytics_workspace.storage[0].id

  sas_allowed_cidrs = concat(var.cluster_egress_cidrs, var.office_vpn_cidrs)

  query_anonymous_success = file("${path.module}/queries/anonymous-success.kql")
  query_container_list    = file("${path.module}/queries/container-list.kql")
  query_sas_outside_egress = templatefile("${path.module}/queries/sas-outside-egress.kql.tftpl", {
    allowed_cidrs = jsonencode(local.sas_allowed_cidrs)
  })
}

# ── The single point of failure for this whole task ────────────────────────────
# Without the diagnostic setting none of the three rules has anything to read, and
# they stay green while seeing nothing. The runbook's first check is "is this still
# attached", for exactly that reason.

resource "azurerm_log_analytics_workspace" "storage" {
  count = var.log_analytics_workspace_id == "" ? 1 : 0

  name                = "katachi-storage-${local.suffix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_days
}

resource "azurerm_monitor_diagnostic_setting" "blob" {
  name               = "katachi-storage-detection"
  target_resource_id = local.blob_service_id

  log_analytics_workspace_id = local.workspace_id

  # Dedicated => the StorageBlobLogs table, which every query here reads. In
  # AzureDiagnostics mode the column names differ and all three queries return
  # nothing, without erroring.
  log_analytics_destination_type = "Dedicated"

  enabled_log { category = "StorageRead" }
  enabled_log { category = "StorageWrite" }
  enabled_log { category = "StorageDelete" }

  enabled_metric { category = "Transaction" }
}

# ── Who is told ────────────────────────────────────────────────────────────────

resource "azurerm_monitor_action_group" "storage_security" {
  name                = "katachi-storage-security-${local.suffix}"
  resource_group_name = var.resource_group_name
  short_name          = "katstorage"

  dynamic "email_receiver" {
    for_each = var.alert_email_receivers
    content {
      name                    = email_receiver.key
      email_address           = email_receiver.value
      use_common_alert_schema = true
    }
  }

  dynamic "webhook_receiver" {
    for_each = var.alert_webhook_url != "" ? [var.alert_webhook_url] : []
    content {
      name                    = "support-channel"
      service_uri             = webhook_receiver.value
      use_common_alert_schema = true
    }
  }

  lifecycle {
    precondition {
      # An action group with no receivers applies cleanly and notifies nobody. All
      # three rules would then fire into the void and every dashboard would show
      # them healthy, which is the exact failure this task exists to prevent —
      # worth refusing rather than discovering during the first real incident.
      condition     = length(var.alert_email_receivers) > 0 || var.alert_webhook_url != ""
      error_message = "Set at least one of alert_email_receivers or alert_webhook_url — an action group with no receivers notifies nobody."
    }
  }
}

# ── Alert 1 — any anonymous success ────────────────────────────────────────────

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "anonymous_success" {
  name                = "katachi-storage-anonymous-success-${local.suffix}"
  resource_group_name = var.resource_group_name
  location            = var.location

  description = "An anonymous caller received a 2xx from the storage account. After KAT-417 T-002 this should be impossible; see docs/runbooks/storage-alerts.md."
  severity    = 0
  enabled     = true

  scopes               = [local.workspace_id]
  evaluation_frequency = "PT5M"
  window_duration      = "PT5M"

  criteria {
    query                   = local.query_anonymous_success
    time_aggregation_method = "Count"
    threshold               = 0
    operator                = "GreaterThan"

    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 1
    }
  }

  # A security finding does not stop being true because the next window is quiet.
  auto_mitigation_enabled = false
  skip_query_validation   = var.skip_query_validation

  action {
    action_groups = [azurerm_monitor_action_group.storage_security.id]
  }
}

# ── Alert 2 — container-scoped ListBlobs ───────────────────────────────────────

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "container_list" {
  name                = "katachi-storage-container-list-${local.suffix}"
  resource_group_name = var.resource_group_name
  location            = var.location

  description = "Something enumerated the container outside a tenant prefix. Usually an operator; see docs/runbooks/storage-alerts.md for the known-benign list."
  severity    = 1
  enabled     = true

  scopes               = [local.workspace_id]
  evaluation_frequency = "PT5M"
  window_duration      = "PT5M"

  criteria {
    query                   = local.query_container_list
    time_aggregation_method = "Count"
    threshold               = 0
    operator                = "GreaterThan"

    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 1
    }
  }

  auto_mitigation_enabled = false
  skip_query_validation   = var.skip_query_validation

  action {
    action_groups = [azurerm_monitor_action_group.storage_security.id]
  }
}

# ── Alert 3 — SAS used from outside the expected egress ────────────────────────

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "sas_outside_egress" {
  name                = "katachi-storage-sas-outside-egress-${local.suffix}"
  resource_group_name = var.resource_group_name
  location            = var.location

  description = "A SAS succeeded from outside the cluster egress. Until KAT-417 T-005 relays downloads this is usually a customer; see docs/runbooks/storage-alerts.md before escalating."
  severity    = 1
  enabled     = var.enable_sas_egress_alert

  scopes               = [local.workspace_id]
  evaluation_frequency = "PT5M"
  window_duration      = "PT5M"

  criteria {
    query                   = local.query_sas_outside_egress
    time_aggregation_method = "Count"
    threshold               = 0
    operator                = "GreaterThan"

    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 1
    }
  }

  auto_mitigation_enabled = false
  skip_query_validation   = var.skip_query_validation

  action {
    action_groups = [azurerm_monitor_action_group.storage_security.id]
  }

  lifecycle {
    precondition {
      # With no ranges the range test is not meaningful: an empty dynamic array
      # makes ipv4_is_in_any_range match nothing, and whether that reads as false
      # (every SAS request alerts) or as null (the row is filtered and the rule
      # never fires at all) is not worth depending on. Neither is a configuration
      # anyone wants, and the second one is the dangerous kind — a rule that looks
      # like coverage and sees nothing.
      condition     = !var.enable_sas_egress_alert || length(local.sas_allowed_cidrs) > 0
      error_message = "enable_sas_egress_alert = true requires at least one entry in cluster_egress_cidrs or office_vpn_cidrs."
    }
  }
}
