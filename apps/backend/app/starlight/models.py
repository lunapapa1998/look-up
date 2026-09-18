from __future__ import annotations

from pydantic import BaseModel, Field


class Location(BaseModel):
    lat: float
    lng: float


class TimingInfo(BaseModel):
    date: str
    sunset: str
    civil_twilight_end: str
    nautical_twilight_end: str
    astronomical_twilight_end: str
    forecast_reference_time: str


class CelestialTargetDetail(BaseModel):
    id: str
    name: str
    constellation: str
    target_type: str  # "milky_way", "constellation", "cluster", "star"
    altitude_deg: float
    azimuth_deg: float
    direction: str  # e.g. "남동쪽", "북동쪽", "남쪽"
    observation_mode: str  # e.g. "육안 관측", "안시 관측", "망원경 관측"
    description: str


class ObservingConditions(BaseModel):
    lunar_age_days: float
    moon_illumination_pct: int
    moon_phase_name: str
    sqm_value: float
    sky_class: str
    milky_way_visible: bool


class StarlightForecastResponse(BaseModel):
    title: str = Field(default="야간 전환 별빛 예보")
    summary: str
    location: Location
    timing: TimingInfo
    target: CelestialTargetDetail
    conditions: ObservingConditions
    all_visible_targets: list[CelestialTargetDetail] = []
    degraded: bool = False
