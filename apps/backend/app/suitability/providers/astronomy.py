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
_MOON_BRIGHT_PCT = 50


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


def _format_minute_of_day(total_minutes: int) -> str:
    return _format_hhmm(*divmod(total_minutes % (24 * 60), 60))


def _moon_phase_name(lun_age: float) -> str:
    if 0 <= lun_age < 1.85:
        return "삭"
    elif 1.85 <= lun_age < 5.54:
        return "초승달"
    elif 5.54 <= lun_age < 9.23:
        return "상현 반달"
    elif 9.23 <= lun_age < 12.92:
        return "차오르는 달"
    elif 12.92 <= lun_age < 16.61:
        return "보름달"
    elif 16.61 <= lun_age < 20.30:
        return "기우는 달"
    elif 20.30 <= lun_age < 23.99:
        return "하현 반달"
    elif 23.99 <= lun_age < 27.68:
        return "그믐달"
    elif 27.68 <= lun_age <= 29.53:
        return "삭"


def _moonless_segments(
    window_start: int, window_end: int, moon_start: int, moon_end: int
) -> list[tuple[int, int]]:
    """Subtract [moon_start, moon_end) from [window_start, window_end); pure, no I/O."""
    if moon_end <= window_start or moon_start >= window_end:
        return [(window_start, window_end)]

    overlap_start = max(window_start, moon_start)
    overlap_end = min(window_end, moon_end)
    if overlap_start <= window_start and overlap_end >= window_end:
        return []

    segments: list[tuple[int, int]] = []
    if overlap_start > window_start:
        segments.append((window_start, overlap_start))
    if overlap_end < window_end:
        segments.append((overlap_end, window_end))
    return segments


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

        try:
            start_hour, start_minute = _parse_hhmm(twilight_raw)
        except (TypeError, ValueError) as exc:
            return LayerReading(
                key=self.key,
                status="unavailable",
                sub_score=0,
                evidence={"reason": f"aste missing/unparseable: {exc}"},
            )

        dark_start = start_hour * 60 + start_minute

        astm_raw = riseset_item.get("astm")
        moonrise_raw = riseset_item.get("moonrise")
        moonset_raw = riseset_item.get("moonset")

        try:
            astm_hour, astm_minute = _parse_hhmm(astm_raw)
            astm_parsed = True
        except (TypeError, ValueError):
            astm_parsed = False

        if astm_parsed:
            window_source = "darkSky"
            dark_end_raw = astm_hour * 60 + astm_minute
            dark_end = dark_end_raw if dark_end_raw > dark_start else dark_end_raw + 1440
        else:
            window_source = "fixedFallback"
            dark_end = dark_start + _GOLDEN_WINDOW_MINUTES

        sub_score = _DAY_SUB_SCORE if mode == "day" else max(0, min(100, 100 - illumination_pct))

        if window_source == "fixedFallback":
            golden_start, golden_end = dark_start, dark_end
            start_str = _format_minute_of_day(golden_start)
            end_str = _format_minute_of_day(golden_end)
            description = "하늘이 어두운 시간대"
        else:
            try:
                moonrise_hour, moonrise_minute = _parse_hhmm(moonrise_raw)
                moonset_hour, moonset_minute = _parse_hhmm(moonset_raw)
                moon_parsed = True
            except (TypeError, ValueError):
                moon_parsed = False

            observation_limited = False
            moon_unknown = not moon_parsed
            if moon_unknown or illumination_pct < _MOON_BRIGHT_PCT:
                golden_start, golden_end = dark_start, dark_end
            else:
                moonrise_norm = moonrise_hour * 60 + moonrise_minute
                moonset_raw_minutes = moonset_hour * 60 + moonset_minute
                moonset_norm = (
                    moonset_raw_minutes if moonset_raw_minutes > moonrise_norm else moonset_raw_minutes + 1440
                )

                segments = _moonless_segments(dark_start, dark_end, moonrise_norm, moonset_norm)
                if segments:
                    golden_start, golden_end = max(segments, key=lambda segment: segment[1] - segment[0])
                else:
                    golden_start, golden_end = dark_start, dark_end
                    observation_limited = True

            start_str = _format_minute_of_day(golden_start)
            end_str = _format_minute_of_day(golden_end)

            if observation_limited:
                description = "달이 밤새 떠 있어 어두운 별은 보기 어려워요"
            elif moon_unknown and illumination_pct >= _MOON_BRIGHT_PCT:
                description = "하늘이 완전히 어두운 시간"
            else:
                description = "달빛 방해 없는 시간대"

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
                    "description": description,
                }
            ],
            evidence={
                "lunarAgeDays": lun_age,
                "illuminationPct": illumination_pct,
                "aste": twilight_raw,
                "windowSource": window_source,
                "astm": astm_raw,
                "moonrise": moonrise_raw,
                "moonset": moonset_raw,
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
