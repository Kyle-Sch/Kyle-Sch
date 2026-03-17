###############################################################################
# apim.tf — Azure API Management
###############################################################################

resource "azurerm_application_insights" "apim" {
  name                = "appi-${var.cluster_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  workspace_id        = data.terraform_remote_state.aks.outputs.log_analytics_workspace_id
  application_type    = "web"

  tags = var.tags
}

resource "azurerm_api_management" "main" {
  name                = "apim-${var.cluster_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  publisher_name      = var.apim_publisher_name
  publisher_email     = var.apim_publisher_email
  sku_name            = var.apim_sku_name

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

resource "azurerm_api_management_logger" "app_insights" {
  name                = "apim-appinsights-logger"
  api_management_name = azurerm_api_management.main.name
  resource_group_name = var.resource_group_name
  resource_id         = azurerm_application_insights.apim.id

  application_insights {
    instrumentation_key = azurerm_application_insights.apim.instrumentation_key
  }
}

resource "azurerm_api_management_diagnostic" "app_insights" {
  identifier               = "applicationinsights"
  resource_group_name      = var.resource_group_name
  api_management_name      = azurerm_api_management.main.name
  api_management_logger_id = azurerm_api_management_logger.app_insights.id

  sampling_percentage       = 5.0
  always_log_errors         = true
  log_client_ip             = true
  verbosity                 = "information"
  http_correlation_protocol = "W3C"
}

resource "azurerm_api_management_backend" "fastapi" {
  name                = "backend-fastapi"
  resource_group_name = var.resource_group_name
  api_management_name = azurerm_api_management.main.name
  protocol            = "http"
  url                 = var.apim_backend_url
}

resource "azurerm_api_management_api" "packages" {
  name                  = "packages-api"
  resource_group_name   = var.resource_group_name
  api_management_name   = azurerm_api_management.main.name
  revision              = "1"
  display_name          = "Packages API"
  path                  = "packages"
  protocols             = ["https"]
  subscription_required = true
  service_url           = var.apim_backend_url
}

resource "azurerm_api_management_api_policy" "packages" {
  api_name            = azurerm_api_management_api.packages.name
  api_management_name = azurerm_api_management.main.name
  resource_group_name = var.resource_group_name

  xml_content = templatefile("${path.module}/policies/api-policy.xml.tpl", {
    tenant_id       = var.apim_tenant_id
    audience        = var.apim_audience
    allowed_origins = var.apim_cors_origins
  })
}
