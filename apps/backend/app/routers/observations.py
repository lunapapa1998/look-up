from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Response

from app.models import Observation, ObservationCreate, ObservationUpdate, SpeciesType
from app.repository import ObservationRepository, get_repository

router = APIRouter(prefix="/api/observations", tags=["observations"])


@router.post("", response_model=Observation, status_code=201)
def create_observation(
    data: ObservationCreate,
    repo: ObservationRepository = Depends(get_repository),
) -> Observation:
    return repo.create(data)


@router.get("", response_model=list[Observation])
def list_observations(
    speciesType: SpeciesType | None = None,
    repo: ObservationRepository = Depends(get_repository),
) -> list[Observation]:
    return repo.list(speciesType)


@router.get("/{observation_id}", response_model=Observation)
def get_observation(
    observation_id: int,
    repo: ObservationRepository = Depends(get_repository),
) -> Observation:
    observation = repo.get(observation_id)
    if observation is None:
        raise HTTPException(404, detail=f"Observation {observation_id} not found")
    return observation


@router.patch("/{observation_id}", response_model=Observation)
def update_observation(
    observation_id: int,
    data: ObservationUpdate,
    repo: ObservationRepository = Depends(get_repository),
) -> Observation:
    updated = repo.update(observation_id, data)
    if updated is None:
        raise HTTPException(404, detail=f"Observation {observation_id} not found")
    return updated


@router.delete("/{observation_id}", status_code=204)
def delete_observation(
    observation_id: int,
    repo: ObservationRepository = Depends(get_repository),
) -> Response:
    if repo.delete(observation_id) is False:
        raise HTTPException(404, detail=f"Observation {observation_id} not found")
    return Response(status_code=204)
