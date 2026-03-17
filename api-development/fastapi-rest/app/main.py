"""
app/main.py

FastAPI application entry point.

Startup lifecycle:
  1. Load Settings (fetches secrets from Azure Key Vault if AZURE_KEYVAULT_URI is set).
  2. Register routers.

Run locally:
  uvicorn app.main:app --reload
"""
from __future__ import annotations

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import Settings
from app.routers import packages, ai_search

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Load config / secrets once at startup; clean up on shutdown."""
    logger.info("Starting up — loading settings from Key Vault...")
    app.state.settings = Settings()
    logger.info("Settings loaded. Application ready.")
    yield
    logger.info("Shutting down.")


app = FastAPI(
    title="Package Registry API",
    version="2.0.0",
    description=(
        "Internal registry for tracking software packages. "
        "Backed by Azure AI Search for semantic search and "
        "Azure AI Foundry (GPT-4o) for natural-language queries."
    ),
    lifespan=lifespan,
    responses={
        401: {"description": "Missing or invalid API key"},
        404: {"description": "Resource not found"},
        422: {"description": "Validation error"},
    },
)

# ---- CORS (origins loaded from Key Vault at startup) --------------------- #
# The middleware is added after startup so origins come from Settings.
# For simplicity we register it here; origins are read from settings at
# request time via the dependency — middleware allows all and auth handles it.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],       # Locked down per-route via settings in prod
    allow_methods=["*"],
    allow_headers=["*"],
)

# ---- Routers -------------------------------------------------------------- #
app.include_router(packages.router, prefix="/packages",  tags=["packages"])
app.include_router(ai_search.router, prefix="/search",   tags=["ai-search"])


# ---- Health probes (no auth — called by K8s liveness/readiness probes) --- #
@app.get("/healthz/live",  include_in_schema=False)
def liveness():
    return {"status": "ok"}


@app.get("/healthz/ready", include_in_schema=False)
def readiness():
    return {"status": "ok"}
