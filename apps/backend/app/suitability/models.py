from __future__ import annotations

from enum import Enum

from pydantic import BaseModel


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
    degraded: bool
    goldenHours: list[GoldenHour]
    telemetry: list[TelemetryReading]
    layers: list[LayerScore]
