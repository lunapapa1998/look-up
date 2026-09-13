from __future__ import annotations

import re

import httpx

from app.suitability.config import get_observation_config

_TOP_SPECIES_N = 5
_MAX_LOCATIONS = 20

_COORD_SUFFIX_RE = re.compile(r"\s*\(\s*-?\d+(?:\.\d+)?\s*,\s*-?\d+(?:\.\d+)?\s*\)\s*$")
_ADDR_PREFIX_RE = re.compile(r"^[\d\-]+\s*")


def _clean_personal_locname(raw: str) -> str:
    without_coord = _COORD_SUFFIX_RE.sub("", raw)
    segments = [segment.strip() for segment in without_coord.split(",")]
    kept = [segment for segment in segments if segment and segment.upper() != "KR"]
    if not kept:
        return without_coord.split(',')[0].strip() or without_coord.strip()
    first = kept[0]
    cleaned = _ADDR_PREFIX_RE.sub("", first)
    return cleaned if cleaned else first


def parse_recent_obs(payload: list[dict]) -> list[dict]:
    normalized: list[dict] = []
    for raw in payload:
        normalized.append(
            {
                "nameKo": raw["comName"],
                "nameSci": raw["sciName"],
                "speciesCode": raw["speciesCode"],
                "count": raw.get("howMany"),
                "obsDt": str(raw["obsDt"]),
                "lat": float(raw["lat"]),
                "lng": float(raw["lng"]),
                "locId": raw["locId"],
                "locName": raw["locName"],
                "locationPrivate": bool(raw.get("locationPrivate", False)),
                "obsValid": bool(raw.get("obsValid", True)),
            }
        )
    return normalized


def aggregate_by_location(obs: list[dict]) -> list[dict]:
    groups: dict[str, dict] = {}
    for record in obs:
        loc_id = record["locId"]
        group = groups.setdefault(
            loc_id,
            {
                "locId": loc_id,
                "locName": record["locName"],
                "lat": record["lat"],
                "lng": record["lng"],
                "locationPrivate": record.get("locationPrivate", False),
                "records": [],
            },
        )
        group["records"].append(record)

    results: list[dict] = []
    for group in groups.values():
        by_species: dict[str, dict] = {}
        for record in group["records"]:
            species_code = record["speciesCode"]
            existing = by_species.get(species_code)
            if existing is None or record["obsDt"] > existing["obsDt"]:
                by_species[species_code] = record

        most_recent_obs_dt = max(record["obsDt"] for record in group["records"])

        top_species = sorted(
            by_species.values(),
            key=lambda entry: (entry["count"] is None, -(entry["count"] or 0)),
        )[:_TOP_SPECIES_N]

        loc_name = group["locName"]
        if group["locationPrivate"]:
            loc_name = _clean_personal_locname(loc_name)

        results.append(
            {
                "locId": group["locId"],
                "locName": loc_name,
                "lat": group["lat"],
                "lng": group["lng"],
                "locationPrivate": group["locationPrivate"],
                "speciesCount": len(by_species),
                "mostRecentObsDt": most_recent_obs_dt,
                "topSpecies": [
                    {
                        "nameKo": entry["nameKo"],
                        "nameSci": entry["nameSci"],
                        "speciesCode": entry["speciesCode"],
                        "count": entry["count"],
                        "obsDt": entry["obsDt"],
                    }
                    for entry in top_species
                ],
            }
        )

    hotspot_results = [result for result in results if not result["locationPrivate"]]
    private_results = [result for result in results if result["locationPrivate"]]
    return (hotspot_results + private_results)[:_MAX_LOCATIONS]


def fetch_recent_obs(
    lat: float,
    lng: float,
    client: httpx.Client | None = None,
    dist: int = 25,
    back: int = 14,
    max_results: int = 100,
) -> list[dict]:
    config = get_observation_config()
    if not config.ebird_token or not config.ebird_base_url:
        return []

    owns_client = client is None
    if client is None:
        client = httpx.Client(timeout=10.0)
    try:
        response = client.get(
            f"{config.ebird_base_url}/data/obs/geo/recent",
            headers={"X-eBirdApiToken": config.ebird_token},
            params={
                "lat": lat,
                "lng": lng,
                "dist": dist,
                "back": back,
                "maxResults": max_results,
                "sppLocale": "ko",
            },
        )
        response.raise_for_status()
        return parse_recent_obs(response.json())
    except Exception:
        return []
    finally:
        if owns_client:
            client.close()
