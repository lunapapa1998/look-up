from datetime import UTC, datetime

from app.badges import derive_badges
from app.models import Observation, SpeciesType

_EXPECTED_IDS = ["first_step", "explorer", "master", "bird_watcher", "star_gazer"]


def _make_observation(id: int, species_type: SpeciesType) -> Observation:
    now = datetime.now(UTC)
    return Observation(
        id=id,
        speciesType=species_type,
        speciesName="테스트",
        observedAt=now,
        createdAt=now,
    )


def test_derive_badges_empty_list():
    progress = derive_badges([])
    assert [p.badge.id for p in progress] == _EXPECTED_IDS
    assert all(p.achieved is False for p in progress)
    assert all(p.currentCount == 0 for p in progress)


def test_derive_badges_crosses_thresholds():
    observations = [_make_observation(i, SpeciesType.BIRD) for i in range(1, 6)]
    observations += [_make_observation(i, SpeciesType.STAR) for i in range(6, 9)]

    progress = derive_badges(observations)
    by_id = {p.badge.id: p for p in progress}

    assert [p.badge.id for p in progress] == _EXPECTED_IDS

    assert by_id["first_step"].achieved is True
    assert by_id["first_step"].currentCount == 8

    assert by_id["explorer"].achieved is True
    assert by_id["explorer"].currentCount == 8

    assert by_id["master"].achieved is False
    assert by_id["master"].currentCount == 8

    assert by_id["bird_watcher"].achieved is True
    assert by_id["bird_watcher"].currentCount == 5

    assert by_id["star_gazer"].achieved is False
    assert by_id["star_gazer"].currentCount == 3


def test_derive_badges_master_threshold():
    observations = [_make_observation(i, SpeciesType.BIRD) for i in range(1, 21)]
    progress = derive_badges(observations)
    by_id = {p.badge.id: p for p in progress}

    assert by_id["master"].achieved is True
    assert by_id["master"].currentCount == 20
    assert by_id["bird_watcher"].achieved is True
    assert by_id["bird_watcher"].currentCount == 20
    assert by_id["star_gazer"].achieved is False
    assert by_id["star_gazer"].currentCount == 0
