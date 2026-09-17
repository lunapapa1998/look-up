from __future__ import annotations

from datetime import datetime
from pathlib import Path

import pytest

from app.suitability.providers.tide import TideProvider, _parse_xml_items
from app.suitability.providers.tide_stations import nearest_station

_TIDE_FIXTURE = Path(__file__).parent / "fixtures" / "khoa_tide_sample.xml"


@pytest.fixture
def tide_items() -> list[dict]:
    return _parse_xml_items(_TIDE_FIXTURE.read_text())


def test_day_mode_produces_golden_hour_around_daytime_high(tide_items: list[dict]) -> None:
    reading = TideProvider().parse(tide_items, "day", datetime(2026, 9, 8, 1, 0))

    assert reading.status == "live"
    assert reading.sub_score == 85
    assert len(reading.golden_hours) == 1
    entry = reading.golden_hours[0]
    assert entry["timeRange"] == "12:46 - 14:46"
    assert "만조" in entry["description"]
    assert "14:46" in entry["description"]


def test_night_mode_still_produces_day_golden_hour_with_lower_sub_score(
    tide_items: list[dict],
) -> None:
    reading = TideProvider().parse(tide_items, "night", datetime(2026, 9, 8, 1, 0))

    assert len(reading.golden_hours) == 1
    entry = reading.golden_hours[0]
    assert entry["mode"] == "day"
    assert entry["timeRange"] == "12:46 - 14:46"
    assert reading.sub_score == 70


def test_telemetry_reports_next_upcoming_extreme(tide_items: list[dict]) -> None:
    reading = TideProvider().parse(tide_items, "day", datetime(2026, 9, 8, 1, 0))

    assert reading.telemetry == [{"kind": "tide", "label": "조위 상태", "value": "만조 02:26"}]


def test_telemetry_falls_back_to_last_extreme_when_all_are_past(tide_items: list[dict]) -> None:
    reading = TideProvider().parse(tide_items, "day", datetime(2026, 9, 8, 23, 0))

    assert reading.telemetry == [{"kind": "tide", "label": "조위 상태", "value": "간조 20:58"}]


def test_nearest_station_matches_exact_coordinates() -> None:
    station = nearest_station(37.45194, 126.59222)

    assert station.code == "DT_0001"


def _make_item(predc_dt: str, level: str) -> dict:
    return {
        "obsvtrNm": "인천",
        "lat": "37.45194",
        "lot": "126.59222",
        "predcDt": predc_dt,
        "predcTdlvVl": level,
        "extrSe": "",
    }


@pytest.mark.parametrize("mode", ["day", "night"])
def test_raises_when_no_daytime_high_tide_exists(mode: str) -> None:
    items = [
        _make_item("2026-09-08 00:10", "700.0"),
        _make_item("2026-09-08 05:30", "200.0"),
        _make_item("2026-09-08 19:15", "750.0"),
        _make_item("2026-09-08 23:40", "150.0"),
    ]

    with pytest.raises(ValueError):
        TideProvider().parse(items, mode, datetime(2026, 9, 8, 1, 0))


def test_day_mode_picks_highest_daytime_high_not_first() -> None:
    items = [
        _make_item("2026-09-08 03:00", "100.0"),
        _make_item("2026-09-08 07:00", "600.0"),
        _make_item("2026-09-08 11:00", "200.0"),
        _make_item("2026-09-08 15:00", "800.0"),
        _make_item("2026-09-08 21:00", "150.0"),
    ]

    reading = TideProvider().parse(items, "day", datetime(2026, 9, 8, 1, 0))

    assert len(reading.golden_hours) == 1
    entry = reading.golden_hours[0]
    assert entry["timeRange"] == "13:00 - 15:00"
    assert "15:00" in entry["description"]
    assert "07:00" not in entry["timeRange"]
    assert "07:00" not in entry["description"]


def test_fetch_absorbs_client_exception_and_returns_stub(monkeypatch) -> None:
    import app.suitability.providers.tide as tide_module
    from app.suitability.config import TideConfig

    monkeypatch.setattr(
        tide_module,
        "get_tide_config",
        lambda: TideConfig(base_url="https://example.invalid", service_key="test-key"),
    )

    class _FakeClient:
        def get(self, *args, **kwargs):
            raise RuntimeError("network exploded")

    reading = TideProvider(client=_FakeClient()).fetch(37.45, 126.7, "day")

    assert reading.status == "stub"
