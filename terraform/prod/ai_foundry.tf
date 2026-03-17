###############################################################################
# AI Foundry — ai_foundry.tf
###############################################################################

resource "azurerm_cognitive_account" "foundry" {
  name                          = "ai-${var.cluster_name}"
  location                      = var.location
  resource_group_name           = var.resource_group_name
  kind                          = "AIServices"
  sku_name                      = var.ai_foundry_sku
  custom_subdomain_name         = "ai-${var.cluster_name}"
  local_auth_enabled            = false
  public_network_access_enabled = true

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

resource "azapi_resource" "gpt45" {
  type      = "Microsoft.CognitiveServices/accounts/deployments@2024-10-01"
  name      = var.gpt45_deployment_name
  parent_id = azurerm_cognitive_account.foundry.id

  body = jsonencode({
    sku = {
      name     = "GlobalStandard"
      capacity = var.gpt45_capacity_tpm
    }
    properties = {
      model = {
        format  = "OpenAI"
        name    = "gpt-4.5"
        version = "2025-02-27"
      }
    }
  })

  response_export_values    = ["name", "properties.model"]
  ignore_missing_property   = true
  schema_validation_enabled = false
}

resource "azapi_resource" "codex" {
  type      = "Microsoft.CognitiveServices/accounts/deployments@2024-10-01"
  name      = var.codex_deployment_name
  parent_id = azurerm_cognitive_account.foundry.id

  body = jsonencode({
    sku = {
      name     = "Standard"
      capacity = var.codex_capacity_tpm
    }
    properties = {
      model = {
        format  = "OpenAI"
        name    = "codex"
        version = "2025-04-14"
      }
    }
  })

  response_export_values    = ["name", "properties.model"]
  ignore_missing_property   = true
  schema_validation_enabled = false
}

resource "azapi_resource" "model_router" {
  type      = "Microsoft.CognitiveServices/accounts/deployments@2024-10-01"
  name      = var.model_router_deployment_name
  parent_id = azurerm_cognitive_account.foundry.id

  body = jsonencode({
    sku = {
      name     = "GlobalStandard"
      capacity = var.model_router_capacity_tpm
    }
    properties = {
      model = {
        format  = "OpenAI"
        name    = "model-router"
        version = "2025-05-19"
      }
    }
  })

  response_export_values    = ["name", "properties.model"]
  ignore_missing_property   = true
  schema_validation_enabled = false
}
