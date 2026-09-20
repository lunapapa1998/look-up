from __future__ import annotations

from app.observation.service import ObservationMapService
from app.suitability.providers.base import LayerReading

_GANGHWA_LABEL = "인천 강화군"

_RAW_BIRD_RECORD_1 = {
    "nameKo": "알락꼬리마도요",
    "nameSci": "Numenius madagascariensis",
    "speciesCode": "bktgod1",
    "count": 280,
    "obsDt": "2026-09-09 16:16",
    "lat": 37.4715,
    "lng": 126.5312,
    "locId": "L1163669",
    "locName": "영종도--송산만과 갯벌(신불도 남단)",
    "obsValid": True,
}

_RAW_BIRD_RECORD_2 = {
    "nameKo": "검은머리물떼새",
    "nameSci": "Haematopus ostralegus",
    "speciesCode": "eurost1",
    "count": None,
    "obsDt": "2026-09-08 09:00",
    "lat": 37.4715,
    "lng": 126.5312,
    "locId": "L1163669",
    "locName": "영종도--송산만과 갯벌(신불도 남단)",
    "obsValid": True,
}

_FOOD_1 = {"name": "노포1", "addr": "주소1", "distanceM": 100, "lat": 1.0, "lng": 1.0, "contentId": "1"}
_FOOD_2 = {"name": "노포2", "addr": "주소2", "distanceM": 200, "lat": 2.0, "lng": 2.0, "contentId": "2"}


class _FakeLightPollutionProvider:
    def fetch(self, lat: float, lng: float, mode: str) -> LayerReading:
        return LayerReading(
            key="lightPollution",
            status="approx",
            sub_score=50,
            evidence={"sqmValue": 21.7, "bortleClass": 3, "skyClass": "Class 3 test"},
        )


class _RaisingLightPollutionProvider:
    def fetch(self, lat: float, lng: float, mode: str) -> LayerReading:
        raise Exception("light pollution provider failed")


def test_happy_path_assembles_all_three_sources():
    service = ObservationMapService(
        fetch_recent_obs=lambda lat, lng: [_RAW_BIRD_RECORD_1, _RAW_BIRD_RECORD_2],
        light_pollution_provider=_FakeLightPollutionProvider(),
        fetch_nearby_food=lambda lat, lng: [_FOOD_1, _FOOD_2],
    )

    result = service.get_observation_map(37.6, 126.4)

    assert result["degraded"] is False
    assert len(result["spots"]) == 4
    assert [spot["kind"] for spot in result["spots"]] == ["bird", "star", "heritage", "heritage"]

    bird_spot = result["spots"][0]
    assert bird_spot["birds"]["status"] == "community"

    star_spot = result["spots"][1]
    assert star_spot["nightSky"] == {
        "sqmValue": 21.7,
        "bortleClass": 3,
        "skyClass": "Class 3 test",
        "status": "approx",
    }

    heritage_spots = result["spots"][2:]
    assert heritage_spots[0]["heritage"] == {"addr": "주소1", "distanceM": 100, "contentId": "1"}
    assert heritage_spots[1]["heritage"] == {"addr": "주소2", "distanceM": 200, "contentId": "2"}


def test_bird_source_raises_is_absorbed():
    def raising_fetch_recent_obs(lat, lng):
        raise Exception("ebird failed")

    service = ObservationMapService(
        fetch_recent_obs=raising_fetch_recent_obs,
        light_pollution_provider=_FakeLightPollutionProvider(),
        fetch_nearby_food=lambda lat, lng: [_FOOD_1, _FOOD_2],
    )

    result = service.get_observation_map(37.6, 126.4)

    assert result["degraded"] is False
    assert "bird" not in [spot["kind"] for spot in result["spots"]]
    assert [spot["kind"] for spot in result["spots"]] == ["star", "heritage", "heritage"]


def test_star_source_raises_is_absorbed():
    service = ObservationMapService(
        fetch_recent_obs=lambda lat, lng: [_RAW_BIRD_RECORD_1, _RAW_BIRD_RECORD_2],
        light_pollution_provider=_RaisingLightPollutionProvider(),
        fetch_nearby_food=lambda lat, lng: [_FOOD_1, _FOOD_2],
    )

    result = service.get_observation_map(37.6, 126.4)

    assert result["degraded"] is False
    assert "star" not in [spot["kind"] for spot in result["spots"]]
    assert [spot["kind"] for spot in result["spots"]] == ["bird", "heritage", "heritage"]


def test_heritage_source_raises_is_absorbed():
    def raising_fetch_nearby_food(lat, lng):
        raise Exception("tourapi failed")

    service = ObservationMapService(
        fetch_recent_obs=lambda lat, lng: [_RAW_BIRD_RECORD_1, _RAW_BIRD_RECORD_2],
        light_pollution_provider=_FakeLightPollutionProvider(),
        fetch_nearby_food=raising_fetch_nearby_food,
    )

    result = service.get_observation_map(37.6, 126.4)

    assert result["degraded"] is False
    assert "heritage" not in [spot["kind"] for spot in result["spots"]]
    assert [spot["kind"] for spot in result["spots"]] == ["bird", "star"]


def test_total_failure_returns_degraded_empty():
    def raising_fetch_recent_obs(lat, lng):
        raise Exception("ebird failed")

    def raising_fetch_nearby_food(lat, lng):
        raise Exception("tourapi failed")

    service = ObservationMapService(
        fetch_recent_obs=raising_fetch_recent_obs,
        light_pollution_provider=_RaisingLightPollutionProvider(),
        fetch_nearby_food=raising_fetch_nearby_food,
    )

    result = service.get_observation_map(37.6, 126.4)

    assert result == {"region": _GANGHWA_LABEL, "degraded": True, "spots": []}
