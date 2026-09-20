from __future__ import annotations

from enum import Enum
from typing import Literal

from pydantic import BaseModel, Field


class ObsMode(str, Enum):
    DAY = "day"
    NIGHT = "night"


class Location(BaseModel):
    lat: float
    lng: float


class GoldenHour(BaseModel):
    mode: str
    label: str
    timeRange: str
    description: str


class Moon(BaseModel):
    illumination: int = Field(ge=0, le=100)
    phaseName: str
    moonrise: str | None
    moonset: str | None
    status: Literal["live", "approx", "unavailable"]


class TelemetryReading(BaseModel):
    kind: str
    label: str
    value: str


class LayerScore(BaseModel):
    key: str
    weight: float
    subScore: int
    status: str


class SuitabilityResponse(BaseModel):
    mode: str
    location: Location
    score: int
    label: str
    sqmValue: float
    skyClass: str
    bortleClass: int
    nightSkyStatus: str
    degraded: bool
    weatherRefreshing: bool = False
    goldenHours: list[GoldenHour]
    telemetry: list[TelemetryReading]
    layers: list[LayerScore]
    moon: Moon | None = None
