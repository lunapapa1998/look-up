from __future__ import annotations

from fastapi import APIRouter, Depends, Query

from app.suitability.models import ObsMode, SuitabilityResponse
from app.suitability.service import SuitabilityService, get_suitability_service

router = APIRouter(prefix="/api/suitability", tags=["suitability"])


@router.get("", response_model=SuitabilityResponse)
def get_suitability(
    mode: ObsMode,
    lat: float = Query(..., ge=-90, le=90),
    lng: float = Query(..., ge=-180, le=180),
    service: SuitabilityService = Depends(get_suitability_service),
) -> SuitabilityResponse:
    return service.get_suitability(lat, lng, mode.value)
