###############################################################################
# Platform Services — outputs.tf
###############################################################################

# ---------------------------------------------------------------------------
# Azure Storage
# ---------------------------------------------------------------------------
output "storage_account_name" {
  description = "Name of the provisioned storage account."
  value       = azurerm_storage_account.main.name
}

output "storage_account_id" {
  description = "Resource ID of the storage account."
  value       = azurerm_storage_account.main.id
}

output "storage_primary_blob_endpoint" {
  description = "Primary blob service endpoint URL."
  value       = azurerm_storage_account.main.primary_blob_endpoint
}

# ---------------------------------------------------------------------------
# Azure AI Search
# ---------------------------------------------------------------------------
output "ai_search_id" {
  description = "Resource ID of the Azure AI Search service."
  value       = azurerm_search_service.main.id
}

output "ai_search_endpoint" {
  description = "HTTPS endpoint for Azure AI Search."
  value       = "https://${azurerm_search_service.main.name}.search.windows.net"
}

# ---------------------------------------------------------------------------
# Azure AI Foundry
# ---------------------------------------------------------------------------
output "ai_foundry_id" {
  description = "Resource ID of the Azure AI Foundry account."
  value       = azurerm_cognitive_account.foundry.id
}

output "ai_foundry_endpoint" {
  description = "HTTPS endpoint for Azure AI Foundry / Cognitive Services."
  value       = azurerm_cognitive_account.foundry.endpoint
}

output "ai_foundry_gpt45_deployment" {
  description = "Name of the GPT-4.5 deployment."
  value       = azapi_resource.gpt45.name
}

output "ai_foundry_codex_deployment" {
  description = "Name of the Codex deployment."
  value       = azapi_resource.codex.name
}

output "ai_foundry_model_router_deployment" {
  description = "Name of the Model Router deployment."
  value       = azapi_resource.model_router.name
}

# ---------------------------------------------------------------------------
# Azure API Management
# ---------------------------------------------------------------------------
output "apim_gateway_url" {
  description = "APIM gateway URL — the public endpoint callers use."
  value       = azurerm_api_management.main.gateway_url
}

output "apim_portal_url" {
  description = "APIM developer portal URL."
  value       = azurerm_api_management.main.developer_portal_url
}

output "apim_id" {
  description = "Resource ID of the APIM instance."
  value       = azurerm_api_management.main.id
}

output "app_insights_connection_string" {
  description = "Application Insights connection string for APIM telemetry."
  value       = azurerm_application_insights.apim.connection_string
  sensitive   = true
}

output "app_insights_instrumentation_key" {
  description = "Application Insights instrumentation key."
  value       = azurerm_application_insights.apim.instrumentation_key
  sensitive   = true
}

# ---------------------------------------------------------------------------
# Key Vault
# ---------------------------------------------------------------------------
output "keyvault_internal_uri" {
  description = "URI of the internal Key Vault."
  value       = azurerm_key_vault.internal.vault_uri
}

output "keyvault_internal_id" {
  description = "Resource ID of the internal Key Vault."
  value       = azurerm_key_vault.internal.id
}

output "keyvault_external_uri" {
  description = "URI of the external Key Vault."
  value       = azurerm_key_vault.external.vault_uri
}

output "keyvault_external_id" {
  description = "Resource ID of the external Key Vault."
  value       = azurerm_key_vault.external.id
}
