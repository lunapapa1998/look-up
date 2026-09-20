from __future__ import annotations

from pydantic import BaseModel


class Coordinate(BaseModel):
    lat: float
    lng: float


class RegionSummary(BaseModel):
    id: str
    label: str
    distanceKm: float
    center: Coordinate
    hasStarSpot: bool


class RegionsResponse(BaseModel):
    nearestId: str
    regions: list[RegionSummary]
