from __future__ import annotations

import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.routers.trails_detail import get_course_detail_fetcher

client = TestClient(app)


def _found_response() -> dict:
    return {
        "crsIdx": "C001",
        "found": True,
        "description": "코스 설명입니다.",
        "themeId": "T_ROUTE_MNG0000000001",
        "startName": "영도대교 입구",
        "endName": "감천사거리",
        "travelerInfo": "- 시점 : 영도대교 입구<br>교통편) 지하철 남포역",
        "tourInfo": "- 용두산공원, 국제시장",
        "elevationProfile": [
            {"positionRatio": 0.0, "elevationM": 8.1},
            {"positionRatio": 1.0, "elevationM": 16.7},
        ],
        "degraded": False,
    }


def _not_found_response() -> dict:
    return {
        "crsIdx": "C999",
        "found": False,
        "description": None,
        "themeId": None,
        "startName": None,
        "endName": None,
        "travelerInfo": None,
        "tourInfo": None,
        "elevationProfile": [],
        "degraded": False,
    }


class FakeFetcher:
    def __init__(self, response: dict) -> None:
        self._response = response

    def __call__(self, crs_idx: str) -> dict:
        return self._response


def _install(fetcher: FakeFetcher) -> None:
    app.dependency_overrides[get_course_detail_fetcher] = lambda: fetcher


@pytest.fixture(autouse=True)
def fresh_fetcher():
    _install(FakeFetcher(_found_response()))
    yield
    app.dependency_overrides.clear()


def test_found_course_returns_full_contract() -> None:
    response = client.get("/api/trails/detail", params={"crsIdx": "C001"})
    assert response.status_code == 200
    body = response.json()

    assert set(body) == {
        "crsIdx",
        "found",
        "description",
        "themeId",
        "startName",
        "endName",
        "travelerInfo",
        "tourInfo",
        "elevationProfile",
        "degraded",
    }
    assert body["found"] is True


def test_not_found_course_returns_200() -> None:
    _install(FakeFetcher(_not_found_response()))

    response = client.get("/api/trails/detail", params={"crsIdx": "C999"})
    assert response.status_code == 200
    body = response.json()
    assert body["found"] is False


def test_missing_crs_idx_returns_422() -> None:
    response = client.get("/api/trails/detail")
    assert response.status_code == 422
