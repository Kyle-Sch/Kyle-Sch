"""
app/config.py

Settings loaded at startup from two Key Vaults:

  AZURE_KEYVAULT_INTERNAL_URI  — infrastructure secrets written by Terraform
                                  (AI Search endpoint, AI Foundry endpoint, etc.)

  AZURE_KEYVAULT_EXTERNAL_URI  — 3rd-party / pipeline-managed secrets
                                  (API key, external service credentials, etc.)

Both vaults use DefaultAzureCredential — no passwords in code.
In AKS the workload identity federated token is picked up automatically.
When neither URI is set the app falls back to environment variables (local dev only).
"""
from __future__ import annotations

import logging
import os

from dotenv import load_dotenv

load_dotenv()

logger = logging.getLogger(__name__)


class Settings:
    """Application settings. Instantiated once during lifespan startup."""

    # ------------------------------------------------------------------ #
    # Internal KV secret names (Terraform-managed)                        #
    # ------------------------------------------------------------------ #
    _INT_AI_SEARCH_EP      = "ai-search-endpoint"
    _INT_AI_FOUNDRY_EP     = "ai-foundry-endpoint"
    _INT_OPENAI_DEPLOYMENT = "openai-deployment"
    _INT_AI_SEARCH_INDEX   = "ai-search-index"
    _INT_CORS_ORIGINS      = "cors-origins"

    # ------------------------------------------------------------------ #
    # External KV secret names (3rd-party / pipeline-managed)             #
    # ------------------------------------------------------------------ #
    _EXT_API_KEY = "api-key"
    # Add more 3rd-party secret names here, e.g.:
    # _EXT_SENDGRID_KEY = "sendgrid-api-key"
    # _EXT_STRIPE_KEY   = "stripe-secret-key"

    def __init__(self) -> None:
        internal_uri = os.getenv("AZURE_KEYVAULT_INTERNAL_URI")
        external_uri = os.getenv("AZURE_KEYVAULT_EXTERNAL_URI")

        if internal_uri and external_uri:
            self._load_from_keyvaults(internal_uri, external_uri)
        else:
            logger.warning(
                "AZURE_KEYVAULT_INTERNAL_URI or AZURE_KEYVAULT_EXTERNAL_URI not set — "
                "falling back to environment variables. Do NOT use this in production."
            )
            self._load_from_env()

    # ------------------------------------------------------------------ #
    # Loaders                                                              #
    # ------------------------------------------------------------------ #
    def _load_from_keyvaults(self, internal_uri: str, external_uri: str) -> None:
        """Fetch secrets from both Key Vaults using a single shared credential.

        One DefaultAzureCredential instance is reused across both clients —
        the workload identity token works for any vault the pod's identity
        has been granted access to.
        """
        from azure.identity import DefaultAzureCredential
        from azure.keyvault.secrets import SecretClient

        logger.info("Loading internal secrets from: %s", internal_uri)
        logger.info("Loading external secrets from: %s", external_uri)

        credential = DefaultAzureCredential()
        internal = SecretClient(vault_url=internal_uri, credential=credential)
        external = SecretClient(vault_url=external_uri, credential=credential)

        def _get(client: SecretClient, name: str) -> str:
            return client.get_secret(name).value or ""

        # --- Internal vault ---
        self.ai_search_endpoint  = _get(internal, self._INT_AI_SEARCH_EP)
        self.ai_foundry_endpoint = _get(internal, self._INT_AI_FOUNDRY_EP)
        self.openai_deployment   = _get(internal, self._INT_OPENAI_DEPLOYMENT)
        self.ai_search_index     = _get(internal, self._INT_AI_SEARCH_INDEX)
        self.cors_origins        = _get(internal, self._INT_CORS_ORIGINS).split(",")

        # --- External vault ---
        self.api_key = _get(external, self._EXT_API_KEY)
        # self.sendgrid_api_key = _get(external, self._EXT_SENDGRID_KEY)

        logger.info("All secrets loaded from both Key Vaults.")

    def _load_from_env(self) -> None:
        """Read secrets from environment variables for local development."""
        self.ai_search_endpoint  = os.getenv("AI_SEARCH_ENDPOINT", "")
        self.ai_foundry_endpoint = os.getenv("AI_FOUNDRY_ENDPOINT", "")
        self.openai_deployment   = os.getenv("OPENAI_DEPLOYMENT", "gpt-4o")
        self.ai_search_index     = os.getenv("AI_SEARCH_INDEX", "packages-index")
        self.cors_origins        = os.getenv("CORS_ORIGINS", "http://localhost:3000").split(",")
        self.api_key             = os.getenv("API_KEY", "dev-insecure-key")
