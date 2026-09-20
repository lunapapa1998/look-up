from __future__ import annotations

from fastapi import APIRouter, Depends, Query

from app.trails.models import TrailsResponse
from app.trails.service import TrailsService, get_trails_service

router = APIRouter(prefix="/api/trails", tags=["trails"])


@router.get("", response_model=TrailsResponse)
def get_trails(
    lat: float = Query(..., ge=-90, le=90),
    lng: float = Query(..., ge=-180, le=180),
    region: str | None = Query(None),
    service: TrailsService = Depends(get_trails_service),
) -> dict:
    return service.get_trails(lat, lng, region_id=region)
