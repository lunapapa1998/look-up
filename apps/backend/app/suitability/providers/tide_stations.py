"""KHOA tide observation station registry.

Static list of tide stations (code, name, lat/lng) used to resolve the
nearest station for a given coordinate before calling the live KHOA API.
"""

from __future__ import annotations

import math
from dataclasses import dataclass


@dataclass(frozen=True)
class TideStation:
    code: str
    name: str
    lat: float
    lng: float


STATIONS: tuple[TideStation, ...] = (
    TideStation("DT_0001", "인천", 37.45194, 126.59222),
    TideStation("DT_0002", "평택", 36.96694, 126.82277),
    TideStation("DT_0003", "영광", 35.42611, 126.42055),
    TideStation("DT_0004", "제주", 33.52750, 126.54305),
    TideStation("DT_0005", "부산", 35.09638, 129.03527),
    TideStation("DT_0006", "묵호", 37.55027, 129.11638),
    TideStation("DT_0007", "목포", 34.77972, 126.37555),
    TideStation("DT_0008", "안산", 37.19222, 126.64722),
    TideStation("DT_0010", "서귀포", 33.24000, 126.56166),
    TideStation("DT_0011", "후포", 36.67750, 129.45305),
    TideStation("DT_0012", "속초", 38.20722, 128.59416),
    TideStation("DT_0013", "울릉도", 37.49138, 130.91361),
    TideStation("DT_0014", "통영", 34.82777, 128.43472),
    TideStation("DT_0016", "여수", 34.74722, 127.76555),
    TideStation("DT_0017", "대산", 37.00750, 126.35277),
    TideStation("DT_0018", "군산", 35.97555, 126.56305),
    TideStation("DT_0020", "울산", 35.50194, 129.38722),
    TideStation("DT_0021", "추자도", 33.96194, 126.30027),
    TideStation("DT_0022", "성산포", 33.47472, 126.92777),
    TideStation("DT_0023", "모슬포", 33.21444, 126.25111),
    TideStation("DT_0024", "장항", 36.00694, 126.68750),
    TideStation("DT_0025", "보령", 36.40638, 126.48611),
    TideStation("DT_0026", "고흥발포", 34.48111, 127.34277),
    TideStation("DT_0027", "완도", 34.31555, 126.75972),
    TideStation("DT_0028", "진도", 34.37777, 126.30861),
    TideStation("DT_0029", "거제도", 34.80138, 128.69916),
    TideStation("DT_0031", "거문도", 34.02833, 127.30888),
    TideStation("DT_0032", "강화대교", 37.73194, 126.52222),
    TideStation("DT_0035", "흑산도", 34.68416, 125.43555),
    TideStation("DT_0036", "대청도", 37.82522, 124.71805),
    TideStation("DT_0037", "어청도", 36.11722, 125.98472),
    TideStation("DT_0038", "굴업도", 37.19444, 125.99500),
    TideStation("DT_0039", "왕돌초", 36.71916, 129.73250),
    TideStation("DT_0041", "복사초", 34.09833, 126.16833),
    TideStation("DT_0042", "교본초", 34.70472, 128.30638),
    TideStation("DT_0043", "영흥도", 37.23861, 126.42861),
    TideStation("DT_0044", "영종대교", 37.54555, 126.58444),
)

_EARTH_RADIUS_KM = 6371.0


def _haversine_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    d_phi = math.radians(lat2 - lat1)
    d_lambda = math.radians(lng2 - lng1)
    a = math.sin(d_phi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(d_lambda / 2) ** 2
    return 2 * _EARTH_RADIUS_KM * math.asin(math.sqrt(a))


def nearest_station(lat: float, lng: float) -> TideStation:
    return min(STATIONS, key=lambda station: _haversine_km(lat, lng, station.lat, station.lng))
