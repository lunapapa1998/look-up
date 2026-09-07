from __future__ import annotations

from datetime import datetime
from enum import Enum

from pydantic import BaseModel, Field, model_validator


class SpeciesType(str, Enum):
    BIRD = "bird"
    STAR = "star"


class ObservationCreate(BaseModel):
    speciesType: SpeciesType
    speciesName: str = Field(min_length=1)
    note: str | None = None
    photoUrl: str | None = None
    observedAt: datetime | None = None
    lat: float | None = None
    lng: float | None = None


class ObservationUpdate(BaseModel):
    speciesType: SpeciesType | None = None
    speciesName: str | None = Field(default=None, min_length=1)
    note: str | None = None
    photoUrl: str | None = None
    observedAt: datetime | None = None
    lat: float | None = None
    lng: float | None = None

    @model_validator(mode="after")
    def _reject_explicit_null_species(self) -> "ObservationUpdate":
        if "speciesType" in self.model_fields_set and self.speciesType is None:
            raise ValueError("speciesType cannot be set to null")
        if "speciesName" in self.model_fields_set and self.speciesName is None:
            raise ValueError("speciesName cannot be set to null")
        if "observedAt" in self.model_fields_set and self.observedAt is None:
            raise ValueError("observedAt cannot be set to null")
        return self


class Observation(BaseModel):
    id: int
    speciesType: SpeciesType
    speciesName: str
    note: str | None = None
    photoUrl: str | None = None
    observedAt: datetime
    lat: float | None = None
    lng: float | None = None
    createdAt: datetime


class Badge(BaseModel):
    id: str
    name: str
    description: str
    targetCount: int


class BadgeProgress(BaseModel):
    badge: Badge
    achieved: bool
    currentCount: int
