"""Pure-Python brightness -> SQM -> Bortle class conversion.

No numpy, no I/O -- deterministic math only, safe to unit test directly.
"""

from __future__ import annotations

import math

_BORTLE_THRESHOLDS: list[tuple[float, int]] = [
    (21.99, 1),
    (21.89, 2),
    (21.69, 3),
    (21.25, 4),
    (20.49, 5),
    (19.50, 6),
    (18.94, 7),
    (18.38, 8),
]

_NATURAL_SKY_SQM = 22.0

_BORTLE_DESCRIPTIONS: list[tuple[int, str]] = [
    (2, "최적 다크스카이"),
    (4, "양호한 다크스카이"),
    (6, "보통 도심 근교"),
    (9, "광해 심각"),
]


def sqm_to_bortle(sqm: float) -> int:
    for threshold, bortle_class in _BORTLE_THRESHOLDS:
        if sqm >= threshold:
            return bortle_class
    return 9


def brightness_to_sqm(brightness_mcd_per_m2: float) -> float:
    if brightness_mcd_per_m2 <= 0:
        return _NATURAL_SKY_SQM
    return math.log10(brightness_mcd_per_m2 / 108000000) / -0.4


def bortle_description(bortle_class: int) -> str:
    for max_class, description in _BORTLE_DESCRIPTIONS:
        if bortle_class <= max_class:
            return description
    return _BORTLE_DESCRIPTIONS[-1][1]
