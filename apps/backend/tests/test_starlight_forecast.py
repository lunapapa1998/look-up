from __future__ import annotations

from datetime import date, datetime, timezone
import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.starlight.astronomy import (
    azimuth_to_direction,
    calculate_approx_moon,
    calculate_sun_events,
    equatorial_to_horizontal,
)
from app.starlight.catalog import CELESTIAL_CATALOG
from app.starlight.service import StarlightForecastService


@pytest.fixture
def client() -> TestClient:
    return TestClient(app)


def test_calculate_sun_events_ordering() -> None:
    # Seoul / Ganghwa
    lat, lng = 37.5, 126.7
    target_date = date(2026, 9, 18)
    events = calculate_sun_events(lat, lng, target_date)

    sunset = events["sunset"]
    civil = events["civil_twilight_end"]
    nautical = events["nautical_twilight_end"]
    astronomical = events["astronomical_twilight_end"]

    assert sunset < civil < nautical < astronomical
    # In September in Korea, astronomical twilight ends around 20:00 ~ 20:30 KST
    assert astronomical.hour in (20, 21)


def test_azimuth_to_direction() -> None:
    assert azimuth_to_direction(0.0) == "북쪽"
    assert azimuth_to_direction(45.0) == "북동쪽"
    assert azimuth_to_direction(90.0) == "동쪽"
    assert azimuth_to_direction(135.0) == "남동쪽"
    assert azimuth_to_direction(180.0) == "남쪽"
    assert azimuth_to_direction(225.0) == "남서쪽"
    assert azimuth_to_direction(270.0) == "서쪽"
    assert azimuth_to_direction(315.0) == "북서쪽"
    assert azimuth_to_direction(359.0) == "북쪽"


def test_equatorial_to_horizontal_zenith_and_polar() -> None:
    # A celestial target right at North Celestial Pole (+90 deg dec)
    dt_utc = datetime(2026, 9, 18, 12, 0, tzinfo=timezone.utc)
    alt, az = equatorial_to_horizontal(0.0, 90.0, 37.5, 126.7, dt_utc)
    # Altitude of Polaris / Celestial North Pole equals observer's latitude ~37.5°
    assert pytest.approx(alt, abs=1.0) == 37.5
    # Direction is North
    assert azimuth_to_direction(az) == "북쪽"


def test_approx_moon_calculation() -> None:
    moon = calculate_approx_moon(date(2026, 9, 18))
    assert 0.0 <= moon["age_days"] <= 30.0
    assert 0 <= moon["illumination_pct"] <= 100
    assert isinstance(moon["phase_name"], str)


def test_service_forecast_sentence_structure() -> None:
    service = StarlightForecastService()
    # Test coordinates (Ganghwa) on 2026-09-18
    resp = service.generate_forecast(
        lat=37.7,
        lng=126.4,
        target_date=date(2026, 9, 18),
        override_twilight_end="20:45",
        target_id="perseus_milky_way",
        override_sqm=21.5,
        override_moon_illumination=10,
    )

    assert resp.title == "야간 전환 별빛 예보"
    assert "오늘 20:45 일몰 및 박명 종료 후" in resp.summary
    assert "방위에서" in resp.summary
    assert "페르세우스자리 은하수" in resp.summary
    assert "육안 관측이 시작됩니다." in resp.summary

    assert resp.target.id == "perseus_milky_way"
    assert resp.target.observation_mode == "육안 관측"
    assert resp.conditions.milky_way_visible is True


def test_service_adapts_to_urban_light_pollution() -> None:
    service = StarlightForecastService()
    # City with heavy light pollution (SQM 16.5) and bright moon (80%)
    resp = service.generate_forecast(
        lat=37.5004,
        lng=126.7984,
        target_date=date(2026, 9, 18),
        target_id="perseus_milky_way",
        override_sqm=16.5,
        override_moon_illumination=80,
    )

    # In heavy light pollution, milky way is not naked-eye visible
    assert resp.conditions.milky_way_visible is False
    assert resp.target.observation_mode in ("안시 관측", "망원경 관측")


def test_service_auto_selects_visible_target() -> None:
    service = StarlightForecastService()
    # No target_id provided -> auto selects best visible target
    resp = service.generate_forecast(
        lat=37.5,
        lng=126.7,
        target_date=date(2026, 9, 18),
    )

    assert resp.target.name != ""
    assert resp.target.altitude_deg > 0
    assert resp.target.direction in ["북쪽", "북동쪽", "동쪽", "남동쪽", "남쪽", "남서쪽", "서쪽", "북서쪽"]
    assert "일몰 및 박명 종료 후" in resp.summary
    assert len(resp.all_visible_targets) > 0


def test_api_starlight_endpoint(client: TestClient) -> None:
    response = client.get("/api/starlight-forecast?lat=37.5004&lng=126.7984")
    assert response.status_code == 200
    data = response.json()

    assert data["title"] == "야간 전환 별빛 예보"
    assert "일몰 및 박명 종료 후" in data["summary"]
    assert data["location"]["lat"] == 37.5004
    assert data["location"]["lng"] == 126.7984
    assert data["timing"]["sunset"] != ""
    assert data["timing"]["astronomical_twilight_end"] != ""
    assert data["target"]["name"] != ""
    assert data["target"]["direction"] != ""


def test_api_starlight_endpoint_with_params(client: TestClient) -> None:
    response = client.get(
        "/api/starlight-forecast",
        params={
            "lat": 37.7,
            "lng": 126.4,
            "date": "2026-09-18",
            "target": "perseus_milky_way",
            "twilight_end": "20:45",
            "sqm": 21.8,
            "moon_illumination": 5,
        },
    )
    assert response.status_code == 200
    data = response.json()

    expected = (
        f"오늘 20:45 일몰 및 박명 종료 후 "
        f"{data['target']['direction']} 방위에서 페르세우스자리 은하수 육안 관측이 시작됩니다."
    )
    assert data["summary"] == expected
    assert data["target"]["id"] == "perseus_milky_way"
    assert data["target"]["observation_mode"] == "육안 관측"
    assert data["conditions"]["milky_way_visible"] is True


def test_api_starlight_invalid_date(client: TestClient) -> None:
    response = client.get("/api/starlight-forecast?lat=37.5&lng=126.7&date=invalid-date")
    assert response.status_code == 400
    assert "Invalid date format" in response.json()["detail"]
