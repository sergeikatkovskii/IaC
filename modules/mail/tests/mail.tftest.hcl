# KAT-648 T-005 — staging's mail (§8 Q5): Azure Communication Services Email, sent
# over SMTP from the domain staging already serves, by an Entra application whose
# password Terraform never holds.
mock_provider "azurerm" {
  mock_data "azurerm_client_config" {
    defaults = {
      tenant_id = "00000000-0000-0000-0000-000000000001"
    }
  }

  mock_resource "azurerm_communication_service" {
    override_during = plan
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/katachi-test/providers/Microsoft.Communication/communicationServices/katachi-test-mail"
    }
  }

  mock_resource "azurerm_email_communication_service" {
    override_during = plan
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/katachi-test/providers/Microsoft.Communication/emailServices/katachi-test-email"
    }
  }

  # What Azure answers for a customer-managed domain: the four records it verifies.
  mock_resource "azurerm_email_communication_service_domain" {
    override_during = plan
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/katachi-test/providers/Microsoft.Communication/emailServices/katachi-test-email/domains/staging.example.test"
      verification_records = [{
        domain = [{ name = "staging.example.test", type = "TXT", value = "ms-domain-verification=0f0f", ttl = 3600 }]
        spf    = [{ name = "staging.example.test", type = "TXT", value = "v=spf1 include:spf.protection.outlook.com -all", ttl = 3600 }]
        dkim   = [{ name = "selector1-azurecomm-prod-net._domainkey", type = "CNAME", value = "selector1-azurecomm-prod-net._domainkey.azurecomm.net", ttl = 3600 }]
        dkim2  = [{ name = "selector2-azurecomm-prod-net._domainkey", type = "CNAME", value = "selector2-azurecomm-prod-net._domainkey.azurecomm.net", ttl = 3600 }]
        dmarc  = []
      }]
    }
  }
}

mock_provider "azuread" {
  mock_resource "azuread_application" {
    override_during = plan
    defaults = {
      client_id = "22222222-0000-0000-0000-000000000002"
    }
  }

  mock_resource "azuread_service_principal" {
    override_during = plan
    defaults = {
      object_id = "33333333-0000-0000-0000-000000000003"
    }
  }
}

variables {
  name_prefix         = "katachi-test"
  resource_group_name = "katachi-test"
  domain              = "staging.example.test"
  zone_name           = "staging.example.test"
}

run "the_domain_is_ours_and_nothing_tracks_its_readers" {
  command = plan

  assert {
    condition     = azurerm_email_communication_service_domain.this.name == "staging.example.test" && azurerm_email_communication_service_domain.this.domain_management == "CustomerManaged"
    error_message = "Mail is sent from staging's own domain, which we manage, never from an Azure-managed one."
  }

  assert {
    condition     = azurerm_email_communication_service_domain.this.user_engagement_tracking_enabled == false
    error_message = "No open or click tracking: a reset link must not be rewritten to pass through Azure."
  }

  assert {
    condition     = azurerm_email_communication_service.this.data_location == "United States" && azurerm_communication_service.this.data_location == "United States"
    error_message = "The services keep their data where the cluster runs."
  }
}

run "the_domain_is_proved_in_its_own_zone" {
  command = plan

  assert {
    condition     = azurerm_dns_txt_record.apex.name == "@" && toset([for r in azurerm_dns_txt_record.apex.record : r.value]) == toset(["ms-domain-verification=0f0f", "v=spf1 include:spf.protection.outlook.com -all"])
    error_message = "The domain's ownership and SPF records share the zone's apex, as one record set."
  }

  assert {
    condition     = azurerm_dns_cname_record.dkim.name == "selector1-azurecomm-prod-net._domainkey" && azurerm_dns_cname_record.dkim.record == "selector1-azurecomm-prod-net._domainkey.azurecomm.net"
    error_message = "The first DKIM selector points at Azure's key."
  }

  assert {
    condition     = azurerm_dns_cname_record.dkim2.name == "selector2-azurecomm-prod-net._domainkey" && azurerm_dns_cname_record.dkim2.zone_name == "staging.example.test"
    error_message = "The second DKIM selector is in staging's zone."
  }
}

run "the_sending_app_may_send_mail_and_holds_no_password_here" {
  command = plan

  assert {
    condition     = azurerm_role_assignment.smtp.role_definition_name == "Communication and Email Service Owner" && azurerm_role_assignment.smtp.scope == azurerm_communication_service.this.id
    error_message = "The SMTP application's one role is on its own Communication Services resource."
  }

  assert {
    condition     = azurerm_role_assignment.smtp.principal_id == "33333333-0000-0000-0000-000000000003"
    error_message = "The role is the application's service principal's."
  }

  # The SMTP password is the application's client secret, made after the apply and
  # written straight into the vault, so it never reaches Terraform's state.
  assert {
    condition     = length(azuread_application.smtp.password) == 0
    error_message = "Terraform makes no password for the application."
  }
}

run "the_product_is_told_where_and_as_whom_to_send" {
  command = plan

  assert {
    condition     = output.smtp_host == "smtp.azurecomm.net"
    error_message = "SMTP over STARTTLS at Azure's own host (checked at TLS 1.3, 2026-11-06)."
  }

  assert {
    condition     = output.smtp_username == "katachi-test-mail.22222222-0000-0000-0000-000000000002.00000000-0000-0000-0000-000000000001"
    error_message = "The SMTP username is the resource's name, the application's id and the tenant's, joined by dots (Microsoft)."
  }

  assert {
    condition     = output.mail_from == "donotreply@staging.example.test"
    error_message = "Mail comes from the domain's one sender."
  }
}
