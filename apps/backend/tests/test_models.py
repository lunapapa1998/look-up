from datetime import UTC, datetime

import pytest
from pydantic import ValidationError

from app.models import Observation, ObservationCreate, ObservationUpdate, SpeciesType


def test_observation_create_valid():
    data = ObservationCreate(speciesType=SpeciesType.BIRD, speciesName="참새")
    assert data.speciesType == SpeciesType.BIRD
    assert data.speciesName == "참새"
    assert data.note is None
    assert data.photoUrl is None
    assert data.observedAt is None
    assert data.lat is None
    assert data.lng is None


def test_observation_create_invalid_species_type():
    with pytest.raises(ValidationError):
        ObservationCreate(speciesType="dog", speciesName="참새")


def test_observation_create_empty_species_name():
    with pytest.raises(ValidationError):
        ObservationCreate(speciesType=SpeciesType.BIRD, speciesName="")


def test_observation_create_missing_required_fields():
    with pytest.raises(ValidationError):
        ObservationCreate(speciesName="참새")


def test_observation_update_accepts_empty_payload():
    update = ObservationUpdate()
    assert update.speciesType is None
    assert update.speciesName is None
    assert update.note is None
    assert update.photoUrl is None
    assert update.observedAt is None
    assert update.lat is None
    assert update.lng is None


def test_observation_update_invalid_species_type():
    with pytest.raises(ValidationError):
        ObservationUpdate(speciesType="dog")


def test_observation_update_partial_payload():
    update = ObservationUpdate(note="업데이트된 메모")
    assert update.model_dump(exclude_unset=True) == {"note": "업데이트된 메모"}


def test_observation_update_rejects_null_species_name():
    with pytest.raises(ValidationError):
        ObservationUpdate(speciesName=None)


def test_observation_update_rejects_null_species_type():
    with pytest.raises(ValidationError):
        ObservationUpdate(speciesType=None)


def test_observation_full_model():
    now = datetime.now(UTC)
    observation = Observation(
        id=1,
        speciesType=SpeciesType.STAR,
        speciesName="북극성",
        observedAt=now,
        createdAt=now,
    )
    assert observation.id == 1
    assert observation.speciesType == SpeciesType.STAR
    assert observation.note is None


def test_observation_missing_required_field_raises():
    with pytest.raises(ValidationError):
        Observation(
            id=1,
            speciesType=SpeciesType.STAR,
            speciesName="북극성",
        )
