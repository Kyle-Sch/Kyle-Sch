###############################################################################
# Platform Services — variables.tf
###############################################################################

variable "resource_group_name" {
  description = "Resource group for all platform services."
  type        = string
}

variable "location" {
  description = "Azure region (e.g. 'eastus2')."
  type        = string
  default     = "eastus2"
}

variable "cluster_name" {
  description = "Cluster name used as a naming prefix for resources."
  type        = string
}

variable "tags" {
  description = "Map of tags to apply to all resources."
  type        = map(string)
  default     = {}
}

# ---------------------------------------------------------------------------
# Azure Storage
# ---------------------------------------------------------------------------
variable "storage_account_name" {
  description = "Globally unique storage account name (3-24 lowercase alphanumeric chars)."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.storage_account_name))
    error_message = "Storage account name must be 3-24 lowercase letters or numbers."
  }
}

variable "replication_type" {
  description = "Storage replication strategy: LRS | GRS | ZRS | GZRS."
  type        = string
  default     = "ZRS"

  validation {
    condition     = contains(["LRS", "GRS", "ZRS", "GZRS", "RA-GRS", "RA-GZRS"], var.replication_type)
    error_message = "Invalid replication type."
  }
}

variable "container_names" {
  description = "List of blob container names to create within the storage account."
  type        = list(string)
  default     = ["data", "logs", "archive"]
}

variable "soft_delete_retention_days" {
  description = "Number of days blobs and containers are retained after deletion."
  type        = number
  default     = 14
}

variable "allowed_ip_ranges" {
  description = "List of public IP/CIDR ranges allowed to access the storage account."
  type        = list(string)
  default     = []
}

variable "allowed_subnet_ids" {
  description = "List of VNet subnet resource IDs allowed to access the storage account."
  type        = list(string)
  default     = []
}

# ---------------------------------------------------------------------------
# Azure AI Search
# ---------------------------------------------------------------------------
variable "ai_search_sku" {
  description = "SKU for Azure AI Search (free | basic | standard | standard2 | standard3)."
  type        = string
  default     = "standard"
  validation {
    condition     = contains(["free", "basic", "standard", "standard2", "standard3"], var.ai_search_sku)
    error_message = "ai_search_sku must be one of: free, basic, standard, standard2, standard3."
  }
}

variable "ai_search_replica_count" {
  description = "Number of replicas for AI Search."
  type        = number
  default     = 1
}

variable "ai_search_index_name" {
  description = "Name of the AI Search index the FastAPI app will use."
  type        = string
  default     = "packages-index"
}

# ---------------------------------------------------------------------------
# Azure AI Foundry
# ---------------------------------------------------------------------------
variable "ai_foundry_sku" {
  description = "SKU for the Azure Cognitive Services / AI Foundry account (S0 | S1)."
  type        = string
  default     = "S0"
}

variable "openai_deployment_name" {
  description = "Name of the OpenAI model deployment inside AI Foundry (e.g. gpt-4o)."
  type        = string
  default     = "gpt-4o"
}

variable "gpt45_deployment_name" {
  description = "Name of the GPT-4.5 deployment inside AI Foundry."
  type        = string
  default     = "gpt-4.5"
}

variable "gpt45_capacity_tpm" {
  description = "Token-per-minute capacity (in thousands) for the GPT-4.5 deployment."
  type        = number
  default     = 10
}

variable "codex_deployment_name" {
  description = "Name of the Codex deployment inside AI Foundry."
  type        = string
  default     = "codex"
}

variable "codex_capacity_tpm" {
  description = "Token-per-minute capacity (in thousands) for the Codex deployment."
  type        = number
  default     = 10
}

variable "model_router_deployment_name" {
  description = "Name of the Model Router deployment inside AI Foundry."
  type        = string
  default     = "model-router"
}

variable "model_router_capacity_tpm" {
  description = "Token-per-minute capacity (in thousands) for the Model Router deployment."
  type        = number
  default     = 20
}

# ---------------------------------------------------------------------------
# Azure API Management
# ---------------------------------------------------------------------------
variable "apim_sku_name" {
  description = "APIM SKU in '<tier>_<units>' format (Developer_1 | Standard_1 | Premium_2)."
  type        = string
  default     = "Developer_1"
}

variable "apim_publisher_name" {
  description = "Publisher display name shown in the APIM developer portal."
  type        = string
  default     = "Platform Team"
}

variable "apim_publisher_email" {
  description = "Publisher contact email for APIM notifications."
  type        = string
  default     = "platform@example.com"
}

variable "apim_tenant_id" {
  description = "Azure AD / Entra ID tenant GUID — injected into JWT validation policy."
  type        = string
}

variable "apim_audience" {
  description = "App registration client ID used as the API audience (api://<client-id>)."
  type        = string
}

variable "apim_backend_url" {
  description = "URL of the FastAPI backend reachable from APIM (in-cluster DNS or private endpoint)."
  type        = string
  default     = "http://worker-service.api.svc.cluster.local:8080"
}

variable "apim_cors_origins" {
  description = "List of allowed CORS origins injected into the APIM policy template."
  type        = list(string)
  default     = ["https://portal.example.com"]
}

# ---------------------------------------------------------------------------
# Key Vault secrets
# ---------------------------------------------------------------------------
variable "cors_origins" {
  description = "Comma-separated list of allowed CORS origins stored in Key Vault."
  type        = string
  default     = "https://portal.example.com"
}
