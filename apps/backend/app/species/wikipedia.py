from __future__ import annotations

import urllib.parse

import httpx

from app.suitability.config import get_wikipedia_config

# Wikipedia REST API rejects requests without a descriptive User-Agent (403).
# https://www.mediawiki.org/wiki/API:Etiquette#The_User-Agent_header
_USER_AGENT = "LookUpApp/1.0 (https://github.com/lookup; contact via app)"


def parse_summary_response(payload: dict, source: str) -> dict:
    if payload.get("type") == "disambiguation":
        raise ValueError("disambiguation page, not a species summary")

    return {
        "title": payload["title"],
        "summary": payload.get("extract") or None,
        "thumbnailUrl": (payload.get("thumbnail") or {}).get("source"),
        "wikiUrl": ((payload.get("content_urls") or {}).get("desktop") or {}).get("page"),
        "source": source,
    }


def _fetch_summary(base_url: str, title: str, source: str, client: httpx.Client) -> dict:
    slug = urllib.parse.quote(title.replace(" ", "_"), safe="")
    response = client.get(f"{base_url}/{slug}")
    if response.status_code == 404:
        raise ValueError(f"no wikipedia summary found for {title!r}")
    response.raise_for_status()
    result = parse_summary_response(response.json(), source=source)
    # A 200 page with no extract (empty summary) is not a usable species hit;
    # raising here lets the caller fall through to the English fallback.
    if not result["summary"]:
        raise ValueError(f"wikipedia summary for {title!r} has no extract")
    return result


def fetch_species_summary(
    name_ko: str | None, sci_name: str | None, client: httpx.Client | None = None
) -> dict | None:
    owns_client = client is None
    try:
        config = get_wikipedia_config()
        if client is None:
            client = httpx.Client(timeout=10.0, headers={"User-Agent": _USER_AGENT})

        if name_ko:
            try:
                return _fetch_summary(config.ko_base_url, name_ko, "ko.wikipedia", client)
            except Exception:
                pass

        if sci_name:
            try:
                return _fetch_summary(config.en_base_url, sci_name, "en.wikipedia", client)
            except Exception:
                pass

        return None
    except Exception:
        return None
    finally:
        if owns_client and client is not None:
            client.close()
