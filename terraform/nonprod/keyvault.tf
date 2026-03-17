###############################################################################
# keyvault.tf — Azure Key Vault and secrets
###############################################################################

resource "azurerm_key_vault" "internal" {
  name                       = "kv-int-${var.cluster_name}"
  location                   = var.location
  resource_group_name        = var.resource_group_name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  enable_rbac_authorization  = true
  soft_delete_retention_days = 90
  purge_protection_enabled   = true

  network_acls {
    default_action = "Allow"
    bypass         = "AzureServices"
  }

  tags = merge(var.tags, { vault-type = "internal" })
}

resource "azurerm_key_vault" "external" {
  name                       = "kv-ext-${var.cluster_name}"
  location                   = var.location
  resource_group_name        = var.resource_group_name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  enable_rbac_authorization  = true
  soft_delete_retention_days = 90
  purge_protection_enabled   = true

  network_acls {
    default_action = "Allow"
    bypass         = "AzureServices"
  }

  tags = merge(var.tags, { vault-type = "external" })
}

resource "azurerm_key_vault_secret" "ai_search_endpoint" {
  name         = "ai-search-endpoint"
  value        = "https://${azurerm_search_service.main.name}.search.windows.net"
  key_vault_id = azurerm_key_vault.internal.id
  depends_on   = [azurerm_role_assignment.terraform_kv_officer_internal]
}

resource "azurerm_key_vault_secret" "ai_foundry_endpoint" {
  name         = "ai-foundry-endpoint"
  value        = azurerm_cognitive_account.foundry.endpoint
  key_vault_id = azurerm_key_vault.internal.id
  depends_on   = [azurerm_role_assignment.terraform_kv_officer_internal]
}

resource "azurerm_key_vault_secret" "openai_deployment" {
  name         = "openai-deployment"
  value        = var.openai_deployment_name
  key_vault_id = azurerm_key_vault.internal.id
  depends_on   = [azurerm_role_assignment.terraform_kv_officer_internal]
}

resource "azurerm_key_vault_secret" "ai_search_index" {
  name         = "ai-search-index"
  value        = var.ai_search_index_name
  key_vault_id = azurerm_key_vault.internal.id
  depends_on   = [azurerm_role_assignment.terraform_kv_officer_internal]
}

resource "azurerm_key_vault_secret" "cors_origins" {
  name         = "cors-origins"
  value        = var.cors_origins
  key_vault_id = azurerm_key_vault.internal.id
  depends_on   = [azurerm_role_assignment.terraform_kv_officer_internal]
}

resource "azurerm_key_vault_secret" "storage_account_name" {
  name         = "storage-account-name"
  value        = azurerm_storage_account.main.name
  key_vault_id = azurerm_key_vault.internal.id
  depends_on   = [azurerm_role_assignment.terraform_kv_officer_internal]
}

resource "azurerm_key_vault_secret" "storage_blob_endpoint" {
  name         = "storage-blob-endpoint"
  value        = azurerm_storage_account.main.primary_blob_endpoint
  key_vault_id = azurerm_key_vault.internal.id
  depends_on   = [azurerm_role_assignment.terraform_kv_officer_internal]
}

resource "azurerm_key_vault_secret" "api_key" {
  name         = "api-key"
  value        = "REPLACE_ME_IN_PIPELINE"
  key_vault_id = azurerm_key_vault.external.id
  depends_on   = [azurerm_role_assignment.terraform_kv_officer_external]

  lifecycle {
    ignore_changes = [value]
  }
}
