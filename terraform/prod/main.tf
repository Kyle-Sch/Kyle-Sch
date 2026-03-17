###############################################################################
# Platform Services — main.tf (prod)
# Contains: Storage, AI Search, AI Foundry, APIM, Key Vault
###############################################################################

terraform {
  required_version = ">= 1.5"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
    azapi = {
      source  = "azure/azapi"
      version = "~> 1.15"
    }
  }

  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "sttfstate"
    container_name       = "tfstate"
    key                  = "prod/platform.tfstate"
  }
}

provider "azurerm" {
  features {}
}

provider "azapi" {}

# ---------------------------------------------------------------------------
# AKS remote state — provides workload identity principal ID and log analytics
# ---------------------------------------------------------------------------
data "terraform_remote_state" "aks" {
  backend = "azurerm"
  config = {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "sttfstate"
    container_name       = "tfstate"
    key                  = "aks/prod/aks-cluster.tfstate"
  }
}
