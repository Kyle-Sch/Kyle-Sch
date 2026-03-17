###############################################################################
# roles.tf — RBAC assignments for platform services
###############################################################################

# ---------------------------------------------------------------------------
# Key Vault — Terraform executor and FastAPI identity
# ---------------------------------------------------------------------------
resource "azurerm_role_assignment" "terraform_kv_officer_internal" {
  scope                = azurerm_key_vault.internal.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_role_assignment" "fastapi_kv_reader_internal" {
  scope                = azurerm_key_vault.internal.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = data.terraform_remote_state.aks.outputs.fastapi_workload_identity_principal_id
}

resource "azurerm_role_assignment" "terraform_kv_officer_external" {
  scope                = azurerm_key_vault.external.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_role_assignment" "fastapi_kv_reader_external" {
  scope                = azurerm_key_vault.external.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = data.terraform_remote_state.aks.outputs.fastapi_workload_identity_principal_id
}

resource "azurerm_role_assignment" "apim_kv_reader_internal" {
  scope                = azurerm_key_vault.internal.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_api_management.main.identity[0].principal_id
}

# ---------------------------------------------------------------------------
# AI Search — FastAPI identity
# ---------------------------------------------------------------------------
resource "azurerm_role_assignment" "fastapi_search_index_reader" {
  scope                = azurerm_search_service.main.id
  role_definition_name = "Search Index Data Reader"
  principal_id         = data.terraform_remote_state.aks.outputs.fastapi_workload_identity_principal_id
}

resource "azurerm_role_assignment" "fastapi_search_index_contributor" {
  scope                = azurerm_search_service.main.id
  role_definition_name = "Search Index Data Contributor"
  principal_id         = data.terraform_remote_state.aks.outputs.fastapi_workload_identity_principal_id
}

resource "azurerm_role_assignment" "fastapi_search_service_contributor" {
  scope                = azurerm_search_service.main.id
  role_definition_name = "Search Service Contributor"
  principal_id         = data.terraform_remote_state.aks.outputs.fastapi_workload_identity_principal_id
}

# ---------------------------------------------------------------------------
# AI Foundry — FastAPI identity
# ---------------------------------------------------------------------------
resource "azurerm_role_assignment" "fastapi_openai_user" {
  scope                = azurerm_cognitive_account.foundry.id
  role_definition_name = "Cognitive Services OpenAI User"
  principal_id         = data.terraform_remote_state.aks.outputs.fastapi_workload_identity_principal_id
}

resource "azurerm_role_assignment" "fastapi_ai_user" {
  scope                = azurerm_cognitive_account.foundry.id
  role_definition_name = "Cognitive Services User"
  principal_id         = data.terraform_remote_state.aks.outputs.fastapi_workload_identity_principal_id
}

# ---------------------------------------------------------------------------
# Storage — FastAPI identity
# ---------------------------------------------------------------------------
resource "azurerm_role_assignment" "fastapi_storage_blob_contributor" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.terraform_remote_state.aks.outputs.fastapi_workload_identity_principal_id
}
