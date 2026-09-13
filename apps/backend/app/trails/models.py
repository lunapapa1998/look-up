from __future__ import annotations

from pydantic import BaseModel


class Coordinate(BaseModel):
    lat: float
    lng: float


class NightSky(BaseModel):
    sqmValue: float
    bortleClass: int
    skyClass: str
    status: str


class HeritageEat(BaseModel):
    name: str
    addr: str
    distanceM: int
    lat: float
    lng: float
    contentId: str


class CourseSuitability(BaseModel):
    score: int
    label: str
    status: str


class TrailCourse(BaseModel):
    crsIdx: str
    name: str
    sigun: str
    distanceKm: float
    durationMin: int
    level: int
    cycle: str
    gpxUrl: str
    start: Coordinate
    end: Coordinate
    nightSky: NightSky
    heritageEats: list[HeritageEat]
    daySuitability: CourseSuitability | None
    nightSuitability: CourseSuitability | None


class TrailsResponse(BaseModel):
    region: str
    degraded: bool
    courses: list[TrailCourse]


class ElevationPoint(BaseModel):
    positionRatio: float
    elevationM: float


class TrailDetailResponse(BaseModel):
    crsIdx: str
    found: bool
    description: str | None
    themeId: str | None
    startName: str | None
    endName: str | None
    travelerInfo: str | None
    tourInfo: str | None
    elevationProfile: list[ElevationPoint]
    degraded: bool
