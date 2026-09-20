from __future__ import annotations

from app.trails.service import TrailsService

SEOUL_LAT = 37.5665
SEOUL_LNG = 126.9780


class _RaisingSuitabilityService:
    def get_suitability(self, lat: float, lng: float, mode: str):
        raise Exception("no network calls allowed in offline tests")


def test_explicit_region_id_overrides_nearest_region():
    service = TrailsService(
        fetch_courses=lambda: [],
        fetch_gpx_endpoints=lambda gpx_url: None,
        fetch_nearby_food=lambda lat, lng: [],
        suitability_service=_RaisingSuitabilityService(),
    )

    result = service.get_trails(SEOUL_LAT, SEOUL_LNG, region_id="yeongyang")

    assert result["region"] == "경북 영양군"


def test_unknown_region_id_falls_back_to_nearest():
    service = TrailsService(
        fetch_courses=lambda: [],
        fetch_gpx_endpoints=lambda gpx_url: None,
        fetch_nearby_food=lambda lat, lng: [],
        suitability_service=_RaisingSuitabilityService(),
    )

    result = service.get_trails(37.6, 126.4, region_id="not-a-real-region")

    assert result["region"] == "인천 강화군"
