"""
app/routers/packages.py

CRUD endpoints for the packages resource.
"""
from __future__ import annotations

import uuid
from datetime import datetime, timezone
from typing import Annotated, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.dependencies import require_api_key
from app.models import (
    PackageCreate,
    PackagePatch,
    PackageResponse,
    PackageListResponse,
    PackageStatus,
    PackageType,
    PackageUpdate,
)

router = APIRouter()

# In-memory store — replace with a real DB / Cosmos / Postgres in production
_store: dict[str, dict] = {}


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _get_or_404(package_id: str) -> dict:
    pkg = _store.get(package_id)
    if not pkg:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"errors": [{"code": "NOT_FOUND", "message": f"Package '{package_id}' not found."}]},
        )
    return pkg


@router.get("", response_model=PackageListResponse, summary="List packages")
def list_packages(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    pkg_status: Optional[PackageStatus] = Query(None, alias="status"),
    package_type: Optional[PackageType] = Query(None),
    owner: Optional[str] = Query(None),
    _: str = Depends(require_api_key),
):
    items = list(_store.values())
    if pkg_status:
        items = [i for i in items if i["status"] == pkg_status]
    if package_type:
        items = [i for i in items if i["package_type"] == package_type]
    if owner:
        items = [i for i in items if i["owner"] == owner]

    total = len(items)
    start = (page - 1) * page_size
    return PackageListResponse(
        items=[PackageResponse(**i) for i in items[start: start + page_size]],
        total=total,
        page=page,
        page_size=page_size,
        has_next=(start + page_size) < total,
    )


@router.get("/{package_id}", response_model=PackageResponse, summary="Get a package")
def get_package(package_id: str, _: str = Depends(require_api_key)):
    return PackageResponse(**_get_or_404(package_id))


@router.post("", response_model=PackageResponse, status_code=status.HTTP_201_CREATED, summary="Create a package")
def create_package(body: PackageCreate, _: str = Depends(require_api_key)):
    for existing in _store.values():
        if existing["name"] == body.name and existing["version"] == body.version:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail={"errors": [{"code": "CONFLICT", "message": f"Package '{body.name}@{body.version}' already exists."}]},
            )
    now = _now()
    pkg_id = str(uuid.uuid4())
    record = {"id": pkg_id, "status": PackageStatus.ACTIVE, "created_at": now, "updated_at": now, **body.model_dump()}
    _store[pkg_id] = record
    return PackageResponse(**record)


@router.put("/{package_id}", response_model=PackageResponse, summary="Full update")
def update_package(package_id: str, body: PackageUpdate, _: str = Depends(require_api_key)):
    existing = _get_or_404(package_id)
    existing.update({**body.model_dump(), "updated_at": _now()})
    _store[package_id] = existing
    return PackageResponse(**existing)


@router.patch("/{package_id}", response_model=PackageResponse, summary="Partial update")
def patch_package(package_id: str, body: PackagePatch, _: str = Depends(require_api_key)):
    existing = _get_or_404(package_id)
    existing.update({**body.model_dump(exclude_unset=True), "updated_at": _now()})
    _store[package_id] = existing
    return PackageResponse(**existing)


@router.delete("/{package_id}", status_code=status.HTTP_204_NO_CONTENT, summary="Archive (soft-delete)")
def delete_package(package_id: str, _: str = Depends(require_api_key)):
    existing = _get_or_404(package_id)
    existing["status"] = PackageStatus.ARCHIVED
    existing["updated_at"] = _now()
    _store[package_id] = existing
