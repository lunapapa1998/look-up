from __future__ import annotations

import httpx

from app.suitability.config import get_trails_config


def _to_int_via_float(value: object, default: int = 0) -> int:
    try:
        return int(float(value))  # type: ignore[arg-type]
    except (TypeError, ValueError):
        return default


def parse_food_list(payload: dict, top_n: int = 3) -> list[dict]:
    item = payload["response"]["body"]["items"].get("item")
    if not item:
        return []
    items = [item] if isinstance(item, dict) else item

    foods = [
        {
            "name": raw["title"],
            "addr": raw["addr1"],
            "distanceM": _to_int_via_float(raw.get("dist")),
            "lat": float(raw["mapy"]),
            "lng": float(raw["mapx"]),
            "contentId": raw["contentid"],
        }
        for raw in items
    ]
    foods.sort(key=lambda food: food["distanceM"])
    return foods[:top_n]


def fetch_nearby_food(
    lat: float,
    lng: float,
    client: httpx.Client | None = None,
    radius: int = 5000,
    rows: int = 10,
    top_n: int = 3,
) -> list[dict]:
    config = get_trails_config()
    if not config.tourapi_base_url or not config.service_key:
        return []

    owns_client = client is None
    if client is None:
        client = httpx.Client(timeout=10.0)
    try:
        response = client.get(
            f"{config.tourapi_base_url}/locationBasedList2",
            params={
                "serviceKey": config.service_key,
                "MobileOS": "ETC",
                "MobileApp": "lookup",
                "_type": "json",
                "numOfRows": rows,
                "pageNo": 1,
                "mapX": lng,
                "mapY": lat,
                "radius": radius,
                "contentTypeId": 39,
                "arrange": "E",
            },
        )
        response.raise_for_status()
        return parse_food_list(response.json(), top_n=top_n)
    except Exception:
        return []
    finally:
        if owns_client:
            client.close()
