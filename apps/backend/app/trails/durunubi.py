from __future__ import annotations

import re

import httpx

from app.suitability.config import get_trails_config

_GPX_LATLON_RE = re.compile(r'lat="([-0-9.]+)"\s+lon="([-0-9.]+)"')


def _to_float(value: object, default: float = 0.0) -> float:
    try:
        return float(value)  # type: ignore[arg-type]
    except (TypeError, ValueError):
        return default


def _to_int_via_float(value: object, default: int = 0) -> int:
    try:
        return int(float(value))  # type: ignore[arg-type]
    except (TypeError, ValueError):
        return default


def parse_course_list(payload: dict) -> list[dict]:
    result_code = payload["response"]["header"]["resultCode"]
    if result_code != "0000":
        raise ValueError(f"unexpected resultCode: {result_code!r}")

    item = payload["response"]["body"]["items"].get("item")
    if not item:
        raise ValueError("no items in course list response")
    items = [item] if isinstance(item, dict) else item

    courses: list[dict] = []
    for raw in items:
        courses.append(
            {
                "crsIdx": raw["crsIdx"],
                "name": raw["crsKorNm"],
                "sigun": raw["sigun"],
                "distanceKm": _to_float(raw.get("crsDstnc")),
                "durationMin": _to_int_via_float(raw.get("crsTotlRqrmHour")),
                "level": _to_int_via_float(raw.get("crsLevel")),
                "cycle": raw["crsCycle"],
                "gpxUrl": raw["gpxpath"],
            }
        )
    return courses


def parse_gpx_endpoints(gpx_text: str) -> tuple[dict, dict]:
    matches = _GPX_LATLON_RE.findall(gpx_text)
    if not matches:
        raise ValueError("no trkpt lat/lon found in gpx text")

    first_lat, first_lon = matches[0]
    last_lat, last_lon = matches[-1]
    start = {"lat": float(first_lat), "lng": float(first_lon)}
    end = {"lat": float(last_lat), "lng": float(last_lon)}
    return start, end


def fetch_courses(
    client: httpx.Client | None = None, brd_div: str = "DNWW", max_rows: int = 1000
) -> list[dict]:
    config = get_trails_config()
    if not config.durunubi_base_url or not config.service_key:
        return []

    owns_client = client is None
    if client is None:
        client = httpx.Client(timeout=10.0)
    try:
        response = client.get(
            f"{config.durunubi_base_url}/courseList",
            params={
                "serviceKey": config.service_key,
                "MobileOS": "ETC",
                "MobileApp": "lookup",
                "_type": "json",
                "numOfRows": max_rows,
                "pageNo": 1,
                "brdDiv": brd_div,
            },
        )
        response.raise_for_status()
        return parse_course_list(response.json())
    except Exception:
        return []
    finally:
        if owns_client:
            client.close()


def fetch_gpx_endpoints(
    gpx_url: str, client: httpx.Client | None = None
) -> tuple[dict, dict] | None:
    owns_client = client is None
    if client is None:
        client = httpx.Client(timeout=10.0)
    try:
        response = client.get(gpx_url)
        response.raise_for_status()
        return parse_gpx_endpoints(response.text)
    except Exception:
        return None
    finally:
        if owns_client:
            client.close()
