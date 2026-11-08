# KAT-648 T-005 — the committed values are placeholders, and a placeholder must
# fail rather than plan clean (this repository's second rule). Reads the committed
# terraform.tfvars as it stands.
mock_provider "azurerm" {
  # The provider still validates what a mock answers, so ids are shaped as Azure's.
  mock_data "azurerm_client_config" {
    defaults = {
      tenant_id       = "00000000-0000-0000-0000-000000000001"
      object_id       = "33333333-3333-3333-3333-333333333333"
      subscription_id = "00000000-0000-0000-0000-000000000000"
      client_id       = "55555555-5555-5555-5555-555555555555"
    }
  }

  mock_data "azurerm_subscription" {
    defaults = {
      display_name = "AZ1-TCM"
    }
  }
}
mock_provider "azuread" {}

run "the_committed_values_cannot_be_applied" {
  command = plan

  expect_failures = [
    var.subscription_id,
    var.app_host,
    var.mcp_host,
    var.admin_host,
    var.operator_ip_ranges,
  ]
}

# KAT-648 T-005: the shape the founder approved for production (2026-11-07, "two
# reserved node"): two Standard_D2as_v5, which he reserves for a year, PostgreSQL B1ms,
# and logs capped at 0.3 GB a day — 160.30 USD a month with the reservation, at most
# 185.49 with logs at the cap, AKS's own load balancer and outbound address included
# (scripts/price.py, 2026-11-07). The two never-committed values are given here; the
# hosts stay placeholders until production's are answered.
run "the_committed_shape_is_two_reserved_nodes_and_the_smallest_database" {
  command = plan

  variables {
    subscription_id    = "00000000-0000-0000-0000-000000000000"
    operator_ip_ranges = ["203.0.113.7"]
    app_host           = "app.example.test"
    mcp_host           = "mcp.example.test"
    admin_host         = "admin.example.test"
  }

  assert {
    condition     = var.node_vm_size == "Standard_D2as_v5" && var.node_min_count == 2 && var.node_max_count == 2
    error_message = "Two nodes, the size the reservation is bought for, and no third the reservation would not cover."
  }

  assert {
    condition     = output.postgres_max_user_connections == 35 && var.log_daily_quota_gb == 0.3
    error_message = "PostgreSQL B1ms, whose 35 connections production's pools are sized for, and logs capped at 0.3 GB a day."
  }
}
