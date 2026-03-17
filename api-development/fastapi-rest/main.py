"""
fastapi-rest/main.py

FastAPI application — CRUD for a "packages" resource.

Endpoints:
  GET    /packages            — list packages (paginated, filterable)
  GET    /packages/{id}       — get a single package
  POST   /packages            — create a package
  PUT    /packages/{id}       — full update
  PATCH  /packages/{id}       — partial update
  DELETE /packages/{id}       — soft-delete (marks status=archived)

Authentication:
  All endpoints require an X-API-Key header validated against the
  API_KEY environment variable.

Run:
  uvicorn main:app --reload
"""

from __future__ import annotations

import os
import uuid
from datetime import datetime, timezone
from typing import Optional

from dotenv import load_dotenv
from fastapi import Depends, FastAPI, Header, HTTPException, Query, status
from fastapi.middleware.cors import CORSMiddleware

from models import (
    ErrorDetail,
    ErrorResponse,
    PackageCreate,
    PackagePatch,
    PackageResponse,
    PackageListResponse,
    PackageStatus,
    PackageType,
    PackageUpdate,
)

load_dotenv()

API_KEY = os.getenv("API_KEY", "dev-insecure-key")

app = FastAPI(
    title="Package Registry API",
    version="1.0.0",
    description="Internal registry for tracking software packages and their metadata.",
    responses={
        401: {"model": ErrorResponse, "description": "Missing or invalid API key"},
        404: {"model": ErrorResponse, "description": "Package not found"},
        422: {"description": "Validation error"},
    },
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=os.getenv("CORS_ORIGINS", "http://localhost:3000").split(","),
    allow_methods=["*"],
    allow_headers=["*"],
)

# ---------------------------------------------------------------------------
# In-memory store (replace with a real DB in production)
# ---------------------------------------------------------------------------
_store: dict[str, dict] = {}


def _now() -> datetime:
    return datetime.now(timezone.utc)


# ---------------------------------------------------------------------------
# Authentication dependency
# ---------------------------------------------------------------------------
def require_api_key(x_api_key: str = Header(..., alias="X-API-Key")) -> str:
    """Validate the X-API-Key header. Raises 401 on failure."""
    if x_api_key != API_KEY:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"errors": [{"code": "AUTH_FAILED", "message": "Invalid or missing API key."}]},
        )
    return x_api_key


# ---------------------------------------------------------------------------
# Helper
# ---------------------------------------------------------------------------
def _get_or_404(package_id: str) -> dict:
    pkg = _store.get(package_id)
    if not pkg:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"errors": [{"code": "NOT_FOUND", "message": f"Package '{package_id}' not found."}]},
        )
    return pkg


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------
@app.get(
    "/packages",
    response_model=PackageListResponse,
    summary="List packages",
    tags=["packages"],
)
def list_packages(
    page: int = Query(1, ge=1, description="Page number"),
    page_size: int = Query(20, ge=1, le=100, description="Items per page"),
    status: Optional[PackageStatus] = Query(None, description="Filter by status"),
    package_type: Optional[PackageType] = Query(None, description="Filter by type"),
    owner: Optional[str] = Query(None, description="Filter by owner"),
    _: str = Depends(require_api_key),
):
    items = list(_store.values())

    # Apply filters
    if status:
        items = [i for i in items if i["status"] == status]
    if package_type:
        items = [i for i in items if i["package_type"] == package_type]
    if owner:
        items = [i for i in items if i["owner"] == owner]

    total = len(items)
    start = (page - 1) * page_size
    page_items = items[start : start + page_size]

    return PackageListResponse(
        items=[PackageResponse(**i) for i in page_items],
        total=total,
        page=page,
        page_size=page_size,
        has_next=(start + page_size) < total,
    )


@app.get(
    "/packages/{package_id}",
    response_model=PackageResponse,
    summary="Get a package",
    tags=["packages"],
)
def get_package(
    package_id: str,
    _: str = Depends(require_api_key),
):
    return PackageResponse(**_get_or_404(package_id))


@app.post(
    "/packages",
    response_model=PackageResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create a package",
    tags=["packages"],
)
def create_package(
    body: PackageCreate,
    _: str = Depends(require_api_key),
):
    # Check for duplicate name+version
    for existing in _store.values():
        if existing["name"] == body.name and existing["version"] == body.version:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail={
                    "errors": [{
                        "code": "CONFLICT",
                        "message": f"Package '{body.name}@{body.version}' already exists.",
                    }]
                },
            )

    now = _now()
    pkg_id = str(uuid.uuid4())
    record = {
        "id": pkg_id,
        "status": PackageStatus.ACTIVE,
        "created_at": now,
        "updated_at": now,
        **body.model_dump(),
    }
    _store[pkg_id] = record
    return PackageResponse(**record)


@app.put(
    "/packages/{package_id}",
    response_model=PackageResponse,
    summary="Full update of a package",
    tags=["packages"],
)
def update_package(
    package_id: str,
    body: PackageUpdate,
    _: str = Depends(require_api_key),
):
    existing = _get_or_404(package_id)
    existing.update({**body.model_dump(), "updated_at": _now()})
    _store[package_id] = existing
    return PackageResponse(**existing)


@app.patch(
    "/packages/{package_id}",
    response_model=PackageResponse,
    summary="Partial update of a package",
    tags=["packages"],
)
def patch_package(
    package_id: str,
    body: PackagePatch,
    _: str = Depends(require_api_key),
):
    existing = _get_or_404(package_id)
    updates = body.model_dump(exclude_unset=True)
    existing.update({**updates, "updated_at": _now()})
    _store[package_id] = existing
    return PackageResponse(**existing)


@app.delete(
    "/packages/{package_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Archive (soft-delete) a package",
    tags=["packages"],
)
def delete_package(
    package_id: str,
    _: str = Depends(require_api_key),
):
    existing = _get_or_404(package_id)
    existing["status"] = PackageStatus.ARCHIVED
    existing["updated_at"] = _now()
    _store[package_id] = existing


# ---------------------------------------------------------------------------
# Health probes (no auth required — called by K8s liveness/readiness probes)
# ---------------------------------------------------------------------------
@app.get("/healthz/live", include_in_schema=False)
def liveness():
    return {"status": "ok"}


@app.get("/healthz/ready", include_in_schema=False)
def readiness():
    # Add any dependency checks here (DB ping, etc.)
    return {"status": "ok"}
