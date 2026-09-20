from __future__ import annotations

from fastapi import APIRouter, Depends, Query

from app.observation.models import ObservationMapResponse
from app.observation.service import ObservationMapService, get_observation_map_service

router = APIRouter(prefix="/api/observation-map", tags=["observation-map"])


@router.get("", response_model=ObservationMapResponse)
def get_observation_map(
    lat: float = Query(..., ge=-90, le=90),
    lng: float = Query(..., ge=-180, le=180),
    region: str | None = Query(None),
    service: ObservationMapService = Depends(get_observation_map_service),
) -> dict:
    return service.get_observation_map(lat, lng, region_id=region)
