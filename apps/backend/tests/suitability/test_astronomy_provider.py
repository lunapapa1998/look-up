from __future__ import annotations

import json
import re
from pathlib import Path

import pytest

from app.suitability.providers.astronomy import AstronomyProvider

_FIXTURES_DIR = Path(__file__).parent / "fixtures"
_RISESET_FIXTURE = _FIXTURES_DIR / "kasi_riseset_sample.json"
_LUNPH_FIXTURE = _FIXTURES_DIR / "kasi_lunph_sample.json"

_TIME_RANGE_RE = re.compile(r"^\d{2}:\d{2} - \d{2}:\d{2}$")


def _unwrap(payload: dict) -> dict:
    return payload["response"]["body"]["items"]["item"]


def _load_item(filename: str) -> dict:
    return _unwrap(json.loads((_FIXTURES_DIR / filename).read_text()))


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


def test_dark_sky_window_with_dim_moon_uses_full_twilight_span(riseset_item: dict, lunar_item: dict) -> None:
    # sample fixture: aste=2021, astm=0438, lunAge=26.8 -> illumination 18% (< _MOON_BRIGHT_PCT)
    reading = AstronomyProvider().parse(riseset_item, lunar_item, "night")

    assert reading.evidence["windowSource"] == "darkSky"
    assert reading.evidence["illuminationPct"] < 50
    entry = reading.golden_hours[0]
    assert entry["timeRange"] == "20:21 - 04:38"
    assert "달빛 방해 적은 시간대" in entry["description"]
    assert "달 밝기 18%" in entry["description"]


def test_missing_astm_falls_back_to_fixed_window(lunar_item: dict) -> None:
    riseset_item_no_astm = _load_item("kasi_riseset_no_astm.json")

    reading = AstronomyProvider().parse(riseset_item_no_astm, lunar_item, "night")

    assert reading.evidence["windowSource"] == "fixedFallback"
    entry = reading.golden_hours[0]
    # aste=20:21 + fixed 220 minutes (3h40m) = 00:01 next day
    assert entry["timeRange"] == "20:21 - 00:01"
    assert entry["description"] == "달 밝기 18%"


def test_bright_full_moon_covering_entire_window_limits_observation() -> None:
    riseset_item_full_moon = _load_item("kasi_riseset_fullmoon_allnight.json")
    lunar_item_full_moon = _load_item("kasi_lunph_full_moon.json")

    reading = AstronomyProvider().parse(riseset_item_full_moon, lunar_item_full_moon, "night")

    assert reading.evidence["windowSource"] == "darkSky"
    assert reading.evidence["illuminationPct"] >= 50
    entry = reading.golden_hours[0]
    assert entry["timeRange"] == "20:21 - 04:38"
    assert "달이 밤새 떠 있어" in entry["description"]
    assert len(reading.golden_hours) == 1
    assert _TIME_RANGE_RE.match(entry["timeRange"])


def test_bright_moon_mid_window_picks_longer_moonless_segment() -> None:
    riseset_item_partial = _load_item("kasi_riseset_moon_partial_overlap.json")
    lunar_item_bright = _load_item("kasi_lunph_bright.json")

    reading = AstronomyProvider().parse(riseset_item_partial, lunar_item_bright, "night")

    assert reading.evidence["windowSource"] == "darkSky"
    assert reading.evidence["illuminationPct"] >= 50
    entry = reading.golden_hours[0]
    # dark window 20:21-04:38 (1221-1718min); moon up 23:00-01:00 (1380-1500min)
    # segments: 20:21-23:00 (159min) and 01:00-04:38 (218min) -> longer segment wins
    assert entry["timeRange"] == "01:00 - 04:38"
    assert "달빛 방해 적은 시간대" in entry["description"]
    assert len(reading.golden_hours) == 1
    assert _TIME_RANGE_RE.match(entry["timeRange"])


def test_dark_sky_window_length_varies_with_twilight_gap(lunar_item: dict) -> None:
    summer_riseset = {"aste": "2130", "astm": "0330"}  # short night, 6h gap
    winter_riseset = {"aste": "1800", "astm": "0600"}  # long night, 12h gap

    summer_reading = AstronomyProvider().parse(summer_riseset, lunar_item, "night")
    winter_reading = AstronomyProvider().parse(winter_riseset, lunar_item, "night")

    assert summer_reading.evidence["windowSource"] == "darkSky"
    assert winter_reading.evidence["windowSource"] == "darkSky"
    assert summer_reading.golden_hours[0]["timeRange"] == "21:30 - 03:30"
    assert winter_reading.golden_hours[0]["timeRange"] == "18:00 - 06:00"


def test_bright_moon_risen_before_twilight_picks_post_moonset_segment() -> None:
    riseset_item_before_twilight = _load_item("kasi_riseset_moon_risen_before_twilight.json")
    lunar_item_bright = _load_item("kasi_lunph_bright.json")

    reading = AstronomyProvider().parse(riseset_item_before_twilight, lunar_item_bright, "night")

    assert reading.evidence["windowSource"] == "darkSky"
    entry = reading.golden_hours[0]
    assert entry["timeRange"] == "23:00 - 04:38"
    assert "달빛 방해 적은 시간대" in entry["description"]


def test_bright_moon_allnight_with_offset_endpoints_limits_observation() -> None:
    riseset_item_offset = _load_item("kasi_riseset_moon_allnight_offset.json")
    lunar_item_bright = _load_item("kasi_lunph_bright.json")

    reading = AstronomyProvider().parse(riseset_item_offset, lunar_item_bright, "night")

    assert reading.evidence["windowSource"] == "darkSky"
    entry = reading.golden_hours[0]
    assert entry["timeRange"] == "20:21 - 04:38"
    assert "달이 밤새 떠 있어" in entry["description"]


def test_missing_moon_fields_with_bright_illumination_does_not_claim_moonless() -> None:
    riseset_item_no_moon = {"aste": "2021", "astm": "0438"}
    lunar_item_bright = _load_item("kasi_lunph_bright.json")

    reading = AstronomyProvider().parse(riseset_item_no_moon, lunar_item_bright, "night")

    assert reading.evidence["windowSource"] == "darkSky"
    entry = reading.golden_hours[0]
    assert entry["timeRange"] == "20:21 - 04:38"
    assert "무월광" not in entry["description"]
    assert "달 정보 확인 중" in entry["description"]
