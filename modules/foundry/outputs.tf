output "id" {
  value = azurerm_cognitive_account.this.id
}

# KAT-650 T-001: where the product calls, and what it calls by default.
output "url" {
  description = "The resource's own address: AI_FOUNDRY_URL in tcm's environment.env. The product adds openai/v1/ for GPT and anthropic/ for Claude."
  value       = "https://${azurerm_cognitive_account.this.custom_subdomain_name}.services.ai.azure.com/"
}

output "default_model" {
  description = "AI_MODEL_DEFAULT in tcm's environment.env: a deployment's name, which is its model's."
  value       = var.default_model
}

output "deployment_names" {
  value = sort(keys(azurerm_cognitive_deployment.models))
}

# Who holds the role, by name: tested at the composition, where it matters.
output "holder_names" {
  value = sort(keys(var.inference_principal_ids))
}
