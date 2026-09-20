"""Grid-backed light pollution lookup, with a deterministic synthetic fallback.

The synthetic math below is a network-free approximation kept as a fallback
for coordinates outside the bundled VIIRS-derived grid, or when the grid file
has not been installed on this deployment.
"""

from __future__ import annotations

import math

from app.suitability.config import get_light_pollution_config
from app.suitability.lightpollution import convert, grid
from app.suitability.providers.base import LayerReading

_SQM_MIN = 16.0
_SQM_MAX = 22.0


class LightPollutionProvider:
    key = "lightPollution"

    def __init__(self, grid_path: str | None = None) -> None:
        resolved_path = grid_path if grid_path is not None else get_light_pollution_config().grid_path
        self._grid = grid.load_grid(resolved_path)

    def fetch(self, lat: float, lng: float, mode: str) -> LayerReading:
        sqm_value: float | None = None
        if self._grid is not None:
            sqm_value = grid.lookup(self._grid, lat, lng)

        if sqm_value is not None:
            bortle_class = convert.sqm_to_bortle(sqm_value)
            status = "approx"
            method = "World Atlas 2015 grid"
        else:
            # Fold lat/lng into a repeatable [0, 1) fraction using the sawtooth
            # pattern of sin() -- a simple stand-in for "distance from an urban
            # center" until real VIIRS raster lookups are wired in.
            seed = math.sin(lat * 12.9898 + lng * 78.233) * 43758.5453
            frac = seed - math.floor(seed)

            sqm_value = _SQM_MIN + frac * (_SQM_MAX - _SQM_MIN)
            bortle_class = max(1, min(9, 9 - round(frac * 8)))
            status = "stub"
            method = "grid not installed — synthetic fallback"

        sub_score = round((sqm_value - _SQM_MIN) / (_SQM_MAX - _SQM_MIN) * 100)
        sub_score = max(0, min(100, sub_score))

        sky_class = f"Class {bortle_class} {convert.bortle_description(bortle_class)}"

        return LayerReading(
            key=self.key,
            status=status,
            sub_score=sub_score,
            telemetry=[],
            golden_hours=[],
            evidence={
                "sqmValue": round(sqm_value, 2),
                "skyClass": sky_class,
                "bortleClass": bortle_class,
                "method": method,
            },
        )
