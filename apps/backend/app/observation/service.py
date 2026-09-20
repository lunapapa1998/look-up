from __future__ import annotations

from app.observation import ebird
from app.observation.ebird import aggregate_by_location
from app.regions import registry
from app.suitability.providers.light_pollution import LightPollutionProvider
from app.trails import tourapi


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

    def get_observation_map(self, lat: float, lng: float, region_id: str | None = None) -> dict:
        region = registry.get(region_id) if region_id else None
        if region is None:
            region = registry.nearest(lat, lng)

        try:
            raw = self.fetch_recent_obs(region.center_lat, region.center_lng)
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

        if region.star_spot is None:
            star_spot = None
        else:
            try:
                star_lat = region.star_spot["lat"]
                star_lng = region.star_spot["lng"]
                reading = self.light_pollution_provider.fetch(star_lat, star_lng, "night")
                star_spot = {
                    "id": region.star_spot["id"],
                    "kind": "star",
                    "name": region.star_spot["name"],
                    "coord": {"lat": star_lat, "lng": star_lng},
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
            foods = self.fetch_nearby_food(region.center_lat, region.center_lng)
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

        return {"region": region.label, "degraded": degraded, "spots": spots}


def get_default_observation_map_service() -> ObservationMapService:
    return ObservationMapService()


_default_observation_map_service = get_default_observation_map_service()


def get_observation_map_service() -> ObservationMapService:
    return _default_observation_map_service
