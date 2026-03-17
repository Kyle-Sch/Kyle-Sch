###############################################################################
# AI Search — ai_search.tf
###############################################################################

resource "azurerm_search_service" "main" {
  name                         = "srch-${var.cluster_name}"
  location                     = var.location
  resource_group_name          = var.resource_group_name
  sku                          = var.ai_search_sku
  replica_count                = var.ai_search_replica_count
  partition_count              = 1
  local_authentication_enabled = false
  authentication_failure_mode  = "http403"

  tags = var.tags
}
