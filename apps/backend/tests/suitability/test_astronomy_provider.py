from __future__ import annotations

import json
import re
from pathlib import Path

import pytest

from app.suitability.providers.astronomy import AstronomyProvider

_RISESET_FIXTURE = Path(__file__).parent / "fixtures" / "kasi_riseset_sample.json"
_LUNPH_FIXTURE = Path(__file__).parent / "fixtures" / "kasi_lunph_sample.json"

_TIME_RANGE_RE = re.compile(r"^\d{2}:\d{2} - \d{2}:\d{2}$")


def _unwrap(payload: dict) -> dict:
    return payload["response"]["body"]["items"]["item"]


@pytest.fixture
def riseset_item() -> dict:
    return _unwrap(json.loads(_RISESET_FIXTURE.read_text()))


@pytest.fixture
def lunar_item() -> dict:
    return _unwrap(json.loads(_LUNPH_FIXTURE.read_text()))


@pytest.mark.parametrize("mode", ["day", "night"])
def test_parse_returns_live_reading_with_expected_shape(riseset_item: dict, lunar_item: dict, mode: str) -> None:
    reading = AstronomyProvider().parse(riseset_item, lunar_item, mode)

    assert reading.status == "live"
    assert 0 <= reading.sub_score <= 100
    assert reading.telemetry == []


def test_night_mode_produces_one_golden_hour_with_well_formed_time_range(riseset_item: dict, lunar_item: dict) -> None:
    reading = AstronomyProvider().parse(riseset_item, lunar_item, "night")

    assert len(reading.golden_hours) == 1
    entry = reading.golden_hours[0]
    assert entry["mode"] == "night"
    assert _TIME_RANGE_RE.match(entry["timeRange"])


def test_day_mode_still_produces_one_night_golden_hour(riseset_item: dict, lunar_item: dict) -> None:
    reading = AstronomyProvider().parse(riseset_item, lunar_item, "day")

    assert len(reading.golden_hours) == 1
    entry = reading.golden_hours[0]
    assert entry["mode"] == "night"
    assert _TIME_RANGE_RE.match(entry["timeRange"])


@pytest.mark.parametrize("mode", ["day", "night"])
def test_missing_twilight_key_degrades_to_unavailable(lunar_item: dict, mode: str) -> None:
    riseset_item_without_twilight = {
        "sunrise": "0616",
        "sunset": "1854",
        "civile": "1924",
    }

    reading = AstronomyProvider().parse(riseset_item_without_twilight, lunar_item, mode)

    assert reading.status == "unavailable"
    assert reading.sub_score == 0
