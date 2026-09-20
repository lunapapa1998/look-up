from __future__ import annotations

import json
from pathlib import Path
from threading import Event

import httpx
import pytest

from app.suitability.providers.weather import (
    ProgressiveWeatherProvider,
    WeatherProvider,
    _parse_grid_value,
    _parse_xy_response,
    _request_text,
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


def test_request_text_retries_transient_timeout(monkeypatch) -> None:
    attempts = 0

    def handler(request: httpx.Request) -> httpx.Response:
        nonlocal attempts
        attempts += 1
        if attempts == 1:
            raise httpx.ReadTimeout("temporary KMA delay", request=request)
        return httpx.Response(200, text="weather data", request=request)

    monkeypatch.setattr("app.suitability.providers.weather.time.sleep", lambda _: None)
    with httpx.Client(transport=httpx.MockTransport(handler)) as client:
        text = _request_text(client, "https://example.test/weather", {}, attempts=2)

    assert text == "weather data"
    assert attempts == 2


def test_request_text_raises_after_retry_budget(monkeypatch) -> None:
    attempts = 0

    def handler(request: httpx.Request) -> httpx.Response:
        nonlocal attempts
        attempts += 1
        raise httpx.ReadTimeout("persistent KMA delay", request=request)

    monkeypatch.setattr("app.suitability.providers.weather.time.sleep", lambda _: None)
    with httpx.Client(transport=httpx.MockTransport(handler)) as client:
        with pytest.raises(httpx.ReadTimeout):
            _request_text(client, "https://example.test/weather", {}, attempts=3)

    assert attempts == 3


def test_recent_cached_reading_is_used_as_approximate_fallback(
    monkeypatch, kma_values: dict
) -> None:
    provider = WeatherProvider()
    live = provider.parse(kma_values, "day")
    monkeypatch.setattr("app.suitability.providers.weather.time.monotonic", lambda: 100.0)
    provider._remember(37.5921, 126.3984, "day", live)
    monkeypatch.setattr("app.suitability.providers.weather.time.monotonic", lambda: 160.0)

    fallback = provider._cached_fallback(
        37.5921, 126.3984, "day", "temporary timeout"
    )

    assert fallback is not None
    assert fallback.status == "approx"
    assert fallback.sub_score == live.sub_score
    assert fallback.telemetry == live.telemetry
    assert fallback.evidence["cacheAgeSeconds"] == 60
    assert fallback.evidence["liveFailure"] == "temporary timeout"


def test_expired_cached_reading_is_not_used(monkeypatch, kma_values: dict) -> None:
    provider = WeatherProvider()
    live = provider.parse(kma_values, "day")
    monkeypatch.setattr("app.suitability.providers.weather.time.monotonic", lambda: 100.0)
    provider._remember(37.5921, 126.3984, "day", live)
    monkeypatch.setattr(
        "app.suitability.providers.weather.time.monotonic",
        lambda: 100.0 + 2 * 60 * 60 + 1,
    )

    fallback = provider._cached_fallback(37.5921, 126.3984, "day", "timeout")

    assert fallback is None


def test_fresh_cache_is_shared_between_day_and_night(
    monkeypatch, kma_values: dict
) -> None:
    provider = WeatherProvider()
    monkeypatch.setattr("app.suitability.providers.weather.time.monotonic", lambda: 100.0)
    provider._remember(37.5921, 126.3984, "day", provider.parse(kma_values, "day"))
    provider._remember(
        37.5921, 126.3984, "night", provider.parse(kma_values, "night")
    )
    monkeypatch.setattr("app.suitability.providers.weather.time.monotonic", lambda: 200.0)

    day = provider._fresh_cached(37.5921, 126.3984, "day")
    night = provider._fresh_cached(37.5921, 126.3984, "night")

    assert day is not None
    assert night is not None
    assert day.status == "live"
    assert night.status == "live"
    assert day.telemetry == night.telemetry
    assert day.sub_score != night.sub_score


def test_progressive_provider_returns_loading_then_shared_cache(kma_values: dict) -> None:
    refreshed = Event()

    class StubWeatherProvider(WeatherProvider):
        calls = 0

        def fetch(self, lat: float, lng: float, mode: str):
            self.calls += 1
            for cached_mode in ("day", "night"):
                self._remember(lat, lng, cached_mode, self.parse(kma_values, cached_mode))
            refreshed.set()
            return self._fresh_cached(lat, lng, mode)

    source = StubWeatherProvider()
    provider = ProgressiveWeatherProvider(source)

    first = provider.fetch(37.5921, 126.3984, "day")
    assert first.status == "loading"
    assert refreshed.wait(timeout=1)

    night = provider.fetch(37.5921, 126.3984, "night")
    day = provider.fetch(37.5921, 126.3984, "day")

    assert source.calls == 1
    assert night.status == "live"
    assert day.status == "live"
    assert night.telemetry == day.telemetry
