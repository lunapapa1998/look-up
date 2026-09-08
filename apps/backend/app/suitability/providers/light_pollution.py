"""Deterministic, network-free approximation of light pollution.

This is a placeholder heuristic only -- real VIIRS (Visible Infrared Imaging
Radiometer Suite) raster integration is out of scope for this slice. It never
performs I/O and always returns the same output for the same (lat, lng), so it
can safely report status="approx" without a live/unavailable distinction.
"""

from __future__ import annotations

import math

from app.suitability.providers.base import LayerReading

_SQM_MIN = 16.0
_SQM_MAX = 22.0

_SKY_CLASS_LABELS: list[tuple[int, str]] = [
    (2, "최적 다크스카이"),
    (4, "양호한 다크스카이"),
    (6, "보통 도심 근교"),
    (9, "광해 심각"),
]


def _sky_class_description(bortle_class: int) -> str:
    for max_class, description in _SKY_CLASS_LABELS:
        if bortle_class <= max_class:
            return description
    return _SKY_CLASS_LABELS[-1][1]


class LightPollutionProvider:
    key = "lightPollution"

    def fetch(self, lat: float, lng: float, mode: str) -> LayerReading:
        # Fold lat/lng into a repeatable [0, 1) fraction using the sawtooth
        # pattern of sin() -- a simple stand-in for "distance from an urban
        # center" until real VIIRS raster lookups are wired in.
        seed = math.sin(lat * 12.9898 + lng * 78.233) * 43758.5453
        frac = seed - math.floor(seed)

        sqm_value = _SQM_MIN + frac * (_SQM_MAX - _SQM_MIN)
        bortle_class = max(1, min(9, 9 - round(frac * 8)))

        sub_score = round((sqm_value - _SQM_MIN) / (_SQM_MAX - _SQM_MIN) * 100)
        sub_score = max(0, min(100, sub_score))

        sky_class = f"Class {bortle_class} {_sky_class_description(bortle_class)}"

        return LayerReading(
            key=self.key,
            status="approx",
            sub_score=sub_score,
            telemetry=[],
            golden_hours=[],
            evidence={
                "sqmValue": round(sqm_value, 2),
                "skyClass": sky_class,
                "bortleClass": bortle_class,
                "method": "static lat/lng approximation, VIIRS raster not yet integrated",
            },
        )
