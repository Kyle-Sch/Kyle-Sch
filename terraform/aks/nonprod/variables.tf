###############################################################################
# AKS Cluster — variables.tf
###############################################################################

variable "resource_group_name" {
  description = "Name of the Azure Resource Group to create."
  type        = string
}

variable "location" {
  description = "Azure region for all resources (e.g. 'eastus2')."
  type        = string
  default     = "eastus2"
}

variable "environment" {
  description = "Deployment environment tag (dev | staging | prod)."
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "cluster_name" {
  description = "Name of the AKS cluster (also used as a prefix for related resources)."
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version to deploy. Must be supported in the chosen region."
  type        = string
  default     = "1.29"
}

# ---------------------------------------------------------------------------
# Networking
# ---------------------------------------------------------------------------
variable "vnet_address_space" {
  description = "CIDR block for the Virtual Network."
  type        = string
  default     = "10.10.0.0/16"
}

variable "aks_subnet_prefix" {
  description = "CIDR block for the AKS node subnet (must be within vnet_address_space)."
  type        = string
  default     = "10.10.1.0/24"
}

# ---------------------------------------------------------------------------
# System node pool
# ---------------------------------------------------------------------------
variable "system_node_vm_size" {
  description = "VM SKU for the system node pool."
  type        = string
  default     = "Standard_D2s_v5"
}

variable "system_node_count" {
  description = "Initial node count for the system pool."
  type        = number
  default     = 2
}

variable "system_node_min_count" {
  description = "Minimum node count for system pool autoscaler."
  type        = number
  default     = 2
}

variable "system_node_max_count" {
  description = "Maximum node count for system pool autoscaler."
  type        = number
  default     = 4
}

# ---------------------------------------------------------------------------
# App node pool
# ---------------------------------------------------------------------------
variable "app_node_vm_size" {
  description = "VM SKU for the application node pool."
  type        = string
  default     = "Standard_D4s_v5"
}

variable "app_node_min_count" {
  description = "Minimum node count for app pool autoscaler."
  type        = number
  default     = 2
}

variable "app_node_max_count" {
  description = "Maximum node count for app pool autoscaler."
  type        = number
  default     = 10
}

# ---------------------------------------------------------------------------
# Tags
# ---------------------------------------------------------------------------
variable "tags" {
  description = "Map of tags to apply to all resources."
  type        = map(string)
  default     = {}
}

# ---------------------------------------------------------------------------
# Workload Identity / FastAPI
# ---------------------------------------------------------------------------
variable "fastapi_namespace" {
  description = "Kubernetes namespace where the FastAPI workload runs."
  type        = string
  default     = "api"
}

variable "fastapi_service_account_name" {
  description = "Name of the Kubernetes ServiceAccount used by the FastAPI pod."
  type        = string
  default     = "fastapi-sa"
}

variable "acr_id" {
  description = "Resource ID of the Azure Container Registry. Leave empty to skip AcrPull assignment."
  type        = string
  default     = ""
}

# ---------------------------------------------------------------------------
# App Deployment
# ---------------------------------------------------------------------------
variable "keyvault_internal_uri" {
  description = "URI of the internal Key Vault (output from the platform apply)."
  type        = string
}

variable "keyvault_external_uri" {
  description = "URI of the external Key Vault (output from the platform apply)."
  type        = string
}

variable "image_repository" {
  description = "Container image repository (e.g. myacr.azurecr.io/fastapi)."
  type        = string
}

variable "image_tag" {
  description = "Container image tag to deploy."
  type        = string
  default     = "latest"
}

variable "replicas" {
  description = "Initial replica count for the Deployment."
  type        = number
  default     = 2
}

variable "min_replicas" {
  description = "Minimum replica count for the HPA."
  type        = number
  default     = 2
}

variable "max_replicas" {
  description = "Maximum replica count for the HPA."
  type        = number
  default     = 10
}

variable "cpu_request" {
  description = "CPU request for the FastAPI container."
  type        = string
  default     = "250m"
}

variable "cpu_limit" {
  description = "CPU limit for the FastAPI container."
  type        = string
  default     = "500m"
}

variable "memory_request" {
  description = "Memory request for the FastAPI container."
  type        = string
  default     = "256Mi"
}

variable "memory_limit" {
  description = "Memory limit for the FastAPI container."
  type        = string
  default     = "512Mi"
}
