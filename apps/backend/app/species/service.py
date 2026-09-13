from __future__ import annotations

from app.species import wikipedia


class SpeciesService:
    def __init__(self, fetch_species_summary=None):
        self.fetch_species_summary = fetch_species_summary or wikipedia.fetch_species_summary

    def get_species(self, sci: str | None, ko: str | None) -> dict:
        result = self.fetch_species_summary(ko, sci)
        if result is None:
            return {
                "nameKo": ko,
                "nameSci": sci,
                "summary": None,
                "thumbnailUrl": None,
                "wikiUrl": None,
                "source": "none",
            }

        return {
            "nameKo": ko,
            "nameSci": sci,
            "summary": result["summary"],
            "thumbnailUrl": result["thumbnailUrl"],
            "wikiUrl": result["wikiUrl"],
            "source": result["source"],
        }


def get_default_species_service() -> SpeciesService:
    return SpeciesService()


_default_species_service = get_default_species_service()


def get_species_service() -> SpeciesService:
    return _default_species_service
