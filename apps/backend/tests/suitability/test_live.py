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

from app.observation.service import ObservationMapService
from app.suitability.models import SuitabilityResponse
from app.suitability.providers.astronomy import AstronomyProvider
from app.suitability.providers.tide import TideProvider
from app.suitability.providers.weather import WeatherProvider
from app.suitability.service import SuitabilityService, get_default_providers
from app.species.wikipedia import fetch_species_summary
from app.trails.durunubi import fetch_courses, fetch_gpx_endpoints
from app.trails.durunubi_detail import fetch_course_detail
from app.trails.service import DEFAULT_REGION_TOKENS, TrailsService
from app.trails.tourapi import fetch_nearby_food

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


@pytest.mark.live
def test_durunubi_courses_live_fetch() -> None:
    courses = fetch_courses()

    assert isinstance(courses, list)
    if not courses:
        print("durunubi courses live fetch: empty (no key or degraded)")
    else:
        assert "gpxUrl" in courses[0]


@pytest.mark.live
def test_durunubi_gpx_endpoints_live_fetch() -> None:
    courses = fetch_courses()
    if not courses:
        pytest.skip("no durunubi courses available to fetch gpx endpoints for")

    gpx_url = next((course["gpxUrl"] for course in courses if course.get("gpxUrl")), None)
    if not gpx_url:
        pytest.skip("no durunubi course with a gpxUrl available")

    endpoints = fetch_gpx_endpoints(gpx_url)

    if endpoints is None:
        print("durunubi gpx endpoints live fetch: unavailable (degraded)")
    else:
        start, end = endpoints
        assert "lat" in start and "lng" in start
        assert "lat" in end and "lng" in end


@pytest.mark.live
def test_tourapi_nearby_food_live_fetch() -> None:
    foods = fetch_nearby_food(_GANGHWA_LAT, _GANGHWA_LNG)

    assert isinstance(foods, list)
    if not foods:
        print("tourapi nearby food live fetch: empty (no key or degraded)")
    else:
        assert "name" in foods[0]
        assert "addr" in foods[0]
        assert "distanceM" in foods[0]


@pytest.mark.live
def test_observation_map_service_live_fetch() -> None:
    service = ObservationMapService()
    result = service.get_observation_map(_GANGHWA_LAT, _GANGHWA_LNG)

    assert isinstance(result["degraded"], bool)
    assert isinstance(result["spots"], list)

    star_spots = [spot for spot in result["spots"] if spot["kind"] == "star"]
    bird_spots = [spot for spot in result["spots"] if spot["kind"] == "bird"]
    heritage_spots = [spot for spot in result["spots"] if spot["kind"] == "heritage"]

    assert len(star_spots) == 1
    print(f"observation map live fetch: {len(bird_spots)} bird spot(s), {len(heritage_spots)} heritage spot(s)")


@pytest.mark.live
def test_wikipedia_species_summary_live_fetch() -> None:
    result = fetch_species_summary("저어새", "Platalea minor")

    if result is None:
        print("wikipedia species summary live fetch: no result (degraded)")
    else:
        assert "summary" in result


@pytest.mark.live
def test_durunubi_course_detail_live_fetch() -> None:
    courses = fetch_courses()
    if not courses:
        pytest.skip("no durunubi courses available to fetch course detail for")

    crs_idx = courses[0]["crsIdx"]
    result = fetch_course_detail(crs_idx)

    assert result["found"] is True
    assert result["degraded"] is False
    print(
        f"durunubi course detail live fetch: description={result['description']!r}, "
        f"elevationProfile len={len(result['elevationProfile'])}"
    )
