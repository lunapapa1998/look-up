from __future__ import annotations

import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.repository import InMemoryObservationRepository, get_repository

client = TestClient(app)


@pytest.fixture(autouse=True)
def fresh_repository():
    fresh_repo = InMemoryObservationRepository()
    app.dependency_overrides[get_repository] = lambda: fresh_repo
    yield fresh_repo
    app.dependency_overrides.clear()


def _valid_payload(**overrides: object) -> dict:
    payload = {
        "speciesType": "bird",
        "speciesName": "까치",
    }
    payload.update(overrides)
    return payload


def test_create_observation_returns_201_with_populated_fields() -> None:
    response = client.post("/api/observations", json=_valid_payload())
    assert response.status_code == 201
    body = response.json()
    assert body["id"] is not None
    assert body["createdAt"] is not None
    assert body["observedAt"] is not None


def test_create_observation_missing_species_name_returns_422() -> None:
    payload = _valid_payload()
    del payload["speciesName"]
    response = client.post("/api/observations", json=payload)
    assert response.status_code == 422


def test_create_observation_invalid_species_type_returns_422() -> None:
    response = client.post("/api/observations", json=_valid_payload(speciesType="fish"))
    assert response.status_code == 422


def test_create_observation_without_observed_at_defaults_server_side() -> None:
    response = client.post("/api/observations", json=_valid_payload())
    assert response.status_code == 201
    assert response.json()["observedAt"] is not None


def test_list_observations_returns_created_items() -> None:
    client.post("/api/observations", json=_valid_payload())
    client.post("/api/observations", json=_valid_payload(speciesName="참새"))
    response = client.get("/api/observations")
    assert response.status_code == 200
    assert len(response.json()) == 2


def test_list_observations_filters_by_species_type() -> None:
    client.post("/api/observations", json=_valid_payload(speciesType="bird"))
    client.post("/api/observations", json=_valid_payload(speciesType="star", speciesName="북극성"))
    response = client.get("/api/observations", params={"speciesType": "bird"})
    assert response.status_code == 200
    body = response.json()
    assert len(body) == 1
    assert body[0]["speciesType"] == "bird"


def test_get_observation_by_id_returns_200() -> None:
    created = client.post("/api/observations", json=_valid_payload()).json()
    response = client.get(f"/api/observations/{created['id']}")
    assert response.status_code == 200
    assert response.json()["id"] == created["id"]


def test_get_observation_missing_id_returns_404_with_detail() -> None:
    response = client.get("/api/observations/999")
    assert response.status_code == 404
    assert "detail" in response.json()


def test_patch_observation_partial_update_keeps_other_fields() -> None:
    created = client.post("/api/observations", json=_valid_payload()).json()
    response = client.patch(f"/api/observations/{created['id']}", json={"note": "둥지 발견"})
    assert response.status_code == 200
    body = response.json()
    assert body["note"] == "둥지 발견"
    assert body["speciesName"] == created["speciesName"]
    assert body["speciesType"] == created["speciesType"]


def test_patch_observation_null_species_name_returns_422() -> None:
    created = client.post("/api/observations", json=_valid_payload()).json()
    response = client.patch(f"/api/observations/{created['id']}", json={"speciesName": None})
    assert response.status_code == 422


def test_patch_observation_null_species_type_returns_422() -> None:
    created = client.post("/api/observations", json=_valid_payload()).json()
    response = client.patch(f"/api/observations/{created['id']}", json={"speciesType": None})
    assert response.status_code == 422


def test_patch_observation_null_observed_at_returns_422() -> None:
    created = client.post("/api/observations", json=_valid_payload()).json()
    response = client.patch(f"/api/observations/{created['id']}", json={"observedAt": None})
    assert response.status_code == 422


def test_patch_observation_missing_id_returns_404() -> None:
    response = client.patch("/api/observations/999", json={"note": "x"})
    assert response.status_code == 404


def test_delete_observation_then_get_returns_404() -> None:
    created = client.post("/api/observations", json=_valid_payload()).json()
    delete_response = client.delete(f"/api/observations/{created['id']}")
    assert delete_response.status_code == 204
    get_response = client.get(f"/api/observations/{created['id']}")
    assert get_response.status_code == 404


def test_delete_observation_missing_id_returns_404() -> None:
    response = client.delete("/api/observations/999")
    assert response.status_code == 404


def test_badges_endpoint_returns_progress_for_all_badges() -> None:
    client.post("/api/observations", json=_valid_payload(speciesType="bird"))
    client.post("/api/observations", json=_valid_payload(speciesType="star", speciesName="북극성"))
    response = client.get("/api/badges")
    assert response.status_code == 200
    body = response.json()
    assert len(body) == 5
    first_step = next(b for b in body if b["badge"]["id"] == "first_step")
    assert first_step["achieved"] is True
    assert first_step["currentCount"] == 2
