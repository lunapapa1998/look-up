from __future__ import annotations

from app.observation import ebird
from app.observation.ebird import aggregate_by_location
from app.suitability.providers.light_pollution import LightPollutionProvider
from app.trails import tourapi

DEFAULT_REGION_LABEL = "인천 강화군"

OBS_STAR_ID = "star:ganghwa-astro"
OBS_STAR_NAME = "강화 천문인마을"
OBS_STAR_LAT = 37.7378
OBS_STAR_LNG = 126.4708


class ObservationMapService:
    def __init__(
        self,
        fetch_recent_obs=None,
        light_pollution_provider=None,
        fetch_nearby_food=None,
    ):
        self.fetch_recent_obs = fetch_recent_obs or ebird.fetch_recent_obs
        self.light_pollution_provider = light_pollution_provider or LightPollutionProvider()
        self.fetch_nearby_food = fetch_nearby_food or tourapi.fetch_nearby_food

    def get_observation_map(self, lat: float, lng: float) -> dict:
        try:
            raw = self.fetch_recent_obs(lat, lng)
            if not raw:
                bird_spots = []
            else:
                locations = aggregate_by_location(raw)
                bird_spots = [
                    {
                        "id": f"bird:{location['locId']}",
                        "kind": "bird",
                        "name": location["locName"],
                        "coord": {"lat": location["lat"], "lng": location["lng"]},
                        "birds": {
                            "speciesCount": location["speciesCount"],
                            "topSpecies": location["topSpecies"],
                            "mostRecentObsDt": location["mostRecentObsDt"],
                            "status": "community",
                        },
                        "nightSky": None,
                        "heritage": None,
                    }
                    for location in locations
                ]
        except Exception:
            bird_spots = []

        try:
            reading = self.light_pollution_provider.fetch(OBS_STAR_LAT, OBS_STAR_LNG, "night")
            star_spot = {
                "id": OBS_STAR_ID,
                "kind": "star",
                "name": OBS_STAR_NAME,
                "coord": {"lat": OBS_STAR_LAT, "lng": OBS_STAR_LNG},
                "nightSky": {
                    "sqmValue": reading.evidence["sqmValue"],
                    "bortleClass": reading.evidence["bortleClass"],
                    "skyClass": reading.evidence["skyClass"],
                    "status": reading.status,
                },
                "birds": None,
                "heritage": None,
            }
        except Exception:
            star_spot = None

        try:
            foods = self.fetch_nearby_food(lat, lng)
            heritage_spots = [
                {
                    "id": f"heritage:{food['contentId']}",
                    "kind": "heritage",
                    "name": food["name"],
                    "coord": {"lat": food["lat"], "lng": food["lng"]},
                    "heritage": {
                        "addr": food["addr"],
                        "distanceM": food["distanceM"],
                        "contentId": food["contentId"],
                    },
                    "birds": None,
                    "nightSky": None,
                }
                for food in (foods or [])
            ]
        except Exception:
            heritage_spots = []

        spots = bird_spots + ([star_spot] if star_spot else []) + heritage_spots
        degraded = len(spots) == 0

        return {"region": DEFAULT_REGION_LABEL, "degraded": degraded, "spots": spots}


def get_default_observation_map_service() -> ObservationMapService:
    return ObservationMapService()


_default_observation_map_service = get_default_observation_map_service()


def get_observation_map_service() -> ObservationMapService:
    return _default_observation_map_service
