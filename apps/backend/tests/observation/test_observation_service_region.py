from __future__ import annotations

import pytest

from app.observation.service import ObservationMapService
from app.suitability.providers.base import LayerReading


class _FakeLightPollutionProvider:
    def fetch(self, lat: float, lng: float, mode: str) -> LayerReading:
        return LayerReading(
            key="lightPollution",
            status="approx",
            sub_score=50,
            evidence={"sqmValue": 21.7, "bortleClass": 3, "skyClass": "Class 3 test"},
        )


def test_region_without_star_spot_omits_star_spot():
    service = ObservationMapService(
        fetch_recent_obs=lambda lat, lng: [],
        light_pollution_provider=_FakeLightPollutionProvider(),
        fetch_nearby_food=lambda lat, lng: [],
    )

    result = service.get_observation_map(37.6, 126.4, region_id="seosan")

    assert result["region"] == "충남 서산시"
    assert all(spot["kind"] != "star" for spot in result["spots"])


def test_unknown_region_id_falls_back_to_nearest():
    service = ObservationMapService(
        fetch_recent_obs=lambda lat, lng: [],
        light_pollution_provider=_FakeLightPollutionProvider(),
        fetch_nearby_food=lambda lat, lng: [],
    )

    result = service.get_observation_map(37.6, 126.4, region_id="not-a-real-region")

    assert result["region"] == "인천 강화군"


def test_selected_region_center_drives_ebird_and_food_queries():
    recent_obs_calls: list[tuple[float, float]] = []
    nearby_food_calls: list[tuple[float, float]] = []

    service = ObservationMapService(
        fetch_recent_obs=lambda lat, lng: (recent_obs_calls.append((lat, lng)), [])[1],
        light_pollution_provider=_FakeLightPollutionProvider(),
        fetch_nearby_food=lambda lat, lng: (nearby_food_calls.append((lat, lng)), [])[1],
    )

    service.get_observation_map(37.6, 126.4, region_id="yeongyang")

    assert len(recent_obs_calls) == 1
    assert recent_obs_calls[0][0] == pytest.approx(36.6666)
    assert recent_obs_calls[0][1] == pytest.approx(129.1124)

    assert len(nearby_food_calls) == 1
    assert nearby_food_calls[0][0] == pytest.approx(36.6666)
    assert nearby_food_calls[0][1] == pytest.approx(129.1124)
