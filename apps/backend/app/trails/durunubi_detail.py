from __future__ import annotations

import re

import httpx

from app.suitability.config import get_trails_config

_TRAVELER_START_RE = re.compile(r"시점\s*[:：]\s*([^<\r\n]+)")
_TRAVELER_END_RE = re.compile(r"종점\s*[:：]\s*([^<\r\n]+)")
_TRKPT_RE = re.compile(r"<trkpt\b.*?>.*?</trkpt>", re.DOTALL)
_ELE_RE = re.compile(r"<ele>([-0-9.]+)</ele>")


def parse_course_detail_item(raw_item: dict) -> dict:
    description = (
        raw_item.get("crsContents")
        or raw_item.get("crsSummary")
        or raw_item.get("crsTourInfo")
        or None
    )
    theme_id = raw_item.get("routeIdx") or None

    traveler_info = raw_item.get("travelerinfo")
    start_name = None
    end_name = None
    if traveler_info:
        start_match = _TRAVELER_START_RE.search(traveler_info)
        if start_match:
            start_name = start_match.group(1).strip()
        end_match = _TRAVELER_END_RE.search(traveler_info)
        if end_match:
            end_name = end_match.group(1).strip()

    return {
        "description": description,
        "themeId": theme_id,
        "startName": start_name,
        "endName": end_name,
        "travelerInfo": traveler_info or None,
        "tourInfo": raw_item.get("crsTourInfo") or None,
    }


def parse_gpx_elevation_profile(gpx_text: str, max_samples: int = 20) -> list:
    trkpt_blocks = _TRKPT_RE.findall(gpx_text)
    n = len(trkpt_blocks)
    if n == 0:
        return []

    survived: list[dict] = []
    for idx, block in enumerate(trkpt_blocks):
        match = _ELE_RE.search(block)
        if not match:
            continue
        position_ratio = idx / (n - 1) if n > 1 else 0.0
        survived.append({"positionRatio": position_ratio, "elevationM": float(match.group(1))})

    step = max(1, n // max_samples)
    sampled = survived[0::step]

    last_match = _ELE_RE.search(trkpt_blocks[-1])
    if last_match and not (sampled and sampled[-1]["positionRatio"] == 1.0):
        sampled.append({"positionRatio": 1.0, "elevationM": float(last_match.group(1))})

    return sampled


def _degraded_result(crs_idx: str, found: bool, degraded: bool) -> dict:
    return {
        "crsIdx": crs_idx,
        "found": found,
        "description": None,
        "themeId": None,
        "startName": None,
        "endName": None,
        "travelerInfo": None,
        "tourInfo": None,
        "elevationProfile": [],
        "degraded": degraded,
    }


def fetch_course_detail(crs_idx: str, client: httpx.Client | None = None) -> dict:
    try:
        config = get_trails_config()
        if not config.durunubi_base_url or not config.service_key:
            return _degraded_result(crs_idx, False, True)

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
                    "numOfRows": 1000,
                    "pageNo": 1,
                    "brdDiv": "DNWW",
                },
            )
            response.raise_for_status()
            payload = response.json()

            result_code = payload["response"]["header"]["resultCode"]
            item = None
            if result_code == "0000":
                item = payload["response"]["body"]["items"].get("item")
            if not item:
                return _degraded_result(crs_idx, False, False)
            items = [item] if isinstance(item, dict) else item

            raw_item = next((raw for raw in items if raw.get("crsIdx") == crs_idx), None)
            if raw_item is None:
                return _degraded_result(crs_idx, False, False)

            parsed = parse_course_detail_item(raw_item)

            elevation_profile: list = []
            gpx_url = raw_item.get("gpxpath")
            if gpx_url:
                try:
                    gpx_response = client.get(gpx_url)
                    gpx_response.raise_for_status()
                    elevation_profile = parse_gpx_elevation_profile(gpx_response.text)
                except Exception:
                    elevation_profile = []

            return {
                "crsIdx": crs_idx,
                "found": True,
                "description": parsed["description"],
                "themeId": parsed["themeId"],
                "startName": parsed["startName"],
                "endName": parsed["endName"],
                "travelerInfo": parsed["travelerInfo"],
                "tourInfo": parsed["tourInfo"],
                "elevationProfile": elevation_profile,
                "degraded": False,
            }
        finally:
            if owns_client:
                client.close()
    except Exception:
        return _degraded_result(crs_idx, False, True)
