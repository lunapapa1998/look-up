"""Live KHOA tide adapter for the tide layer.

Parsing (`parse`) is separated from network I/O (`fetch`) so the fusion logic
can be unit tested against fixture payloads with zero network calls. `fetch`
never raises -- config/network/parse failures all degrade to a deterministic
stub reading with status="stub" so callers never mistake it for real data.
"""

from __future__ import annotations

import xml.etree.ElementTree as ET
from datetime import datetime, timedelta, timezone
from typing import NamedTuple

import httpx

from app.suitability.config import get_tide_config
from app.suitability.providers.base import LayerReading

_SUB_SCORE = 70
_DAY_START_HOUR = 6
_DAY_END_HOUR = 18
_DAY_GOLDEN_SUB_SCORE = 85
_NIGHT_SUB_SCORE = 70
_KST = timezone(timedelta(hours=9))


def _parse_xml_items(xml_text: str) -> list[dict]:
    root = ET.fromstring(xml_text)
    result_code = root.findtext("header/resultCode")
    result_msg = root.findtext("header/resultMsg")
    if result_code != "00":
        raise ValueError(f"KHOA resultCode={result_code}: {result_msg}")

    items_el = root.find("body/items")
    items = [
        {child.tag: child.text for child in item_el}
        for item_el in (items_el.findall("item") if items_el is not None else [])
    ]
    if not items:
        raise ValueError("KHOA tide response has no items")
    return items


class _Extreme(NamedTuple):
    dt: datetime
    level: float
    is_high: bool


def _classify_extremes(entries: list[tuple[datetime, float]]) -> list[bool]:
    n = len(entries)
    is_high = [False] * n
    ambiguous = False

    for i in range(n):
        neighbors = []
        if i > 0:
            neighbors.append(entries[i - 1][1])
        if i < n - 1:
            neighbors.append(entries[i + 1][1])

        level = entries[i][1]
        if not neighbors:
            ambiguous = True
            continue

        ge_all = all(level >= nb for nb in neighbors)
        le_all = all(level <= nb for nb in neighbors)
        if ge_all and le_all:
            ambiguous = True
        elif ge_all:
            is_high[i] = True
        elif le_all:
            is_high[i] = False
        else:
            ambiguous = True

    if ambiguous:
        max_level = max(level for _, level in entries)
        return [level == max_level for _, level in entries]

    return is_high


class TideProvider:
    key = "tide"

    def __init__(self, client: httpx.Client | None = None):
        self._client = client

    def parse(self, items: list[dict], mode: str, now: datetime) -> LayerReading:
        entries = sorted(
            (
                (datetime.strptime(item["predcDt"], "%Y-%m-%d %H:%M"), float(item["predcTdlvVl"]))
                for item in items
            ),
            key=lambda entry: entry[0],
        )
        is_high = _classify_extremes(entries)
        extremes = [
            _Extreme(dt=dt, level=level, is_high=high)
            for (dt, level), high in zip(entries, is_high)
        ]

        daytime_highs = [
            extreme
            for extreme in extremes
            if extreme.is_high and _DAY_START_HOUR <= extreme.dt.hour < _DAY_END_HOUR
        ]
        if not daytime_highs:
            raise ValueError("no daytime high tide in KHOA response")

        golden_high = max(daytime_highs, key=lambda extreme: extreme.level)
        sub_score = _DAY_GOLDEN_SUB_SCORE if mode == "day" else _NIGHT_SUB_SCORE
        start = (golden_high.dt - timedelta(hours=2)).strftime("%H:%M")
        end = golden_high.dt.strftime("%H:%M")
        golden_hours = [
            {
                "mode": "day",
                "label": "낮 · 탐조 골든타임",
                "timeRange": f"{start} - {end}",
                "description": f"만조 {end} · 2시간 전 갯벌 유입 피크",
            }
        ]

        next_extreme = next((extreme for extreme in extremes if extreme.dt >= now), extremes[-1])
        label = "만조" if next_extreme.is_high else "간조"
        telemetry = [
            {
                "kind": "tide",
                "label": "조위 상태",
                "value": f"{label} {next_extreme.dt.strftime('%H:%M')}",
            }
        ]

        return LayerReading(
            key=self.key,
            status="live",
            sub_score=sub_score,
            telemetry=telemetry,
            golden_hours=golden_hours,
            evidence={
                "stationName": items[0].get("obsvtrNm"),
                "extremesCount": len(items),
            },
        )

    def _stub_reading(self, mode: str, reason: str) -> LayerReading:
        golden_hours = [
            {
                "mode": "day",
                "label": "낮 · 탐조 골든타임",
                "timeRange": "14:00 - 17:30",
                "description": "만조 2시간 전 갯벌 유입 피크 (스텁 데이터)",
            }
        ]

        return LayerReading(
            key=self.key,
            status="stub",
            sub_score=_SUB_SCORE,
            telemetry=[
                {
                    "kind": "tide",
                    "label": "조위 상태",
                    "value": "만조 16:15 (스텁 데이터)",
                }
            ],
            golden_hours=golden_hours,
            evidence={"reason": reason},
        )

    def fetch(self, lat: float, lng: float, mode: str) -> LayerReading:
        client: httpx.Client | None = None
        owns_client = False
        try:
            config = get_tide_config()
            if not config.service_key or not config.base_url:
                return self._stub_reading(
                    mode, "TIDE config missing: service_key/base_url not configured"
                )

            client = self._client
            owns_client = client is None
            if owns_client:
                client = httpx.Client(timeout=5.0)

            from app.suitability.providers.tide_stations import nearest_station

            station = nearest_station(lat, lng)

            response = client.get(
                config.base_url,
                params={"serviceKey": config.service_key, "obsCode": station.code},
            )
            response.raise_for_status()
            items = _parse_xml_items(response.text)

            now = datetime.now(_KST).replace(tzinfo=None)
            return self.parse(items, mode, now)
        except Exception as exc:  # noqa: BLE001
            return self._stub_reading(mode, f"KHOA tide request failed: {exc}")
        finally:
            if owns_client and client is not None:
                try:
                    client.close()
                except Exception:  # noqa: BLE001
                    pass
