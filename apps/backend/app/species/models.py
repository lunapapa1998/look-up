from __future__ import annotations

from pydantic import BaseModel


class Conservation(BaseModel):
    naturalMonument: str | None
    koreaEndangered: str | None
    iucn: str | None


class SpeciesInfo(BaseModel):
    nameKo: str | None
    nameSci: str | None
    summary: str | None
    thumbnailUrl: str | None
    wikiUrl: str | None
    source: str
    summaryLong: str | None = None
    conservation: Conservation | None = None
