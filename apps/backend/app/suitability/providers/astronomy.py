"""Live KASI astronomy adapter for the astronomy layer.

Parsing (`parse`) is separated from network I/O (`fetch`) so the fusion logic
can be unit tested against fixture payloads with zero network calls. `parse`
never raises -- any missing/malformed field degrades to status="unavailable".
"""

from __future__ import annotations

from datetime import date

import httpx

from app.suitability.config import get_astronomy_config
from app.suitability.providers.base import LayerReading

_GOLDEN_WINDOW_MINUTES = 3 * 60 + 40
_DAY_SUB_SCORE = 75


def _parse_hhmm(value: object) -> tuple[int, int]:
    text = str(value).strip()
    if len(text) != 4 or not text.isdigit():
        raise ValueError(f"expected 4-digit HHMM string, got {value!r}")
    hour, minute = int(text[:2]), int(text[2:])
    if not (0 <= hour <= 23 and 0 <= minute <= 59):
        raise ValueError(f"HHMM out of range: {value!r}")
    return hour, minute


def _format_hhmm(hour: int, minute: int) -> str:
    return f"{hour:02d}:{minute:02d}"


def _add_minutes(hour: int, minute: int, delta_minutes: int) -> tuple[int, int]:
    total = (hour * 60 + minute + delta_minutes) % (24 * 60)
    return total // 60, total % 60


def _format_age(age: float) -> str:
    if age == int(age):
        return f"월령 {int(age)}일"
    return f"월령 {age:.1f}일"


def _unwrap_item(payload: dict) -> dict:
    item = payload["response"]["body"]["items"]["item"]
    if isinstance(item, list):
        item = item[0]
    if not isinstance(item, dict):
        raise ValueError("unexpected KASI item shape")
    return item


class AstronomyProvider:
    key = "astronomy"

    def __init__(self, client: httpx.Client | None = None):
        self._client = client

    def parse(self, riseset_item: dict, lunar_item: dict, mode: str) -> LayerReading:
        try:
            lun_age = float(lunar_item["lunAge"])
        except (KeyError, TypeError, ValueError, AttributeError) as exc:
            return LayerReading(
                key=self.key,
                status="unavailable",
                sub_score=0,
                evidence={"reason": f"lunAge missing or unparseable: {exc}"},
            )

        illumination_pct = round(100 * (1 - abs(lun_age - 14.75) / 14.75))
        illumination_pct = max(0, min(100, illumination_pct))

        twilight_raw = riseset_item.get("aste") if isinstance(riseset_item, dict) else None

        if mode == "day":
            return LayerReading(
                key=self.key,
                status="live",
                sub_score=_DAY_SUB_SCORE,
                telemetry=[],
                golden_hours=[],
                evidence={
                    "lunarAgeDays": lun_age,
                    "illuminationPct": illumination_pct,
                    "aste": twilight_raw if isinstance(twilight_raw, str) else None,
                },
            )

        try:
            start_hour, start_minute = _parse_hhmm(twilight_raw)
        except (TypeError, ValueError) as exc:
            return LayerReading(
                key=self.key,
                status="unavailable",
                sub_score=0,
                evidence={"reason": f"aste missing/unparseable: {exc}"},
            )

        start_str = _format_hhmm(start_hour, start_minute)
        end_hour, end_minute = _add_minutes(start_hour, start_minute, _GOLDEN_WINDOW_MINUTES)
        end_str = _format_hhmm(end_hour, end_minute)

        sub_score = max(0, min(100, 100 - illumination_pct))

        return LayerReading(
            key=self.key,
            status="live",
            sub_score=sub_score,
            telemetry=[],
            golden_hours=[
                {
                    "mode": "night",
                    "label": "밤 · 천체 골든타임",
                    "timeRange": f"{start_str} - {end_str}",
                    "description": f"{_format_age(lun_age)} · 광도 {illumination_pct}%",
                }
            ],
            evidence={
                "lunarAgeDays": lun_age,
                "illuminationPct": illumination_pct,
                "aste": twilight_raw,
            },
        )

    def fetch(self, lat: float, lng: float, mode: str) -> LayerReading:
        config = get_astronomy_config()
        missing = [
            name
            for name, value in (
                ("service_key", config.service_key),
                ("riseset_base_url", config.riseset_base_url),
                ("lunph_base_url", config.lunph_base_url),
            )
            if not value
        ]
        if missing:
            return LayerReading(
                key=self.key,
                status="unavailable",
                sub_score=0,
                evidence={"reason": f"KASI astronomy config missing: {', '.join(missing)}"},
            )

        client = self._client
        owns_client = client is None
        if owns_client:
            client = httpx.Client(timeout=5.0)

        try:
            locdate = date.today().strftime("%Y%m%d")

            riseset_response = client.get(
                f"{config.riseset_base_url}/getLCRiseSetInfo",
                params={
                    "serviceKey": config.service_key,
                    "locdate": locdate,
                    "longitude": lng,
                    "latitude": lat,
                    "_type": "json",
                },
            )
            riseset_response.raise_for_status()
            riseset_item = _unwrap_item(riseset_response.json())

            lunar_response = client.get(
                f"{config.lunph_base_url}/getLunPhInfo",
                params={
                    "serviceKey": config.service_key,
                    "solYear": locdate[:4],
                    "solMonth": locdate[4:6],
                    "solDay": locdate[6:8],
                    "_type": "json",
                },
            )
            lunar_response.raise_for_status()
            lunar_item = _unwrap_item(lunar_response.json())

            return self.parse(riseset_item, lunar_item, mode)
        except Exception as exc:  # noqa: BLE001 -- fetch() must never raise
            return LayerReading(
                key=self.key,
                status="unavailable",
                sub_score=0,
                evidence={"reason": f"KASI astronomy request failed: {exc}"},
            )
        finally:
            if owns_client:
                client.close()
