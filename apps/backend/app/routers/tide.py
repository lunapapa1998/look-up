from __future__ import annotations

from fastapi import APIRouter, Depends, Query

from app.species.tide_today import TideTodayResponse, fetch_today_tides

router = APIRouter(prefix="/api/tide", tags=["tide"])


def get_today_tides_fetcher():
    return fetch_today_tides


@router.get("/today", response_model=TideTodayResponse)
def get_tide_today(
    lat: float = Query(...),
    lng: float = Query(...),
    fetcher=Depends(get_today_tides_fetcher),
) -> dict:
    return fetcher(lat, lng)
