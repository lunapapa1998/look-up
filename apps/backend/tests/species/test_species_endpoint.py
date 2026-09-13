from __future__ import annotations

import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.species.service import SpeciesService, get_species_service

client = TestClient(app)


class FakeSpeciesService:
    def __init__(self, response: dict) -> None:
        self._response = response

    def get_species(self, sci: str | None, ko: str | None) -> dict:
        return self._response


def _install(service: SpeciesService) -> None:
    app.dependency_overrides[get_species_service] = lambda: service


@pytest.fixture(autouse=True)
def fresh_species_service():
    _install(
        FakeSpeciesService(
            {
                "nameKo": "저어새",
                "nameSci": "Platalea minor",
                "summary": "저어새는 저어새과에 속하는 새이다.",
                "thumbnailUrl": "https://example.com/thumb.jpg",
                "wikiUrl": "https://ko.wikipedia.org/wiki/저어새",
                "source": "ko.wikipedia",
            }
        )
    )
    yield
    app.dependency_overrides.clear()


def test_happy_path_returns_full_contract() -> None:
    response = client.get("/api/species", params={"ko": "저어새"})
    assert response.status_code == 200
    body = response.json()

    assert set(body) == {
        "nameKo",
        "nameSci",
        "summary",
        "thumbnailUrl",
        "wikiUrl",
        "source",
    }
    assert body["source"] == "ko.wikipedia"


def test_no_result_returns_200_not_404() -> None:
    _install(
        FakeSpeciesService(
            {
                "nameKo": "없는새",
                "nameSci": None,
                "summary": None,
                "thumbnailUrl": None,
                "wikiUrl": None,
                "source": "none",
            }
        )
    )

    response = client.get("/api/species", params={"ko": "없는새"})
    assert response.status_code == 200
    body = response.json()
    assert body["source"] == "none"
    assert body["summary"] is None


def test_missing_both_sci_and_ko_returns_422() -> None:
    response = client.get("/api/species")
    assert response.status_code == 422
