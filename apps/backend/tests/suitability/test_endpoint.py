from __future__ import annotations

import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.suitability.lightpollution import convert
from app.suitability.providers.base import LayerReading
from app.suitability.service import SuitabilityService, get_suitability_service

client = TestClient(app)


class FakeProvider:
    def __init__(self, key: str, reading: LayerReading | None = None, raises: bool = False):
        self.key = key
        self._reading = reading
        self._raises = raises

    def fetch(self, lat: float, lng: float, mode: str) -> LayerReading:
        if self._raises:
            raise RuntimeError(f"{self.key} provider exploded")
        return self._reading


def _healthy_providers() -> dict[str, FakeProvider]:
    return {
        "environment": FakeProvider(
            "environment",
            LayerReading(
                key="environment",
                status="live",
                sub_score=90,
                telemetry=[
                    {"kind": "sky", "label": "하늘상태", "value": "맑음"},
                    {"kind": "humidity", "label": "습도", "value": "55%"},
                    {"kind": "wind", "label": "풍속·풍향", "value": "2.1 m/s (NW)"},
                    {"kind": "precip", "label": "강수형태", "value": "없음"},
                ],
            ),
        ),
        "astronomy": FakeProvider(
            "astronomy",
            LayerReading(
                key="astronomy",
                status="live",
                sub_score=85,
                golden_hours=[
                    {
                        "mode": "night",
                        "label": "밤 · 천체 골든타임",
                        "timeRange": "21:40 - 01:20",
                        "description": "월령 12% 삭 근처 · 운량 0%",
                    }
                ],
            ),
        ),
        "lightPollution": FakeProvider(
            "lightPollution",
            LayerReading(
                key="lightPollution",
                status="approx",
                sub_score=80,
                evidence={"sqmValue": 21.6, "skyClass": "Class 2 최적 다크스카이"},
            ),
        ),
        "tide": FakeProvider(
            "tide",
            LayerReading(
                key="tide",
                status="stub",
                sub_score=88,
                telemetry=[{"kind": "tide", "label": "조위 상태", "value": "만조 16:15"}],
                golden_hours=[
                    {
                        "mode": "day",
                        "label": "낮 · 탐조 골든타임",
                        "timeRange": "14:00 - 17:30",
                        "description": "만조 2시간 전 갯벌 유입 피크",
                    }
                ],
            ),
        ),
    }


def _install(providers: dict[str, FakeProvider]) -> None:
    service = SuitabilityService(providers)
    app.dependency_overrides[get_suitability_service] = lambda: service


@pytest.fixture(autouse=True)
def fresh_providers():
    _install(_healthy_providers())
    yield
    app.dependency_overrides.clear()


def test_happy_path_returns_full_contract() -> None:
    response = client.get("/api/suitability", params={"lat": 37.5, "lng": 127.0, "mode": "day"})
    assert response.status_code == 200
    body = response.json()

    assert body["mode"] == "day"
    assert body["location"] == {"lat": 37.5, "lng": 127.0}
    assert isinstance(body["score"], int)
    assert isinstance(body["label"], str)
    assert body["sqmValue"] == 21.6
    assert body["skyClass"] == "Class 2 최적 다크스카이"
    assert body["bortleClass"] == convert.sqm_to_bortle(21.6)
    assert body["nightSkyStatus"] == "approx"
    assert body["degraded"] is False

    assert isinstance(body["goldenHours"], list)
    assert len(body["goldenHours"]) == 2
    assert body["goldenHours"][0]["mode"] == "day"
    assert body["goldenHours"][1]["mode"] == "night"
    for entry in body["goldenHours"]:
        assert set(entry) == {"mode", "label", "timeRange", "description"}

    assert isinstance(body["telemetry"], list)
    assert len(body["telemetry"]) == 5
    for entry in body["telemetry"]:
        assert set(entry) == {"kind", "label", "value"}

    assert isinstance(body["layers"], list)
    assert len(body["layers"]) == 4
    for entry in body["layers"]:
        assert set(entry) == {"key", "weight", "subScore", "status"}


