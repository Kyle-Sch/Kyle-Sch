"""
fastapi-rest/models.py

Pydantic models for the packages API.
"""

from __future__ import annotations

from datetime import datetime
from enum import Enum
from typing import Optional

from pydantic import BaseModel, Field, field_validator


# ---------------------------------------------------------------------------
# Enumerations
# ---------------------------------------------------------------------------
class PackageStatus(str, Enum):
    PENDING = "pending"
    ACTIVE = "active"
    DEPRECATED = "deprecated"
    ARCHIVED = "archived"


class PackageType(str, Enum):
    LIBRARY = "library"
    FRAMEWORK = "framework"
    TOOL = "tool"
    SERVICE = "service"


# ---------------------------------------------------------------------------
# Base model — fields shared across request and response
# ---------------------------------------------------------------------------
class PackageBase(BaseModel):
    name: str = Field(..., min_length=1, max_length=200, description="Package name")
    version: str = Field(..., pattern=r"^\d+\.\d+\.\d+$", description="Semantic version (X.Y.Z)")
    description: Optional[str] = Field(None, max_length=1000)
    package_type: PackageType = Field(PackageType.LIBRARY, description="Package category")
    tags: list[str] = Field(default_factory=list, max_length=20)
    owner: str = Field(..., min_length=1, max_length=100, description="Owning team or user")

    @field_validator("name")
    @classmethod
    def name_lowercase(cls, v: str) -> str:
        return v.strip().lower()

    @field_validator("tags")
    @classmethod
    def tags_lowercase(cls, v: list[str]) -> list[str]:
        return [t.strip().lower() for t in v]


# ---------------------------------------------------------------------------
# Request models
# ---------------------------------------------------------------------------
class PackageCreate(PackageBase):
    """Request body for POST /packages."""
    pass


class PackageUpdate(BaseModel):
    """Request body for PUT /packages/{id} — all fields required."""
    name: str = Field(..., min_length=1, max_length=200)
    version: str = Field(..., pattern=r"^\d+\.\d+\.\d+$")
    description: Optional[str] = Field(None, max_length=1000)
    package_type: PackageType
    tags: list[str] = Field(default_factory=list)
    owner: str = Field(..., min_length=1, max_length=100)
    status: PackageStatus


class PackagePatch(BaseModel):
    """Request body for PATCH /packages/{id} — all fields optional."""
    name: Optional[str] = Field(None, min_length=1, max_length=200)
    version: Optional[str] = Field(None, pattern=r"^\d+\.\d+\.\d+$")
    description: Optional[str] = Field(None, max_length=1000)
    package_type: Optional[PackageType] = None
    tags: Optional[list[str]] = None
    owner: Optional[str] = Field(None, min_length=1, max_length=100)
    status: Optional[PackageStatus] = None


# ---------------------------------------------------------------------------
# Response models
# ---------------------------------------------------------------------------
class PackageResponse(PackageBase):
    """Full package representation returned by the API."""
    id: str = Field(..., description="Unique package identifier (UUID)")
    status: PackageStatus = PackageStatus.ACTIVE
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class PackageListResponse(BaseModel):
    """Paginated list of packages."""
    items: list[PackageResponse]
    total: int
    page: int
    page_size: int
    has_next: bool


# ---------------------------------------------------------------------------
# Error response model
# ---------------------------------------------------------------------------
class ErrorDetail(BaseModel):
    code: str
    message: str
    field: Optional[str] = None


class ErrorResponse(BaseModel):
    errors: list[ErrorDetail]
    request_id: Optional[str] = None
