from __future__ import annotations

from datetime import datetime
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query

from app.starlight.models import StarlightForecastResponse
from app.starlight.service import StarlightForecastService, get_starlight_service

router = APIRouter(prefix="/api/starlight-forecast", tags=["starlight"])


@router.get("", response_model=StarlightForecastResponse)
def get_starlight_forecast(
    lat: float = Query(..., ge=-90, le=90, description="Latitude"),
    lng: float = Query(..., ge=-180, le=180, description="Longitude"),
    date_str: Optional[str] = Query(None, alias="date", description="Target date (YYYY-MM-DD)"),
    time_str: Optional[str] = Query(None, alias="time", description="Target time (HH:MM)"),
    target_id: Optional[str] = Query(None, alias="target", description="Target celestial ID"),
    sqm: Optional[float] = Query(None, description="Override SQM value"),
    moon_illumination: Optional[int] = Query(None, ge=0, le=100, description="Override moon illumination pct"),
    twilight_end: Optional[str] = Query(None, description="Override twilight end time (HH:MM)"),
    service: StarlightForecastService = Depends(get_starlight_service),
) -> StarlightForecastResponse:
    target_date = None
    if date_str:
        try:
            target_date = datetime.strptime(date_str, "%Y-%m-%d").date()
        except ValueError:
            raise HTTPException(status_code=400, detail="Invalid date format, expected YYYY-MM-DD")

    return service.generate_forecast(
        lat=lat,
        lng=lng,
        target_date=target_date,
        target_time=time_str,
        target_id=target_id,
        override_sqm=sqm,
        override_moon_illumination=moon_illumination,
        override_twilight_end=twilight_end,
    )