def test_light_pollution_evidence_bortle_class_passes_through() -> None:
    providers = _healthy_providers()
    providers["lightPollution"] = FakeProvider(
        "lightPollution",
        LayerReading(
            key="lightPollution",
            status="approx",
            sub_score=60,
            evidence={"sqmValue": 17.5, "skyClass": "some label", "bortleClass": 4},
        ),
    )
    _install(providers)

    response = client.get("/api/suitability", params={"lat": 37.5, "lng": 127.0, "mode": "day"})
    assert response.status_code == 200
    body = response.json()
    assert body["bortleClass"] == 4
    assert body["nightSkyStatus"] == "approx"


def test_mode_changes_score() -> None:
    day_response = client.get("/api/suitability", params={"lat": 37.5, "lng": 127.0, "mode": "day"})
    night_response = client.get("/api/suitability", params={"lat": 37.5, "lng": 127.0, "mode": "night"})
    assert day_response.status_code == 200
    assert night_response.status_code == 200
    assert day_response.json()["score"] != night_response.json()["score"]


def test_provider_exception_degrades_instead_of_500() -> None:
    providers = _healthy_providers()
    providers["tide"] = FakeProvider("tide", raises=True)
    _install(providers)

    response = client.get("/api/suitability", params={"lat": 37.5, "lng": 127.0, "mode": "day"})
    assert response.status_code == 200
    body = response.json()
    assert body["degraded"] is True

    tide_layer = next(layer for layer in body["layers"] if layer["key"] == "tide")
    assert tide_layer["status"] == "unavailable"


def test_missing_lat_returns_422() -> None:
    response = client.get("/api/suitability", params={"lng": 127.0, "mode": "day"})
    assert response.status_code == 422


def test_invalid_mode_returns_422() -> None:
    response = client.get("/api/suitability", params={"lat": 37.5, "lng": 127.0, "mode": "afternoon"})
    assert response.status_code == 422


def test_lat_out_of_range_returns_422() -> None:
    response = client.get("/api/suitability", params={"lat": 200, "lng": 127.0, "mode": "day"})
    assert response.status_code == 422


def test_missing_lng_returns_422() -> None:
    response = client.get("/api/suitability", params={"lat": 37.5, "mode": "day"})
    assert response.status_code == 422


def test_missing_mode_returns_422() -> None:
    response = client.get("/api/suitability", params={"lat": 37.5, "lng": 127.0})
    assert response.status_code == 422


def test_lng_out_of_range_returns_422() -> None:
    response = client.get("/api/suitability", params={"lat": 37.5, "lng": 200, "mode": "day"})
    assert response.status_code == 422


def test_happy_path_moon_is_none_when_astronomy_evidence_lacks_moon_fields() -> None:
    response = client.get("/api/suitability", params={"lat": 37.5, "lng": 127.0, "mode": "day"})
    body = response.json()
    assert body["moon"] is None


def test_astronomy_live_with_full_evidence_populates_moon() -> None:
    providers = _healthy_providers()
    providers["astronomy"] = FakeProvider(
        "astronomy",
        LayerReading(
            key="astronomy",
            status="live",
            sub_score=85,
            golden_hours=[
                {
                    "mode": "night",
                    "label": "밤 · 천체 골든타임",
                    "timeRange": "21:40 - 01:20",
                    "description": "월령 12% 삭 근처 · 운량 0%",
                }
            ],
            evidence={"lunarAgeDays": 14.0, "illuminationPct": 96, "moonrise": "1832", "moonset": "0512"},
        ),
    )
    _install(providers)

    response = client.get("/api/suitability", params={"lat": 37.5, "lng": 127.0, "mode": "night"})
    body = response.json()

    moon = body["moon"]
    assert moon is not None
    assert moon["illumination"] == 96
    assert moon["phaseName"] == "보름달"
    assert moon["moonrise"] == "18:32"
    assert moon["moonset"] == "05:12"
    assert moon["status"] == "live"


def test_astronomy_unavailable_status_yields_moon_none() -> None:
    providers = _healthy_providers()
    providers["astronomy"] = FakeProvider(
        "astronomy",
        LayerReading(
            key="astronomy",
            status="unavailable",
            sub_score=0,
        ),
    )
    _install(providers)

    response = client.get("/api/suitability", params={"lat": 37.5, "lng": 127.0, "mode": "night"})
    body = response.json()

    assert body["moon"] is None
