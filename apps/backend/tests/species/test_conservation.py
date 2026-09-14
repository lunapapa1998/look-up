from __future__ import annotations

from app.species.conservation import lookup_conservation
from app.species.service import SpeciesService


def test_known_species_returns_exact_seed_values() -> None:
    result = lookup_conservation("Platalea minor", "저어새")

    assert result == {
        "naturalMonument": "천연기념물 제205-1호",
        "koreaEndangered": "멸종위기 I급",
        "iucn": "EN",
    }


def test_unknown_species_returns_none() -> None:
    result = lookup_conservation("Corvus corax", "큰까마귀")

    assert result is None


def test_case_and_whitespace_insensitive_sci_name_still_matches() -> None:
    result = lookup_conservation("  PLATALEA MINOR  ", None)

    assert result == {
        "naturalMonument": "천연기념물 제205-1호",
        "koreaEndangered": "멸종위기 I급",
        "iucn": "EN",
    }


def test_partial_field_species_has_null_natural_monument() -> None:
    result = lookup_conservation("Numenius madagascariensis", "알락꼬리마도요")

    assert result == {
        "naturalMonument": None,
        "koreaEndangered": "멸종위기 II급",
        "iucn": "EN",
    }


def test_service_populates_conservation_for_known_species() -> None:
    service = SpeciesService(
        fetch_species_summary=lambda ko, sci: {
            "summary": "저어새는 저어새과에 속하는 새이다.",
            "thumbnailUrl": "https://example.com/thumb.jpg",
            "wikiUrl": "https://ko.wikipedia.org/wiki/저어새",
            "source": "ko.wikipedia",
        },
        fetch_species_extract=lambda ko, sci: None,
    )

    response = service.get_species("Platalea minor", "저어새")

    assert response["conservation"] == {
        "naturalMonument": "천연기념물 제205-1호",
        "koreaEndangered": "멸종위기 I급",
        "iucn": "EN",
    }


def test_service_returns_none_conservation_for_unknown_species() -> None:
    service = SpeciesService(
        fetch_species_summary=lambda ko, sci: None,
        fetch_species_extract=lambda ko, sci: None,
    )

    response = service.get_species("Corvus corax", "큰까마귀")

    assert response["conservation"] is None
