from __future__ import annotations

from app.models import Badge, BadgeProgress, Observation, SpeciesType

_BADGES: list[Badge] = [
    Badge(id="first_step", name="첫 관찰", description="첫 관찰 기록을 남겼어요", targetCount=1),
    Badge(id="explorer", name="탐험가", description="총 5개의 관찰을 기록했어요", targetCount=5),
    Badge(id="master", name="관찰 마스터", description="총 20개의 관찰을 기록했어요", targetCount=20),
    Badge(id="bird_watcher", name="새 관찰자", description="새(bird) 관찰을 5회 기록했어요", targetCount=5),
    Badge(id="star_gazer", name="별 관찰자", description="별(star) 관찰을 5회 기록했어요", targetCount=5),
]


def derive_badges(observations: list[Observation]) -> list[BadgeProgress]:
    total = len(observations)
    bird_count = sum(1 for o in observations if o.speciesType == SpeciesType.BIRD)
    star_count = sum(1 for o in observations if o.speciesType == SpeciesType.STAR)

    counts = {
        "first_step": total,
        "explorer": total,
        "master": total,
        "bird_watcher": bird_count,
        "star_gazer": star_count,
    }

    return [
        BadgeProgress(
            badge=badge,
            achieved=counts[badge.id] >= badge.targetCount,
            currentCount=counts[badge.id],
        )
        for badge in _BADGES
    ]
