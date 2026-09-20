from __future__ import annotations

import math
from dataclasses import dataclass, field

_EARTH_RADIUS_KM = 6371.0


def _haversine_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    d_phi = math.radians(lat2 - lat1)
    d_lambda = math.radians(lng2 - lng1)
    a = math.sin(d_phi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(d_lambda / 2) ** 2
    return 2 * _EARTH_RADIUS_KM * math.asin(math.sqrt(a))


@dataclass(frozen=True)
class Region:
    id: str
    label: str
    center_lat: float
    center_lng: float
    trail_tokens: list[str] = field(default_factory=list)
    star_spot: dict | None = None


REGIONS: list[Region] = [
    Region(
        id="ganghwa",
        label="인천 강화군",
        center_lat=37.7469,
        center_lng=126.4878,
        trail_tokens=["강화"],
        star_spot={
            "id": "star:ganghwa-astro",
            "name": "강화 천문인마을",
            "lat": 37.7378,
            "lng": 126.4708,
        },
    ),
    Region(
        id="pyeongchang",
        label="강원 평창군",
        center_lat=37.3705,
        center_lng=128.3900,
        trail_tokens=["평창", "정선"],
        star_spot={
            "id": "star:pyeongchang-astro",
            "name": "청옥산 육백마지기",
            "lat": 37.3607,
            "lng": 128.6620,
        },
    ),
    Region(
        id="seosan",
        label="충남 서산시",
        center_lat=36.7849,
        center_lng=126.4503,
        trail_tokens=["서산"],
        star_spot=None,
    ),
    Region(
        id="suncheon",
        label="전남 순천시",
        center_lat=34.9506,
        center_lng=127.4872,
        trail_tokens=["순천"],
        star_spot=None,
    ),
    Region(
        id="yeongyang",
        label="경북 영양군",
        center_lat=36.6666,
        center_lng=129.1124,
        trail_tokens=["영양"],
        star_spot={
            "id": "star:yeongyang-astro",
            "name": "영양 반딧불이생태공원(국제밤하늘공원)",
            "lat": 36.6790,
            "lng": 129.0930,
        },
    ),
    Region(
        id="muju",
        label="전북 무주군",
        center_lat=36.0069,
        center_lng=127.6608,
        trail_tokens=["무주"],
        star_spot={
            "id": "star:muju-astro",
            "name": "무주 반디랜드",
            "lat": 36.0330,
            "lng": 127.7360,
        },
    ),
    Region(
        id="changnyeong",
        label="경남 창녕군",
        center_lat=35.5447,
        center_lng=128.4923,
        trail_tokens=["창녕"],
        star_spot=None,
    ),
]


def sort_by_distance(lat: float, lng: float) -> list[tuple[Region, float]]:
    pairs = [
        (region, _haversine_km(lat, lng, region.center_lat, region.center_lng))
        for region in REGIONS
    ]
    pairs.sort(key=lambda pair: pair[1])
    return pairs


def nearest(lat: float, lng: float) -> Region:
    return min(REGIONS, key=lambda region: _haversine_km(lat, lng, region.center_lat, region.center_lng))


def get(region_id: str) -> Region | None:
    for region in REGIONS:
        if region.id == region_id:
            return region
    return None
