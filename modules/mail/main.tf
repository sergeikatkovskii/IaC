# KAT-648 T-005 — staging's mail (§8 Q5): Azure Communication Services Email, which the
# product reaches over SMTP with STARTTLS at TLS 1.3 (smtp.azurecomm.net:587, measured
# 2026-11-06), so its mail code is unchanged. It sends from staging's own domain,
# verified by the four records Azure asks for, written in the zone staging serves.
#
# The SMTP password is an Entra application's client secret. Terraform makes the
# application and its one role, and never its secret: the founder makes that after
# the apply and writes it straight into the vault (tcm docs/runbooks/staging.md), so it
# reaches neither the plan nor the state. Azure does attach access keys to the
# Communication Services resource itself, and the provider reads them into the state
# whatever this says; the state account is Entra-only, behind the operator's address.

data "azurerm_client_config" "current" {}

resource "azurerm_email_communication_service" "this" {
  name                = "${var.name_prefix}-email"
  resource_group_name = var.resource_group_name
  data_location       = var.data_location
  tags                = var.tags
}

# No open or click tracking: a reset link must reach the reader as we wrote it.
resource "azurerm_email_communication_service_domain" "this" {
  name                             = var.domain
  email_service_id                 = azurerm_email_communication_service.this.id
  domain_management                = "CustomerManaged"
  user_engagement_tracking_enabled = false
  tags                             = var.tags
}

resource "azurerm_communication_service" "this" {
  name                = "${var.name_prefix}-mail"
  resource_group_name = var.resource_group_name
  data_location       = var.data_location
  tags                = var.tags
}

resource "azurerm_communication_service_email_domain_association" "this" {
  communication_service_id = azurerm_communication_service.this.id
  email_service_domain_id  = azurerm_email_communication_service_domain.this.id
}

resource "azurerm_email_communication_service_domain_sender_username" "this" {
  name                    = var.sender
  email_service_domain_id = azurerm_email_communication_service_domain.this.id
  display_name            = var.sender_display_name
}

# The records Azure verifies the domain by, each named relative to the zone.
locals {
  records = azurerm_email_communication_service_domain.this.verification_records[0]
  relative = {
    for kind in ["domain", "spf", "dkim", "dkim2"] : kind => (
      trimsuffix(local.records[kind][0].name, ".") == var.domain
      ? "@"
      : trimsuffix(trimsuffix(local.records[kind][0].name, "."), ".${var.domain}")
    )
  }
}

# Ownership and SPF both live at the domain itself: one TXT record set holds both.
resource "azurerm_dns_txt_record" "apex" {
  name                = local.relative["domain"]
  zone_name           = var.zone_name
  resource_group_name = var.resource_group_name
  ttl                 = 3600
  tags                = var.tags

  record {
    value = local.records.domain[0].value
  }

  record {
    value = local.records.spf[0].value
  }

  lifecycle {
    precondition {
      condition     = local.relative["domain"] == local.relative["spf"]
      error_message = "Azure named the ownership and SPF records differently; they cannot share one TXT record set."
    }
  }
}

resource "azurerm_dns_cname_record" "dkim" {
  name                = local.relative["dkim"]
  zone_name           = var.zone_name
  resource_group_name = var.resource_group_name
  ttl                 = 3600
  record              = local.records.dkim[0].value
  tags                = var.tags
}

resource "azurerm_dns_cname_record" "dkim2" {
  name                = local.relative["dkim2"]
  zone_name           = var.zone_name
  resource_group_name = var.resource_group_name
  ttl                 = 3600
  record              = local.records.dkim2[0].value
  tags                = var.tags
}

# The SMTP application: an Entra application with no password here, and one role,
# on its own Communication Services resource (Microsoft: SMTP authentication).
resource "azuread_application" "smtp" {
  display_name     = "${var.name_prefix}-smtp"
  sign_in_audience = "AzureADMyOrg"
}

resource "azuread_service_principal" "smtp" {
  client_id = azuread_application.smtp.client_id
}

resource "azurerm_role_assignment" "smtp" {
  scope                = azurerm_communication_service.this.id
  role_definition_name = "Communication and Email Service Owner"
  principal_id         = azuread_service_principal.smtp.object_id
  principal_type       = "ServicePrincipal"
}
