from __future__ import annotations

from fastapi import APIRouter, Depends

from app.badges import derive_badges
from app.models import BadgeProgress
from app.repository import ObservationRepository, get_repository

router = APIRouter(prefix="/api/badges", tags=["badges"])


@router.get("", response_model=list[BadgeProgress])
def list_badges(
    repo: ObservationRepository = Depends(get_repository),
) -> list[BadgeProgress]:
    return derive_badges(repo.list())
