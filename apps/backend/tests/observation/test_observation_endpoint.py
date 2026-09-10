from __future__ import annotations

import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.observation.service import ObservationMapService, get_observation_map_service

client = TestClient(app)


def _bird_spot() -> dict:
    return {
        "id": "bird:L123456",
        "kind": "bird",
        "name": "강화 남단 습지",
        "coord": {"lat": 37.70, "lng": 126.45},
        "birds": {
            "speciesCount": 12,
            "topSpecies": [
                {
                    "nameKo": "저어새",
                    "nameSci": "Platalea minor",
                    "speciesCode": "eaospo1",
                    "count": 5,
                    "obsDt": "2026-09-01 07:30",
                }
            ],
            "mostRecentObsDt": "2026-09-01 07:30",
            "status": "community",
        },
        "nightSky": None,
        "heritage": None,
    }


def _star_spot() -> dict:
    return {
        "id": "star:ganghwa-astro",
        "kind": "star",
        "name": "강화 천문인마을",
        "coord": {"lat": 37.7378, "lng": 126.4708},
        "nightSky": {
            "sqmValue": 21.4,
            "bortleClass": 3,
            "skyClass": "Class 3 다크스카이",
            "status": "approx",
        },
        "birds": None,
        "heritage": None,
    }


def _heritage_spot() -> dict:
    return {
        "id": "heritage:12345",
        "kind": "heritage",
        "name": "강화 순무김치",
        "coord": {"lat": 37.749, "lng": 126.481},
        "heritage": {
            "addr": "인천 강화군 강화읍",
            "distanceM": 320,
            "contentId": "12345",
        },
        "birds": None,
        "nightSky": None,
    }


class FakeObservationMapService:
    def __init__(self, response: dict) -> None:
        self._response = response

    def get_observation_map(self, lat: float, lng: float) -> dict:
        return self._response


def _install(service: ObservationMapService) -> None:
    app.dependency_overrides[get_observation_map_service] = lambda: service


@pytest.fixture(autouse=True)
def fresh_observation_map_service():
    _install(
        FakeObservationMapService(
            {
                "region": "인천 강화군",
                "degraded": False,
                "spots": [_bird_spot(), _star_spot(), _heritage_spot()],
            }
        )
    )
    yield
    app.dependency_overrides.clear()


def test_happy_path_returns_full_contract() -> None:
    response = client.get("/api/observation-map", params={"lat": 37.73, "lng": 126.52})
    assert response.status_code == 200
    body = response.json()

    assert set(body) == {"region", "degraded", "spots"}
    assert body["degraded"] is False

    spots_by_kind = {spot["kind"]: spot for spot in body["spots"]}
    assert set(spots_by_kind) == {"bird", "star", "heritage"}

    for spot in body["spots"]:
        assert set(spot) == {"id", "kind", "name", "coord", "nightSky", "birds", "heritage"}

    bird_spot = spots_by_kind["bird"]
    assert set(bird_spot["birds"]) == {"speciesCount", "topSpecies", "mostRecentObsDt", "status"}
    for species in bird_spot["birds"]["topSpecies"]:
        assert set(species) == {"nameKo", "nameSci", "speciesCode", "count", "obsDt"}

    star_spot = spots_by_kind["star"]
    assert set(star_spot["nightSky"]) == {"sqmValue", "bortleClass", "skyClass", "status"}

    heritage_spot = spots_by_kind["heritage"]
    assert set(heritage_spot["heritage"]) == {"addr", "distanceM", "contentId"}


def test_degraded_response_returns_empty_spots() -> None:
    _install(
        FakeObservationMapService(
            {
                "region": "인천 강화군",
                "degraded": True,
                "spots": [],
            }
        )
    )

    response = client.get("/api/observation-map", params={"lat": 37.73, "lng": 126.52})
    assert response.status_code == 200
    body = response.json()
    assert body["degraded"] is True
    assert body["spots"] == []


def test_missing_lat_returns_422() -> None:
    response = client.get("/api/observation-map", params={"lng": 126.52})
    assert response.status_code == 422


def test_lat_out_of_range_returns_422() -> None:
    response = client.get("/api/observation-map", params={"lat": 200, "lng": 126.52})
    assert response.status_code == 422


def test_lng_out_of_range_returns_422() -> None:
    response = client.get("/api/observation-map", params={"lat": 37.73, "lng": -200})
    assert response.status_code == 422
