from __future__ import annotations

from types import SimpleNamespace

from app.suitability.providers.base import LayerReading
from app.trails.service import TrailsService

GANGHWA_SIGUN = "인천 강화군"
SEOGWIPO_SIGUN = "제주 서귀포시"


class _RaisingSuitabilityService:
    def get_suitability(self, lat: float, lng: float, mode: str):
        raise Exception("no network calls allowed in offline tests")


def _course(crs_idx: str, gpx_url: str, sigun: str = GANGHWA_SIGUN) -> dict:
    return {
        "crsIdx": crs_idx,
        "name": f"코스 {crs_idx}",
        "sigun": sigun,
        "distanceKm": 10.0,
        "durationMin": 200,
        "level": 1,
        "cycle": "비순환형",
        "gpxUrl": gpx_url,
    }


class _FakeLightPollutionProvider:
    def __init__(self, sqm_by_gpx_url: dict[str, float], gpx_url_by_lat: dict[float, str]):
        self._sqm_by_gpx_url = sqm_by_gpx_url
        self._gpx_url_by_lat = gpx_url_by_lat

    def fetch(self, lat: float, lng: float, mode: str) -> LayerReading:
        gpx_url = self._gpx_url_by_lat[lat]
        sqm_value = self._sqm_by_gpx_url[gpx_url]
        return LayerReading(
            key="lightPollution",
            status="approx",
            sub_score=50,
            evidence={"sqmValue": sqm_value, "bortleClass": 4, "skyClass": "Class 4"},
        )


def test_degrades_when_course_list_empty():
    service = TrailsService(
        fetch_courses=lambda: [],
        fetch_gpx_endpoints=lambda gpx_url: None,
        fetch_nearby_food=lambda lat, lng: [],
        suitability_service=_RaisingSuitabilityService(),
    )

    result = service.get_trails(37.6, 126.4)

    assert result["degraded"] is True
    assert result["courses"] == []


def test_degrades_when_no_region_match():
    service = TrailsService(
        fetch_courses=lambda: [_course("AAA", "https://example.com/a.gpx", sigun=SEOGWIPO_SIGUN)],
        fetch_gpx_endpoints=lambda gpx_url: None,
        fetch_nearby_food=lambda lat, lng: [],
        suitability_service=_RaisingSuitabilityService(),
    )

    result = service.get_trails(37.6, 126.4)

    assert result["degraded"] is True
    assert result["courses"] == []


def test_ranking_and_tiebreak():
    courses = [
        _course("AAA", "https://example.com/aaa.gpx"),
        _course("BBB", "https://example.com/bbb.gpx"),
        _course("CCC", "https://example.com/ccc.gpx"),
    ]
    courses[0]["distanceKm"] = 5.0
    courses[2]["distanceKm"] = 8.0

    endpoints_by_gpx_url = {
        "https://example.com/aaa.gpx": ({"lat": 1.0, "lng": 1.0}, {"lat": 10.0, "lng": 10.0}),
        "https://example.com/bbb.gpx": ({"lat": 2.0, "lng": 2.0}, {"lat": 20.0, "lng": 20.0}),
        "https://example.com/ccc.gpx": ({"lat": 3.0, "lng": 3.0}, {"lat": 30.0, "lng": 30.0}),
    }
    sqm_by_gpx_url = {
        "https://example.com/aaa.gpx": 21.0,
        "https://example.com/bbb.gpx": 18.0,
        "https://example.com/ccc.gpx": 21.0,
    }
    gpx_url_by_lat = {10.0: "https://example.com/aaa.gpx", 20.0: "https://example.com/bbb.gpx", 30.0: "https://example.com/ccc.gpx"}
    fixed_food = [
        {"name": "노포1", "addr": "주소1", "distanceM": 100, "lat": 0.0, "lng": 0.0, "contentId": "1"},
        {"name": "노포2", "addr": "주소2", "distanceM": 200, "lat": 0.0, "lng": 0.0, "contentId": "2"},
    ]

    service = TrailsService(
        fetch_courses=lambda: courses,
        fetch_gpx_endpoints=lambda gpx_url: endpoints_by_gpx_url[gpx_url],
        fetch_nearby_food=lambda lat, lng: fixed_food,
        light_pollution_provider=_FakeLightPollutionProvider(sqm_by_gpx_url, gpx_url_by_lat),
        suitability_service=_RaisingSuitabilityService(),
    )

    result = service.get_trails(37.6, 126.4)

    assert result["degraded"] is False
    assert [course["crsIdx"] for course in result["courses"]] == ["AAA", "CCC", "BBB"]
    for course in result["courses"]:
        assert course["heritageEats"] == fixed_food
        assert course["daySuitability"] is None
        assert course["nightSuitability"] is None


