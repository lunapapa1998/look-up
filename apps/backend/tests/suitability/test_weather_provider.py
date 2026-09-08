from __future__ import annotations

import json
from pathlib import Path

import pytest

from app.suitability.providers.weather import (
    WeatherProvider,
    _parse_grid_value,
    _parse_xy_response,
)

_FIXTURE_PATH = Path(__file__).parent / "fixtures" / "kma_weather_sample.json"


@pytest.fixture
def kma_values() -> dict:
    return json.loads(_FIXTURE_PATH.read_text())


@pytest.mark.parametrize("mode", ["day", "night"])
def test_parse_returns_live_reading_with_expected_shape(kma_values: dict, mode: str) -> None:
    reading = WeatherProvider().parse(kma_values, mode)

    assert reading.status == "live"
    assert 0 <= reading.sub_score <= 100
    assert [entry["kind"] for entry in reading.telemetry] == ["sky", "humidity", "wind", "precip"]
    assert reading.evidence["skyCode"] == kma_values["SKY"]
    assert reading.evidence["ptyCode"] == kma_values["PTY"]
    assert reading.evidence["precipitationDetected"] is False


def test_day_and_night_sub_scores_differ_for_same_payload(kma_values: dict) -> None:
    day_reading = WeatherProvider().parse(kma_values, "day")
    night_reading = WeatherProvider().parse(kma_values, "night")

    assert day_reading.sub_score != night_reading.sub_score


def test_precipitation_penalizes_sub_score(kma_values: dict) -> None:
    clear_reading = WeatherProvider().parse(kma_values, "day")

    rainy_values = dict(kma_values, PTY=1)
    rainy_reading = WeatherProvider().parse(rainy_values, "day")

    assert rainy_reading.sub_score < clear_reading.sub_score
    assert rainy_reading.evidence["precipitationDetected"] is True


# 3x3 grid (nx_max=3): the real KMA grid flattens row-major and wraps across
# physical lines, so parsing is flat-token indexed, not line-per-row. With
# nx_max=3 a 3-wide grid indexes identically whether wrapped or not.
_GRID_SAMPLE = "# header comment\n10, 20, 30\n40, 50, 60,\n70, 80, 90,\n"


def test_parse_grid_value_indexes_correct_row_and_column() -> None:
    assert _parse_grid_value(_GRID_SAMPLE, nx=1, ny=1, nx_max=3) == 10.0
    assert _parse_grid_value(_GRID_SAMPLE, nx=3, ny=2, nx_max=3) == 60.0
    assert _parse_grid_value(_GRID_SAMPLE, nx=2, ny=3, nx_max=3) == 80.0


def test_parse_grid_value_raises_on_no_data_sentinel() -> None:
    sample = "# header\n-99.0, 20, 30\n"
    with pytest.raises(ValueError):
        _parse_grid_value(sample, nx=1, ny=1, nx_max=3)


def test_parse_xy_response_extracts_last_two_tokens_of_last_valid_line() -> None:
    text = "# NX NY LON LAT\n#comment line\n126.70 37.45 55 127\n"
    assert _parse_xy_response(text) == (55, 127)


def test_fetch_without_api_key_returns_unavailable_without_network(monkeypatch) -> None:
    import app.suitability.providers.weather as weather_module
    from app.suitability.config import WeatherConfig

    monkeypatch.setattr(
        weather_module,
        "get_weather_config",
        lambda: WeatherConfig(provider="kma", kma_base_url="https://example.invalid", kma_api_key=""),
    )

    reading = WeatherProvider().fetch(37.45, 126.7, "day")

    assert reading.status == "unavailable"
    assert reading.sub_score == 0
    assert reading.evidence["reason"] == "KMA_APIHUB_KEY not configured"
