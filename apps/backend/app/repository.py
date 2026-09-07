from __future__ import annotations

from datetime import UTC, datetime
from typing import Protocol

from app.models import Observation, ObservationCreate, ObservationUpdate, SpeciesType


class ObservationRepository(Protocol):
    def list(self, species_type: SpeciesType | None = None) -> list[Observation]: ...

    def get(self, observation_id: int) -> Observation | None: ...

    def create(self, data: ObservationCreate) -> Observation: ...

    def update(self, observation_id: int, data: ObservationUpdate) -> Observation | None: ...

    def delete(self, observation_id: int) -> bool: ...


class InMemoryObservationRepository:
    def __init__(self) -> None:
        self._observations: dict[int, Observation] = {}
        self._next_id: int = 1

    def list(self, species_type: SpeciesType | None = None) -> list[Observation]:
        observations = list(self._observations.values())
        if species_type is None:
            return observations
        return [o for o in observations if o.speciesType == species_type]

    def get(self, observation_id: int) -> Observation | None:
        return self._observations.get(observation_id)

    def create(self, data: ObservationCreate) -> Observation:
        now = datetime.now(UTC)
        observation = Observation(
            id=self._next_id,
            speciesType=data.speciesType,
            speciesName=data.speciesName,
            note=data.note,
            photoUrl=data.photoUrl,
            observedAt=data.observedAt if data.observedAt is not None else now,
            lat=data.lat,
            lng=data.lng,
            createdAt=now,
        )
        self._observations[observation.id] = observation
        self._next_id += 1
        return observation

    def update(self, observation_id: int, data: ObservationUpdate) -> Observation | None:
        existing = self._observations.get(observation_id)
        if existing is None:
            return None
        updated = existing.model_copy(update=data.model_dump(exclude_unset=True))
        self._observations[observation_id] = updated
        return updated

    def delete(self, observation_id: int) -> bool:
        if observation_id not in self._observations:
            return False
        del self._observations[observation_id]
        return True


_default_repository = InMemoryObservationRepository()


def get_repository() -> ObservationRepository:
    return _default_repository
