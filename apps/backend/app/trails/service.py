from __future__ import annotations

import re

from app.suitability.providers.light_pollution import LightPollutionProvider
from app.suitability.service import get_suitability_service
from app.trails import durunubi, tourapi


def _normalize(text: str) -> str:
    return re.sub(r"\s+", " ", text.strip().lower())


def match_region(place_tokens: list[str], courses: list[dict]) -> list[dict]:
    normalized_tokens = [_normalize(token) for token in place_tokens]

    matched = []
    for course in courses:
        normalized_sigun = _normalize(course["sigun"])
        if any(token in normalized_sigun for token in normalized_tokens):
            matched.append(course)
    return matched


DEFAULT_REGION_LABEL = "인천 강화군"
DEFAULT_REGION_TOKENS = ["강화"]
TOP_K = 5
CANDIDATE_LIMIT = 15


class TrailsService:
    def __init__(
        self,
        fetch_courses=None,
        fetch_gpx_endpoints=None,
        fetch_nearby_food=None,
        light_pollution_provider=None,
        suitability_service=None,
    ):
        self.fetch_courses = fetch_courses or durunubi.fetch_courses
        self.fetch_gpx_endpoints = fetch_gpx_endpoints or durunubi.fetch_gpx_endpoints
        self.fetch_nearby_food = fetch_nearby_food or tourapi.fetch_nearby_food
        self.light_pollution_provider = light_pollution_provider or LightPollutionProvider()
        self.suitability_service = suitability_service or get_suitability_service()

    def get_trails(self, lat: float, lng: float) -> dict:
        all_courses = self.fetch_courses()
        if not all_courses:
            return {"region": DEFAULT_REGION_LABEL, "degraded": True, "courses": []}

        matched = match_region(DEFAULT_REGION_TOKENS, all_courses)
        if not matched:
            return {"region": DEFAULT_REGION_LABEL, "degraded": True, "courses": []}

        candidates = sorted(matched, key=lambda course: course["crsIdx"])[:CANDIDATE_LIMIT]

        ranked: list[dict] = []
        for candidate in candidates:
            endpoints = self.fetch_gpx_endpoints(candidate["gpxUrl"])
            if endpoints is None:
                continue
            start, end = endpoints
            try:
                reading = self.light_pollution_provider.fetch(end["lat"], end["lng"], "night")
            except Exception:
                continue
            night_sky = {
                "sqmValue": reading.evidence["sqmValue"],
                "bortleClass": reading.evidence["bortleClass"],
                "skyClass": reading.evidence["skyClass"],
                "status": reading.status,
            }
            ranked.append(
                {
                    "crsIdx": candidate["crsIdx"],
                    "name": candidate["name"],
                    "sigun": candidate["sigun"],
                    "distanceKm": candidate["distanceKm"],
                    "durationMin": candidate["durationMin"],
                    "level": candidate["level"],
                    "cycle": candidate["cycle"],
                    "gpxUrl": candidate["gpxUrl"],
                    "start": start,
                    "end": end,
                    "nightSky": night_sky,
                    "heritageEats": [],
                    "daySuitability": None,
                    "nightSuitability": None,
                }
            )

        ranked.sort(
            key=lambda course: (
                -course["nightSky"]["sqmValue"],
                course["distanceKm"],
                course["crsIdx"],
            )
        )

        top = ranked[:TOP_K]

        for index, course in enumerate(top):
            end = course["end"]
            try:
                course["heritageEats"] = self.fetch_nearby_food(end["lat"], end["lng"])
            except Exception:
                course["heritageEats"] = []

            if index != 0:
                continue

            try:
                day_response = self.suitability_service.get_suitability(end["lat"], end["lng"], "day")
                course["daySuitability"] = {
                    "score": day_response.score,
                    "label": day_response.label,
                    "status": "approx" if day_response.degraded else "live",
                }
            except Exception:
                course["daySuitability"] = None

            try:
                night_response = self.suitability_service.get_suitability(end["lat"], end["lng"], "night")
                course["nightSuitability"] = {
                    "score": night_response.score,
                    "label": night_response.label,
                    "status": "approx" if night_response.degraded else "live",
                }
            except Exception:
                course["nightSuitability"] = None

        return {"region": DEFAULT_REGION_LABEL, "degraded": False, "courses": top}


def get_default_trails_service() -> TrailsService:
    return TrailsService()


_default_trails_service = get_default_trails_service()


def get_trails_service() -> TrailsService:
    return _default_trails_service
