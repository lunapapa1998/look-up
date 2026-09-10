from __future__ import annotations

import httpx

from app.suitability.config import get_observation_config

_TOP_SPECIES_N = 5


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

        results.append(
            {
                "locId": group["locId"],
                "locName": group["locName"],
                "lat": group["lat"],
                "lng": group["lng"],
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
    return results


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
