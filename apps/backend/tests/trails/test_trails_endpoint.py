from __future__ import annotations

import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.trails.service import TrailsService, get_trails_service

client = TestClient(app)


def _healthy_course() -> dict:
    return {
        "crsIdx": "C001",
        "name": "강화 나들길 1코스",
        "sigun": "인천 강화군",
        "distanceKm": 17.7,
        "durationMin": 420,
        "level": 2,
        "cycle": "N",
        "gpxUrl": "https://example.com/course1.gpx",
        "start": {"lat": 37.73, "lng": 126.52},
        "end": {"lat": 37.75, "lng": 126.48},
        "nightSky": {
            "sqmValue": 21.4,
            "bortleClass": 3,
            "skyClass": "Class 3 다크스카이",
            "status": "approx",
        },
        "heritageEats": [
            {
                "name": "강화 순무김치",
                "addr": "인천 강화군 강화읍",
                "distanceM": 320,
                "lat": 37.749,
                "lng": 126.481,
                "contentId": "12345",
            }
        ],
        "daySuitability": {"score": 82, "label": "쾌적", "status": "live"},
        "nightSuitability": {"score": 75, "label": "쾌적", "status": "live"},
    }


class FakeTrailsService:
    def __init__(self, response: dict) -> None:
        self._response = response

    def get_trails(self, lat: float, lng: float, region_id: str | None = None) -> dict:
        return self._response


def _install(service: TrailsService) -> None:
    app.dependency_overrides[get_trails_service] = lambda: service


@pytest.fixture(autouse=True)
def fresh_trails_service():
    _install(
        FakeTrailsService(
            {
                "region": "인천 강화군",
                "degraded": False,
                "courses": [_healthy_course()],
            }
        )
    )
    yield
    app.dependency_overrides.clear()


def test_happy_path_returns_full_contract() -> None:
    response = client.get("/api/trails", params={"lat": 37.73, "lng": 126.52})
    assert response.status_code == 200
    body = response.json()

    assert "region" in body
    assert "degraded" in body
    assert "courses" in body
    assert body["degraded"] is False

    course = body["courses"][0]
    assert set(course) == {
        "crsIdx",
        "name",
        "sigun",
        "distanceKm",
        "durationMin",
        "level",
        "cycle",
        "gpxUrl",
        "start",
        "end",
        "nightSky",
        "heritageEats",
        "daySuitability",
        "nightSuitability",
    }
    assert set(course["start"]) == {"lat", "lng"}
    assert set(course["end"]) == {"lat", "lng"}
    assert set(course["nightSky"]) == {"sqmValue", "bortleClass", "skyClass", "status"}
    assert set(course["daySuitability"]) == {"score", "label", "status"}
    assert set(course["nightSuitability"]) == {"score", "label", "status"}
    for eat in course["heritageEats"]:
        assert set(eat) == {"name", "addr", "distanceM", "lat", "lng", "contentId"}


def test_degraded_response_returns_empty_courses() -> None:
    _install(
        FakeTrailsService(
            {
                "region": "인천 강화군",
                "degraded": True,
                "courses": [],
            }
        )
    )

    response = client.get("/api/trails", params={"lat": 37.73, "lng": 126.52})
    assert response.status_code == 200
    body = response.json()
    assert body["degraded"] is True
    assert body["courses"] == []


def test_missing_lat_returns_422() -> None:
    response = client.get("/api/trails", params={"lng": 126.52})
    assert response.status_code == 422


def test_lat_out_of_range_returns_422() -> None:
    response = client.get("/api/trails", params={"lat": 200, "lng": 126.52})
    assert response.status_code == 422
