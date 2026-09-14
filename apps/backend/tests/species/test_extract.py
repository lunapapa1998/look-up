from __future__ import annotations

import os

import httpx
import pytest

from app.species.wikipedia import fetch_species_extract


def _mock_client(routes: dict[str, tuple[int, dict]]) -> httpx.Client:
    def handler(request: httpx.Request) -> httpx.Response:
        for needle, (status, body) in routes.items():
            if needle in str(request.url):
                return httpx.Response(status, json=body)
        return httpx.Response(404, json={})

    return httpx.Client(transport=httpx.MockTransport(handler))


def _extract_response(title: str, extract: str) -> dict:
    return {"query": {"pages": {"1": {"title": title, "extract": extract}}}}


def _missing_response() -> dict:
    return {"query": {"pages": {"-1": {"title": "없는새", "missing": ""}}}}


def test_ko_extract_hit_returns_it() -> None:
    client = _mock_client(
        {
            "ko.wikipedia.org": (200, _extract_response("저어새", "저어새는 저어새과에 속하는 새이다.")),
        }
    )

    result = fetch_species_extract("저어새", "Platalea minor", client=client)

    assert result == "저어새는 저어새과에 속하는 새이다."


def test_ko_missing_page_falls_back_to_en() -> None:
    client = _mock_client(
        {
            "ko.wikipedia.org": (200, _missing_response()),
            "en.wikipedia.org": (
                200,
                _extract_response("Black-faced spoonbill", "A wading bird."),
            ),
        }
    )

    result = fetch_species_extract("없는새", "Platalea minor", client=client)

    assert result == "A wading bird."


def test_ko_empty_extract_falls_back_to_en() -> None:
    client = _mock_client(
        {
            "ko.wikipedia.org": (200, _extract_response("저어새", "")),
            "en.wikipedia.org": (
                200,
                _extract_response("Black-faced spoonbill", "A wading bird."),
            ),
        }
    )

    result = fetch_species_extract("저어새", "Platalea minor", client=client)

    assert result == "A wading bird."


def test_both_ko_and_en_miss_returns_none() -> None:
    client = _mock_client(
        {
            "ko.wikipedia.org": (200, _missing_response()),
            "en.wikipedia.org": (200, _missing_response()),
        }
    )

    result = fetch_species_extract("없는새", "Nonexistus species", client=client)

    assert result is None


def test_long_extract_is_cut_at_last_sentence_punctuation_before_cap() -> None:
    # Build a >1500 char extract where the last sentence-ending punctuation
    # at or before index 1500 sits at index 1490, followed by filler text.
    long_extract = ("가" * 1490) + "." + ("나" * 50)
    client = _mock_client(
        {
            "ko.wikipedia.org": (200, _extract_response("저어새", long_extract)),
        }
    )

    result = fetch_species_extract("저어새", "Platalea minor", client=client)

    assert result == ("가" * 1490) + "."
    assert len(result) == 1491


def test_long_extract_with_no_punctuation_is_hard_cut_to_1500() -> None:
    long_extract = "가" * 2000
    client = _mock_client(
        {
            "ko.wikipedia.org": (200, _extract_response("저어새", long_extract)),
        }
    )

    result = fetch_species_extract("저어새", "Platalea minor", client=client)

    assert result == "가" * 1500
    assert len(result) == 1500


def test_long_extract_with_punctuation_exactly_at_cap_boundary_stays_within_limit() -> None:
    # Sentence-ending punctuation sits at index 1500 (the 1501st character).
    # A truncation window that includes index 1500 would return 1501 chars.
    long_extract = ("가" * 1500) + "." + ("나" * 50)
    client = _mock_client(
        {
            "ko.wikipedia.org": (200, _extract_response("저어새", long_extract)),
        }
    )

    result = fetch_species_extract("저어새", "Platalea minor", client=client)

    assert result is not None
    assert len(result) <= 1500


pytestmark_live = pytest.mark.skipif(
    os.getenv("RUN_LIVE_TESTS") != "1",
    reason=(
        "live test -- set the RUN_LIVE_TESTS environment variable to the "
        "value 1 and pass the -m live selector to run against the real wikipedia API"
    ),
)


@pytestmark_live
@pytest.mark.live
def test_fetch_species_extract_live_fetch() -> None:
    result = fetch_species_extract(name_ko="저어새", sci_name="Platalea minor")

    assert result is not None
    assert len(result) > 100