def test_course_skipped_when_gpx_fetch_fails():
    courses = [
        _course("AAA", "https://example.com/aaa.gpx"),
        _course("BBB", "https://example.com/bbb.gpx"),
    ]

    def fake_fetch_gpx_endpoints(gpx_url: str):
        if gpx_url == "https://example.com/aaa.gpx":
            return None
        return ({"lat": 2.0, "lng": 2.0}, {"lat": 20.0, "lng": 20.0})

    service = TrailsService(
        fetch_courses=lambda: courses,
        fetch_gpx_endpoints=fake_fetch_gpx_endpoints,
        fetch_nearby_food=lambda lat, lng: [],
        light_pollution_provider=_FakeLightPollutionProvider(
            {"https://example.com/bbb.gpx": 19.0}, {20.0: "https://example.com/bbb.gpx"}
        ),
        suitability_service=_RaisingSuitabilityService(),
    )

    result = service.get_trails(37.6, 126.4)

    assert result["degraded"] is False
    assert len(result["courses"]) == 1
    assert result["courses"][0]["crsIdx"] == "BBB"


def test_ranks_all_matched_courses_before_slicing_to_top_k():
    courses = [_course(f"C{i}", f"https://example.com/{i}.gpx") for i in range(6)]

    endpoints_by_gpx_url = {
        f"https://example.com/{i}.gpx": ({"lat": float(i), "lng": float(i)}, {"lat": 10.0 + i, "lng": 10.0 + i})
        for i in range(6)
    }
    gpx_url_by_lat = {10.0 + i: f"https://example.com/{i}.gpx" for i in range(6)}
    sqm_by_gpx_url = {f"https://example.com/{i}.gpx": 18.0 for i in range(6)}
    sqm_by_gpx_url["https://example.com/5.gpx"] = 22.0

    gpx_call_count = {"n": 0}

    def counting_fetch_gpx_endpoints(gpx_url: str):
        gpx_call_count["n"] += 1
        return endpoints_by_gpx_url[gpx_url]

    food_call_count = {"n": 0}

    def counting_fetch_nearby_food(lat: float, lng: float):
        food_call_count["n"] += 1
        return []

    service = TrailsService(
        fetch_courses=lambda: courses,
        fetch_gpx_endpoints=counting_fetch_gpx_endpoints,
        fetch_nearby_food=counting_fetch_nearby_food,
        light_pollution_provider=_FakeLightPollutionProvider(sqm_by_gpx_url, gpx_url_by_lat),
        suitability_service=_RaisingSuitabilityService(),
    )

    result = service.get_trails(37.6, 126.4)

    assert gpx_call_count["n"] == 6
    assert food_call_count["n"] <= 5
    assert result["courses"][0]["crsIdx"] == "C5"


