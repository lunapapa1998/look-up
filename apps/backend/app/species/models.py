from __future__ import annotations

from pydantic import BaseModel


class SpeciesInfo(BaseModel):
    nameKo: str | None
    nameSci: str | None
    summary: str | None
    thumbnailUrl: str | None
    wikiUrl: str | None
    source: str
