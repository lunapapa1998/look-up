from __future__ import annotations

import json
from pathlib import Path

import pytest

from app.trails.durunubi import parse_course_list, parse_gpx_endpoints
from app.trails.service import match_region
from app.trails.tourapi import parse_food_list

FIXTURES_DIR = Path(__file__).parent / "fixtures"


def _load_json(name: str) -> dict:
    return json.loads((FIXTURES_DIR / name).read_text(encoding="utf-8"))


def test_parse_course_list_returns_expected_fields():
    payload = _load_json("durunubi_courselist.json")
    courses = parse_course_list(payload)

    assert len(courses) == 2

    first, second = courses
    assert first["crsIdx"] == "T_CRS_MNG0000005118"
    assert first["name"] == "남파랑길 3코스"
    assert first["sigun"] == "부산 영도구"
    assert first["distanceKm"] == 14.0
    assert first["durationMin"] == 330
    assert first["level"] == 2

    assert second["crsIdx"] == "T_CRS_MNG0000009999"
    assert second["name"] == "서해랑길 강화 코스"
    assert second["sigun"] == "인천 강화군"
    assert second["distanceKm"] == 11.0
    assert second["durationMin"] == 210
    assert second["level"] == 1


def test_parse_course_list_raises_on_bad_result_code():
    payload = {
        "response": {
            "header": {"resultCode": "9999", "resultMsg": "ERROR"},
            "body": {"items": {"item": []}},
        }
    }
    with pytest.raises(ValueError):
        parse_course_list(payload)


def test_parse_gpx_endpoints_returns_start_and_end():
    gpx_text = (FIXTURES_DIR / "durunubi_course.gpx").read_text(encoding="utf-8")
    start, end = parse_gpx_endpoints(gpx_text)

    assert start["lat"] == pytest.approx(35.0965626320323)
    assert start["lng"] == pytest.approx(129.035967774477)
    assert end["lat"] == pytest.approx(35.0874667791044)
    assert end["lng"] == pytest.approx(129.004487268964)


def test_parse_gpx_endpoints_raises_on_no_trkpt():
    with pytest.raises(ValueError):
        parse_gpx_endpoints("<gpx><trk><trkseg></trkseg></trk></gpx>")


def test_parse_food_list_top_n_default():
    payload = _load_json("tourapi_food.json")
    foods = parse_food_list(payload, top_n=3)

    assert len(foods) == 2
    first, second = foods
    assert first["name"] == "꽃게와낙지"
    assert first["distanceM"] == 1363
    assert first["lat"] == pytest.approx(37.6003291209)
    assert first["lng"] == pytest.approx(126.4097886867)
    assert first["contentId"] == "855186"
    assert second["name"] == "멍때림"


def test_parse_food_list_top_n_one():
    payload = _load_json("tourapi_food.json")
    foods = parse_food_list(payload, top_n=1)

    assert len(foods) == 1
    assert foods[0]["name"] == "꽃게와낙지"


def test_match_region_matches_ganghwa_token():
    payload = _load_json("durunubi_courselist.json")
    courses = parse_course_list(payload)

    matched = match_region(["강화"], courses)

    assert len(matched) == 1
    assert matched[0]["sigun"] == "인천 강화군"


def test_match_region_returns_empty_for_unrelated_place():
    payload = _load_json("durunubi_courselist.json")
    courses = parse_course_list(payload)

    matched = match_region(["서울 종로구"], courses)

    assert matched == []