def test_candidate_limit_bounds_gpx_fetch_count():
    courses = [_course(f"C{i:02d}", f"https://example.com/{i}.gpx") for i in range(20)]

    endpoints_by_gpx_url = {
        f"https://example.com/{i}.gpx": ({"lat": float(i), "lng": float(i)}, {"lat": 10.0 + i, "lng": 10.0 + i})
        for i in range(20)
    }
    gpx_url_by_lat = {10.0 + i: f"https://example.com/{i}.gpx" for i in range(20)}
    sqm_by_gpx_url = {f"https://example.com/{i}.gpx": 18.0 for i in range(20)}

    gpx_call_count = {"n": 0}

    def counting_fetch_gpx_endpoints(gpx_url: str):
        gpx_call_count["n"] += 1
        return endpoints_by_gpx_url[gpx_url]

    service = TrailsService(
        fetch_courses=lambda: courses,
        fetch_gpx_endpoints=counting_fetch_gpx_endpoints,
        fetch_nearby_food=lambda lat, lng: [],
        light_pollution_provider=_FakeLightPollutionProvider(sqm_by_gpx_url, gpx_url_by_lat),
        suitability_service=_RaisingSuitabilityService(),
    )

    service.get_trails(37.6, 126.4)

    assert gpx_call_count["n"] == 15


def test_featured_course_gets_suitability():
    courses = [_course(f"C{i}", f"https://example.com/{i}.gpx") for i in range(2)]

    endpoints_by_gpx_url = {
        f"https://example.com/{i}.gpx": ({"lat": float(i), "lng": float(i)}, {"lat": 10.0 + i, "lng": 10.0 + i})
        for i in range(2)
    }
    gpx_url_by_lat = {10.0 + i: f"https://example.com/{i}.gpx" for i in range(2)}
    sqm_by_gpx_url = {
        "https://example.com/0.gpx": 22.0,
        "https://example.com/1.gpx": 18.0,
    }

    class _FakeSuitabilityService:
        def get_suitability(self, lat: float, lng: float, mode: str):
            return SimpleNamespace(score=77, label=f"{mode}-label", degraded=False)

    service = TrailsService(
        fetch_courses=lambda: courses,
        fetch_gpx_endpoints=lambda gpx_url: endpoints_by_gpx_url[gpx_url],
        fetch_nearby_food=lambda lat, lng: [],
        light_pollution_provider=_FakeLightPollutionProvider(sqm_by_gpx_url, gpx_url_by_lat),
        suitability_service=_FakeSuitabilityService(),
    )

    result = service.get_trails(37.6, 126.4)

    featured = result["courses"][0]
    assert featured["crsIdx"] == "C0"
    assert featured["daySuitability"] == {"score": 77, "label": "day-label", "status": "live"}
    assert featured["nightSuitability"] == {"score": 77, "label": "night-label", "status": "live"}

    for course in result["courses"][1:]:
        assert course["daySuitability"] is None
        assert course["nightSuitability"] is None


def test_suitability_and_light_pollution_exceptions_are_absorbed():
    courses = [
        _course("AAA", "https://example.com/aaa.gpx"),
        _course("BBB", "https://example.com/bbb.gpx"),
    ]

    endpoints_by_gpx_url = {
        "https://example.com/aaa.gpx": ({"lat": 1.0, "lng": 1.0}, {"lat": 10.0, "lng": 10.0}),
        "https://example.com/bbb.gpx": ({"lat": 2.0, "lng": 2.0}, {"lat": 20.0, "lng": 20.0}),
    }

    class _FailingLightPollutionProvider:
        def fetch(self, lat: float, lng: float, mode: str):
            if lat == 10.0:
                raise Exception("light pollution provider failed")
            return LayerReading(
                key="lightPollution",
                status="approx",
                sub_score=50,
                evidence={"sqmValue": 19.0, "bortleClass": 4, "skyClass": "Class 4"},
            )

    class _FailingSuitabilityService:
        def get_suitability(self, lat: float, lng: float, mode: str):
            raise Exception("suitability provider failed")

    service = TrailsService(
        fetch_courses=lambda: courses,
        fetch_gpx_endpoints=lambda gpx_url: endpoints_by_gpx_url[gpx_url],
        fetch_nearby_food=lambda lat, lng: [],
        light_pollution_provider=_FailingLightPollutionProvider(),
        suitability_service=_FailingSuitabilityService(),
    )

    result = service.get_trails(37.6, 126.4)

    assert result["degraded"] is False
    assert len(result["courses"]) == 1
    assert result["courses"][0]["crsIdx"] == "BBB"
    assert result["courses"][0]["daySuitability"] is None
    assert result["courses"][0]["nightSuitability"] is None
