from __future__ import annotations

import pytest

import httpx

from app.species.wikipedia import fetch_species_summary, parse_summary_response


def test_parse_summary_response_returns_expected_dict() -> None:
    payload = {
        "title": "저어새",
        "extract": "저어새는 저어새과에 속하는 새이다.",
        "thumbnail": {"source": "https://example.com/thumb.jpg"},
        "content_urls": {"desktop": {"page": "https://ko.wikipedia.org/wiki/저어새"}},
    }

    result = parse_summary_response(payload, source="ko.wikipedia")

    assert result == {
        "title": "저어새",
        "summary": "저어새는 저어새과에 속하는 새이다.",
        "thumbnailUrl": "https://example.com/thumb.jpg",
        "wikiUrl": "https://ko.wikipedia.org/wiki/저어새",
        "source": "ko.wikipedia",
    }


def test_parse_summary_response_missing_thumbnail_and_content_urls_defaults_to_none() -> None:
    payload = {"title": "저어새", "extract": "설명"}

    result = parse_summary_response(payload, source="ko.wikipedia")

    assert result["thumbnailUrl"] is None
    assert result["wikiUrl"] is None


def test_parse_summary_response_disambiguation_raises_value_error() -> None:
    payload = {"type": "disambiguation", "title": "저어새"}

    with pytest.raises(ValueError):
        parse_summary_response(payload, source="ko.wikipedia")


def _mock_client(routes: dict[str, tuple[int, dict]]) -> httpx.Client:
    def handler(request: httpx.Request) -> httpx.Response:
        for needle, (status, body) in routes.items():
            if needle in str(request.url):
                return httpx.Response(status, json=body)
        return httpx.Response(404, json={})

    return httpx.Client(transport=httpx.MockTransport(handler))


def test_empty_extract_on_korean_falls_back_to_english() -> None:
    # ko wiki page exists (200) but has no extract -> must fall through to en.
    client = _mock_client(
        {
            "ko.wikipedia.org": (200, {"title": "저어새", "extract": ""}),
            "en.wikipedia.org": (
                200,
                {"title": "Black-faced spoonbill", "extract": "A wading bird."},
            ),
        }
    )
    result = fetch_species_summary("저어새", "Platalea minor", client=client)

    assert result is not None
    assert result["source"] == "en.wikipedia"
    assert result["summary"] == "A wading bird."
