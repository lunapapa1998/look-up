from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query

from app.species.models import SpeciesInfo
from app.species.service import SpeciesService, get_species_service

router = APIRouter(prefix="/api/species", tags=["species"])


@router.get("", response_model=SpeciesInfo)
def get_species(
    sci: str | None = Query(None),
    ko: str | None = Query(None),
    service: SpeciesService = Depends(get_species_service),
) -> dict:
    if sci is None and ko is None:
        raise HTTPException(status_code=422, detail="either sci or ko query param is required")
    return service.get_species(sci, ko)
