from __future__ import annotations

import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.routers.tide import get_today_tides_fetcher

client = TestClient(app)


def _found_response() -> dict:
    return {
        "found": True,
        "degraded": False,
        "stationName": "인천",
        "extremes": [
            {"time": "06:00", "kind": "high", "levelCm": 500},
            {"time": "12:00", "kind": "low", "levelCm": 90},
        ],
    }


class FakeFetcher:
    def __init__(self, response: dict) -> None:
        self._response = response

    def __call__(self, lat: float, lng: float) -> dict:
        return self._response


def _install(fetcher: FakeFetcher) -> None:
    app.dependency_overrides[get_today_tides_fetcher] = lambda: fetcher


@pytest.fixture(autouse=True)
def fresh_fetcher():
    _install(FakeFetcher(_found_response()))
    yield
    app.dependency_overrides.clear()


def test_tide_today_returns_fetcher_response() -> None:
    response = client.get("/api/tide/today", params={"lat": 37.45194, "lng": 126.59222})
    assert response.status_code == 200
    assert response.json() == _found_response()


def test_missing_lng_returns_422() -> None:
    response = client.get("/api/tide/today", params={"lat": 37.45194})
    assert response.status_code == 422


def test_missing_lat_returns_422() -> None:
    response = client.get("/api/tide/today", params={"lng": 126.59222})
    assert response.status_code == 422
