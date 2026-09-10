from __future__ import annotations

from typing import Literal

from pydantic import BaseModel


class Coordinate(BaseModel):
    lat: float
    lng: float


class BirdSpecies(BaseModel):
    nameKo: str
    nameSci: str
    speciesCode: str
    count: int | None
    obsDt: str


class BirdObservation(BaseModel):
    speciesCount: int
    topSpecies: list[BirdSpecies]
    mostRecentObsDt: str
    status: str = "community"


class NightSky(BaseModel):
    sqmValue: float
    bortleClass: int
    skyClass: str
    status: str = "approx"


class HeritageInfo(BaseModel):
    addr: str
    distanceM: int | None
    contentId: str


class ObservationSpot(BaseModel):
    id: str
    kind: Literal["bird", "star", "heritage"]
    name: str
    coord: Coordinate
    nightSky: NightSky | None
    birds: BirdObservation | None
    heritage: HeritageInfo | None


class ObservationMapResponse(BaseModel):
    region: str
    degraded: bool
    spots: list[ObservationSpot]
