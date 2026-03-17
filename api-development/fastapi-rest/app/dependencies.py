"""
app/dependencies.py

FastAPI dependency callables shared across routers.

AI clients use Azure DefaultAzureCredential — no API keys stored anywhere.
In AKS the workload identity token is picked up automatically from the
projected service account token volume (AZURE_FEDERATED_TOKEN_FILE env var).
"""
from __future__ import annotations

from functools import lru_cache
from typing import Annotated

from azure.identity import DefaultAzureCredential, get_bearer_token_provider
from azure.search.documents import SearchClient
from azure.search.documents.aio import SearchClient as AsyncSearchClient
from fastapi import Depends, Header, HTTPException, Request, status
from openai import AzureOpenAI

from app.config import Settings


# --------------------------------------------------------------------------- #
# Settings singleton — injected via FastAPI app state                          #
# --------------------------------------------------------------------------- #
def get_settings(request: Request) -> Settings:
    """Return the Settings object stored on app.state at startup."""
    return request.app.state.settings


# --------------------------------------------------------------------------- #
# Authentication                                                               #
# --------------------------------------------------------------------------- #
def require_api_key(
    x_api_key: Annotated[str, Header(alias="X-API-Key")],
    settings: Annotated[Settings, Depends(get_settings)],
) -> str:
    """Validate the X-API-Key header against the secret loaded from Key Vault."""
    if x_api_key != settings.api_key:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"errors": [{"code": "AUTH_FAILED", "message": "Invalid or missing API key."}]},
        )
    return x_api_key


# --------------------------------------------------------------------------- #
# Azure AI Search client                                                       #
# --------------------------------------------------------------------------- #
def get_search_client(
    settings: Annotated[Settings, Depends(get_settings)],
) -> SearchClient:
    """Synchronous AI Search client using workload identity (no API key)."""
    credential = DefaultAzureCredential()
    return SearchClient(
        endpoint=settings.ai_search_endpoint,
        index_name=settings.ai_search_index,
        credential=credential,
    )


# --------------------------------------------------------------------------- #
# Azure OpenAI / AI Foundry client                                            #
# --------------------------------------------------------------------------- #
def get_openai_client(
    settings: Annotated[Settings, Depends(get_settings)],
) -> AzureOpenAI:
    """AzureOpenAI client using workload identity bearer token (no API key)."""
    credential = DefaultAzureCredential()
    token_provider = get_bearer_token_provider(
        credential, "https://cognitiveservices.azure.com/.default"
    )
    return AzureOpenAI(
        azure_endpoint=settings.ai_foundry_endpoint,
        azure_ad_token_provider=token_provider,
        api_version="2024-12-01-preview",
    )
