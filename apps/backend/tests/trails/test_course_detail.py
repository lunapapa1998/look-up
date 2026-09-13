from __future__ import annotations

from pathlib import Path

import pytest

from app.trails.durunubi_detail import parse_course_detail_item, parse_gpx_elevation_profile

FIXTURES_DIR = Path(__file__).parent / "fixtures"


def test_parse_course_detail_item_full() -> None:
    raw_item = {
        "crsIdx": "T_CRS_MNG0000005118",
        "crsContents": "남파랑길 3코스 설명입니다.",
        "routeIdx": "T_ROUTE_MNG0000000001",
        "travelerinfo": "- 시점 : 영도대교 입구(부산 중구 태종로 8)<br>- 종점 : 감천사거리(부산 사하구 감천동)",
        "crsTourInfo": "- 부산의 유명한 관광지인 용두산공원, 국제시장",
    }

    result = parse_course_detail_item(raw_item)

    assert result == {
        "description": "남파랑길 3코스 설명입니다.",
        "themeId": "T_ROUTE_MNG0000000001",
        "startName": "영도대교 입구(부산 중구 태종로 8)",
        "endName": "감천사거리(부산 사하구 감천동)",
        "travelerInfo": "- 시점 : 영도대교 입구(부산 중구 태종로 8)<br>- 종점 : 감천사거리(부산 사하구 감천동)",
        "tourInfo": "- 부산의 유명한 관광지인 용두산공원, 국제시장",
    }


def test_parse_course_detail_item_missing_description_fields() -> None:
    raw_item = {"crsIdx": "C1"}

    result = parse_course_detail_item(raw_item)

    assert result["description"] is None


def test_parse_course_detail_item_missing_travelerinfo() -> None:
    raw_item = {"crsIdx": "C1", "crsContents": "설명"}

    result = parse_course_detail_item(raw_item)

    assert result["startName"] is None
    assert result["endName"] is None


def test_parse_gpx_elevation_profile_from_fixture() -> None:
    gpx_text = (FIXTURES_DIR / "durunubi_course.gpx").read_text(encoding="utf-8")

    profile = parse_gpx_elevation_profile(gpx_text)

    assert len(profile) == 6
    assert profile[0]["positionRatio"] == pytest.approx(0.0)
    assert profile[-1]["positionRatio"] == pytest.approx(1.0)
    assert profile[0]["elevationM"] == pytest.approx(8.102)
    assert profile[-1]["elevationM"] == pytest.approx(16.742)


def test_parse_gpx_elevation_profile_empty_gpx() -> None:
    assert parse_gpx_elevation_profile("") == []
