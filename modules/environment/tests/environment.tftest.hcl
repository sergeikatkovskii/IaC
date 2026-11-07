# KAT-648 T-005 — one environment, composed. staging and production call this module
# with their own tfvars, so they differ by values and never by an edited copy.
mock_provider "azurerm" {
  mock_data "azurerm_client_config" {
    defaults = {
      tenant_id       = "00000000-0000-0000-0000-000000000001"
      object_id       = "33333333-3333-3333-3333-333333333333"
      subscription_id = "00000000-0000-0000-0000-000000000000"
      client_id       = "55555555-5555-5555-5555-555555555555"
    }
  }

  # KAT-648 T-005: the subscription the provider is pointed at, by its name.
  mock_data "azurerm_subscription" {
    defaults = {
      display_name = "AZ2-NonProd"
    }
  }
}

# KAT-648 T-005: the SMTP application is an Entra one (modules/mail).
mock_provider "azuread" {}

variables {
  environment           = "staging"
  subscription_name     = "AZ2-NonProd"
  location              = "centralus"
  resource_group_name   = "katachi-test"
  app_host              = "staging.example.test"
  mcp_host              = "mcp.staging.example.test"
  admin_host            = "admin.staging.example.test"
  operator_ip_ranges    = ["203.0.113.7"]
  alert_email_receivers = { oncall = "ops@example.test" }
}

run "the_values_the_overlay_needs_come_out" {
  command = plan

  assert {
    condition     = output.app_host == "staging.example.test" && output.mcp_host == "mcp.staging.example.test"
    error_message = "The hosts reach environment.env as APP_HOST and MCP_HOST."
  }

  assert {
    condition     = output.admin_host == "admin.staging.example.test"
    error_message = "The operator console's host reaches environment.env as ADMIN_HOST (KAT-648 §8 Q2)."
  }

  assert {
    condition     = output.postgres_max_user_connections == 414
    error_message = "DB_MAX_USER_CONNECTIONS is the chosen tier's own figure."
  }

  assert {
    condition     = output.pod_cidr == "10.244.0.0/16"
    error_message = "TRUSTED_PROXY_CIDR is the pod range the gateway's pods live in (KAT-S9)."
  }

  assert {
    condition     = toset(keys(output.unit_client_ids)) == toset(["backend", "worker", "scheduler", "mcp", "migrate", "redis", "db-bootstrap"])
    error_message = "Every unit's client id comes out, for its service account."
  }

  assert {
    condition     = output.postgres_admin_login == "katachiadmin"
    error_message = "DB_ADMIN_USER is the server administrator first boot signs in as."
  }
}

# KAT-648 T-004: first boot's database bootstrap makes the role DATABASE_URL names,
# which lives in the app vault — and the administrator's password in the admin one.
run "first_boot_reads_the_role_from_the_app_vault_and_the_password_from_the_admin_one" {
  command = plan

  assert {
    condition     = contains(module.vault_app.reader_names, "db-bootstrap")
    error_message = "db-bootstrap reads the app vault's database-url."
  }

  assert {
    condition     = toset(module.vault_admin.reader_names) == toset(["db-bootstrap"])
    error_message = "Only db-bootstrap reads the admin vault."
  }
}

run "the_environment_is_one_of_two" {
  command = plan

  variables {
    environment = "dev"
  }

  expect_failures = [var.environment]
}

run "a_placeholder_host_is_refused" {
  command = plan

  variables {
    app_host = "REPLACE"
  }

  expect_failures = [var.app_host]
}

run "a_placeholder_admin_host_is_refused" {
  command = plan

  variables {
    admin_host = "REPLACE"
  }

  expect_failures = [var.admin_host]
}

# KAT-648 T-005: four subscriptions, and az's default is not staging's. The
# subscription the provider is pointed at must be the one this environment names, or
# nothing is planned in it.
run "a_plan_in_another_subscription_is_refused" {
  command = plan

  variables {
    subscription_name = "AZ1-TCM"
  }

  expect_failures = [azurerm_resource_group.this]
}

# KAT-648 T-005: staging runs the Kubernetes minor minikube proved the manifests on,
# which the pipeline's kubectl matches; the patch channel keeps it current.
run "the_cluster_runs_the_minor_it_is_given" {
  command = plan

  variables {
    kubernetes_version = "1.35"
  }

  assert {
    condition     = module.cluster.kubernetes_version == "1.35"
    error_message = "environment's kubernetes_version reaches the cluster."
  }
}

# KAT-648 T-005: staging's mail (§8 Q5) comes with its zone, because the domain it
# sends from is verified there; an environment with no zone here has none yet.
run "mail_comes_with_the_zone_it_is_verified_in" {
  command = plan

  variables {
    dns_zone_name = "staging.example.test"
    app_host      = "staging.example.test"
  }

  assert {
    condition     = length(module.mail) == 1 && output.smtp_host == "smtp.azurecomm.net"
    error_message = "With a zone served here, staging sends mail through Azure Communication Services."
  }
}

run "no_zone_means_no_mail_yet" {
  command = plan

  assert {
    condition     = length(module.mail) == 0 && output.smtp_host == null
    error_message = "Without a zone there is nowhere to verify a sending domain."
  }
}
