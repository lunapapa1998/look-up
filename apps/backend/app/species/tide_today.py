"""Coordinate-based 'today's tide extremes' lookup.

Reuses the KHOA XML parsing / station lookup helpers from
`app.suitability.providers.tide` and `.tide_stations` -- this module owns no
tide-parsing logic of its own, only the today-filtering and response shaping.
"""

from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Literal

import httpx
from pydantic import BaseModel

from app.suitability.config import get_tide_config
from app.suitability.providers.tide import _classify_extremes, _parse_xml_items
from app.suitability.providers.tide_stations import _haversine_km, nearest_station

_KST = timezone(timedelta(hours=9))
_MAX_STATION_DISTANCE_KM = 20.0


class TideExtreme(BaseModel):
    time: str
    kind: Literal["high", "low"]
    levelCm: int | None


class TideTodayResponse(BaseModel):
    found: bool
    degraded: bool
    stationName: str | None
    extremes: list[TideExtreme]


def fetch_today_tides(lat: float, lng: float, client: httpx.Client | None = None) -> dict:
    station = nearest_station(lat, lng)
    distance = _haversine_km(lat, lng, station.lat, station.lng)
    if distance > _MAX_STATION_DISTANCE_KM:
        return {"found": False, "degraded": False, "stationName": None, "extremes": []}

    config = get_tide_config()
    if not config.service_key or not config.base_url:
        return {"found": False, "degraded": True, "stationName": None, "extremes": []}

    owns_client = client is None
    try:
        if owns_client:
            client = httpx.Client(timeout=5.0)

        response = client.get(
            config.base_url,
            params={"serviceKey": config.service_key, "obsCode": station.code},
        )
        response.raise_for_status()
        items = _parse_xml_items(response.text)

        entries = sorted(
            (
                (datetime.strptime(item["predcDt"], "%Y-%m-%d %H:%M"), float(item["predcTdlvVl"]))
                for item in items
            ),
            key=lambda entry: entry[0],
        )
        is_high_list = _classify_extremes(entries)

        today = datetime.now(_KST).date()
        extremes = [
            {
                "time": dt.strftime("%H:%M"),
                "kind": "high" if is_high else "low",
                "levelCm": round(level),
            }
            for (dt, level), is_high in zip(entries, is_high_list)
            if dt.date() == today
        ]

        return {
            "found": True,
            "degraded": False,
            "stationName": items[0].get("obsvtrNm") or station.name,
            "extremes": extremes,
        }
    except Exception:  # noqa: BLE001
        return {"found": False, "degraded": True, "stationName": None, "extremes": []}
    finally:
        if owns_client and client is not None:
            try:
                client.close()
            except Exception:  # noqa: BLE001
                pass
