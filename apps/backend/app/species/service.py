from __future__ import annotations

from app.species import conservation, wikipedia


class SpeciesService:
    def __init__(self, fetch_species_summary=None, fetch_species_extract=None):
        self.fetch_species_summary = fetch_species_summary or wikipedia.fetch_species_summary
        self.fetch_species_extract = fetch_species_extract or wikipedia.fetch_species_extract

    def get_species(self, sci: str | None, ko: str | None) -> dict:
        result = self.fetch_species_summary(ko, sci)

        summary_long = None
        try:
            summary_long = self.fetch_species_extract(ko, sci)
        except Exception:
            summary_long = None

        conservation_info = conservation.lookup_conservation(sci, ko)
        if conservation_info is not None and not any(conservation_info.values()):
            conservation_info = None

        if result is None:
            return {
                "nameKo": ko,
                "nameSci": sci,
                "summary": None,
                "thumbnailUrl": None,
                "wikiUrl": None,
                "source": "none",
                "summaryLong": summary_long,
                "conservation": conservation_info,
            }

        return {
            "nameKo": ko,
            "nameSci": sci,
            "summary": result["summary"],
            "thumbnailUrl": result["thumbnailUrl"],
            "wikiUrl": result["wikiUrl"],
            "source": result["source"],
            "summaryLong": summary_long,
            "conservation": conservation_info,
        }


def get_default_species_service() -> SpeciesService:
    return SpeciesService()


_default_species_service = get_default_species_service()


def get_species_service() -> SpeciesService:
    return _default_species_service
