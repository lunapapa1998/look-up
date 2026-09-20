from __future__ import annotations

from fastapi import APIRouter, Query

from app.regions import registry
from app.regions.models import RegionsResponse

router = APIRouter(prefix="/api/regions", tags=["regions"])


@router.get("", response_model=RegionsResponse)
def get_regions(
    lat: float = Query(..., ge=-90, le=90),
    lng: float = Query(..., ge=-180, le=180),
) -> dict:
    pairs = registry.sort_by_distance(lat, lng)
    regions = [
        {
            "id": region.id,
            "label": region.label,
            "distanceKm": round(distance, 1),
            "center": {"lat": region.center_lat, "lng": region.center_lng},
            "hasStarSpot": region.star_spot is not None,
        }
        for region, distance in pairs
    ]
    return {"nearestId": pairs[0][0].id, "regions": regions}
