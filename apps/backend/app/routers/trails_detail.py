from __future__ import annotations

from fastapi import APIRouter, Depends, Query

from app.trails.durunubi_detail import fetch_course_detail
from app.trails.models import TrailDetailResponse

router = APIRouter(prefix="/api/trails", tags=["trails"])


def get_course_detail_fetcher():
    return fetch_course_detail


@router.get("/detail", response_model=TrailDetailResponse)
def get_trail_detail(
    crsIdx: str = Query(..., min_length=1),
    fetcher=Depends(get_course_detail_fetcher),
) -> dict:
    return fetcher(crsIdx)
