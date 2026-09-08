"""Live smoke tests against the real KMA(기상청 API 허브) and KASI APIs.

Skipped by default (module-level skipif). To run for real:

    cd apps/backend
    RUN_LIVE_TESTS=1 uv run pytest -m live -q

Requires KMA_APIHUB_KEY / KMA_APIHUB_BASE_URL / KASI_* /
DATA_GO_KR_SERVICE_KEY(또는 DATA_GO_KR_SERVICE_KEY_DECODED) to be set
in the repo-root .env (see apps/backend/.env.example) for the "live" status
path to be exercised -- without keys, providers degrade to "unavailable"
and these tests still pass.
"""

from __future__ import annotations

import os

import pytest

from app.suitability.models import SuitabilityResponse
from app.suitability.providers.astronomy import AstronomyProvider
from app.suitability.providers.tide import TideProvider
from app.suitability.providers.weather import WeatherProvider
from app.suitability.service import SuitabilityService, get_default_providers

pytestmark = pytest.mark.skipif(
    os.getenv("RUN_LIVE_TESTS") != "1",
    reason=(
        "live test -- set the RUN_LIVE_TESTS environment variable to the "
        "value 1 and pass the -m live selector to run against real OWM/KASI APIs"
    ),
)

_SEOUL_LAT = 37.5665
_SEOUL_LNG = 126.9780

_GANGHWA_LAT = 37.73194
_GANGHWA_LNG = 126.52222


@pytest.mark.live
def test_weather_provider_live_fetch() -> None:
    provider = WeatherProvider()
    reading = provider.fetch(_SEOUL_LAT, _SEOUL_LNG, "day")

    assert reading.status in ("live", "unavailable")
    if reading.status == "unavailable":
        assert reading.evidence.get("reason")
        print(f"weather provider unavailable: {reading.evidence.get('reason')}")
    else:
        assert 0 <= reading.sub_score <= 100
        assert len(reading.telemetry) == 4


@pytest.mark.live
def test_astronomy_provider_live_fetch() -> None:
    provider = AstronomyProvider()
    reading = provider.fetch(_SEOUL_LAT, _SEOUL_LNG, "night")

    assert reading.status in ("live", "unavailable")
    if reading.status == "unavailable":
        assert reading.evidence.get("reason")
        print(f"astronomy provider unavailable: {reading.evidence.get('reason')}")
    else:
        assert 0 <= reading.sub_score <= 100


@pytest.mark.live
def test_tide_provider_live_fetch() -> None:
    provider = TideProvider()
    reading = provider.fetch(_GANGHWA_LAT, _GANGHWA_LNG, "day")

    assert reading.status in ("live", "stub")
    if reading.status == "stub":
        assert reading.evidence.get("reason")
        print(f"tide provider stub: {reading.evidence.get('reason')}")
    else:
        assert 0 <= reading.sub_score <= 100


@pytest.mark.live
def test_suitability_service_live_end_to_end() -> None:
    service = SuitabilityService(get_default_providers())
    result = service.get_suitability(_SEOUL_LAT, _SEOUL_LNG, "day")

    assert isinstance(result, SuitabilityResponse)
    assert 0 <= result.score <= 100
    assert len(result.layers) == 4

    layers_by_key = {layer.key: layer for layer in result.layers}
    assert layers_by_key["lightPollution"].status == "approx"
    assert layers_by_key["tide"].status in ("live", "stub")
