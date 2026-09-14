from __future__ import annotations

import os
from datetime import datetime, timedelta, timezone

import httpx
import pytest

from app.species import tide_today
from app.species.tide_today import fetch_today_tides
from app.suitability.config import TideConfig

_KST = timezone(timedelta(hours=9))

_INCHEON = (37.45194, 126.59222)  # exact match to DT_0001, distance=0
_CHUNCHEON = (37.8813, 127.7300)  # landlocked, far from all 36 known stations

# Determinism note: the XML fixtures below stamp predcDt with datetime.now(KST)'s
# actual date (rather than freezing/injecting "today"), so the date-filter step
# inside fetch_today_tides always matches "today" regardless of when tests run.


def _today_kst_str() -> str:
    return datetime.now(_KST).date().isoformat()


def _build_xml(items: list[tuple[str, str, str]]) -> str:
    item_xml = "".join(
        f"<item><predcDt>{dt}</predcDt><predcTdlvVl>{level}</predcTdlvVl>"
        f"<obsvtrNm>{name}</obsvtrNm></item>"
        for dt, level, name in items
    )
    return (
        "<response><header><resultCode>00</resultCode><resultMsg>OK</resultMsg></header>"
        f"<body><items>{item_xml}</items></body></response>"
    )


def FakeClient(
    response: httpx.Response | None = None, exc: Exception | None = None
) -> httpx.Client:
    holder: dict[str, httpx.Client] = {}

    def handler(request: httpx.Request) -> httpx.Response:
        holder["client"].called = True
        if exc is not None:
            raise exc
        return response

    client = httpx.Client(transport=httpx.MockTransport(handler))
    client.called = False
    holder["client"] = client
    return client


def test_coastal_match_returns_today_extremes_sorted_and_classified(monkeypatch):
    monkeypatch.setattr(
        tide_today,
        "get_tide_config",
        lambda: TideConfig(base_url="https://example.test/tide", service_key="KEY"),
    )
    today = _today_kst_str()
    xml = _build_xml(
        [
            (f"{today} 00:00", "100.0", "인천"),
            (f"{today} 06:00", "500.0", "인천"),
            (f"{today} 12:00", "90.0", "인천"),
            (f"{today} 18:00", "480.0", "인천"),
        ]
    )
    fake_client = FakeClient(response=httpx.Response(200, text=xml))

    result = fetch_today_tides(*_INCHEON, client=fake_client)

    assert result["found"] is True
    assert result["degraded"] is False
    assert result["stationName"] == "인천"
    assert result["extremes"] == [
        {"time": "00:00", "kind": "low", "levelCm": 100},
        {"time": "06:00", "kind": "high", "levelCm": 500},
        {"time": "12:00", "kind": "low", "levelCm": 90},
        {"time": "18:00", "kind": "high", "levelCm": 480},
    ]


def test_inland_coordinate_returns_not_found_without_network_call():
    fake_client = FakeClient(response=httpx.Response(200, text="<response/>"))

    result = fetch_today_tides(*_CHUNCHEON, client=fake_client)

    assert result == {"found": False, "degraded": False, "stationName": None, "extremes": []}
    assert fake_client.called is False


def test_missing_config_returns_degraded(monkeypatch):
    monkeypatch.setattr(
        tide_today,
        "get_tide_config",
        lambda: TideConfig(base_url="", service_key=""),
    )
    fake_client = FakeClient(response=httpx.Response(200, text="<response/>"))

    result = fetch_today_tides(*_INCHEON, client=fake_client)

    assert result == {"found": False, "degraded": True, "stationName": None, "extremes": []}
    assert fake_client.called is False


def test_khoa_http_error_returns_degraded(monkeypatch):
    monkeypatch.setattr(
        tide_today,
        "get_tide_config",
        lambda: TideConfig(base_url="https://example.test/tide", service_key="KEY"),
    )
    fake_client = FakeClient(exc=httpx.ConnectError("boom"))

    result = fetch_today_tides(*_INCHEON, client=fake_client)

    assert result == {"found": False, "degraded": True, "stationName": None, "extremes": []}


def test_khoa_malformed_xml_returns_degraded(monkeypatch):
    monkeypatch.setattr(
        tide_today,
        "get_tide_config",
        lambda: TideConfig(base_url="https://example.test/tide", service_key="KEY"),
    )
    fake_client = FakeClient(response=httpx.Response(200, text="not xml"))

    result = fetch_today_tides(*_INCHEON, client=fake_client)

    assert result == {"found": False, "degraded": True, "stationName": None, "extremes": []}


pytestmark_live = pytest.mark.skipif(
    os.getenv("RUN_LIVE_TESTS") != "1",
    reason=(
        "live test -- set the RUN_LIVE_TESTS environment variable to the "
        "value 1 and pass the -m live selector to run against the real KHOA API"
    ),
)


@pytestmark_live
@pytest.mark.live
def test_fetch_today_tides_live_fetch() -> None:
    result = fetch_today_tides(lat=37.73194, lng=126.52222)

    assert result["found"] is True
    assert len(result["extremes"]) > 0
