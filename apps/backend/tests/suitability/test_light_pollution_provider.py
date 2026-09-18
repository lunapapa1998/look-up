from __future__ import annotations

from pathlib import Path

from app.suitability.lightpollution import convert
from app.suitability.providers.light_pollution import LightPollutionProvider

FIXTURE_PATH = str(Path(__file__).parent / "fixtures" / "lp_grid_sample.json")
MISSING_PATH = str(Path(__file__).parent / "fixtures" / "does_not_exist.json")

SEOUL_LAT, SEOUL_LNG = 37.57, 126.98
MOUNTAIN_LAT, MOUNTAIN_LNG = 37.95, 127.45


def test_fetch_seoul_uses_grid():
    provider = LightPollutionProvider(grid_path=FIXTURE_PATH)
    reading = provider.fetch(SEOUL_LAT, SEOUL_LNG, "night")

    assert reading.status == "approx"
    assert reading.evidence["method"] == "World Atlas 2015 grid"
    assert reading.evidence["sqmValue"] == 17.5
    assert reading.evidence["bortleClass"] == convert.sqm_to_bortle(17.5)


def test_fetch_mountain_darker_than_seoul():
    provider = LightPollutionProvider(grid_path=FIXTURE_PATH)

    seoul_reading = provider.fetch(SEOUL_LAT, SEOUL_LNG, "night")
    mountain_reading = provider.fetch(MOUNTAIN_LAT, MOUNTAIN_LNG, "night")

    assert mountain_reading.status == "approx"
    assert mountain_reading.evidence["sqmValue"] == 21.5
    assert seoul_reading.sub_score < mountain_reading.sub_score


def test_fetch_missing_grid_falls_back_to_synthetic():
    provider = LightPollutionProvider(grid_path=MISSING_PATH)
    reading = provider.fetch(SEOUL_LAT, SEOUL_LNG, "night")

    assert reading.status == "stub"
    assert reading.evidence["method"] == "grid not installed — synthetic fallback"
    assert 0 <= reading.sub_score <= 100


def test_fetch_out_of_bbox_falls_back_to_synthetic():
    provider = LightPollutionProvider(grid_path=FIXTURE_PATH)
    reading = provider.fetch(10.0, 10.0, "night")

    assert reading.status == "stub"
    assert reading.evidence["method"] == "grid not installed — synthetic fallback"
