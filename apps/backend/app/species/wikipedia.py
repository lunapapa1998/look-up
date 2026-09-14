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


_EXTRACT_KO_API_URL = "https://ko.wikipedia.org/w/api.php"
_EXTRACT_EN_API_URL = "https://en.wikipedia.org/w/api.php"
_EXTRACT_MAX_LEN = 1500


def _fetch_extract(api_url: str, title: str, client: httpx.Client) -> str:
    response = client.get(
        api_url,
        params={
            "action": "query",
            "prop": "extracts",
            "exintro": 1,
            "explaintext": 1,
            "format": "json",
            "titles": title,
        },
    )
    response.raise_for_status()
    payload = response.json()
    page = next(iter(payload["query"]["pages"].values()))
    if "missing" in page:
        raise ValueError(f"no wikipedia article found for {title!r}")
    extract = page.get("extract") or ""
    if not extract.strip():
        raise ValueError(f"wikipedia extract for {title!r} is empty")
    return extract


def _truncate_extract(extract: str) -> str:
    if len(extract) <= _EXTRACT_MAX_LEN:
        return extract
    # Look for a sentence-ending punctuation mark at or before index _EXTRACT_MAX_LEN
    # so the cut lands on a full sentence instead of mid-word.
    window = extract[:_EXTRACT_MAX_LEN]
    last_idx = max(window.rfind("."), window.rfind("!"), window.rfind("?"))
    if last_idx == -1:
        return extract[:_EXTRACT_MAX_LEN]
    return extract[: last_idx + 1]


def fetch_species_extract(
    name_ko: str | None, sci_name: str | None, client: httpx.Client | None = None
) -> str | None:
    owns_client = client is None
    try:
        if client is None:
            client = httpx.Client(timeout=10.0, headers={"User-Agent": _USER_AGENT})

        if name_ko:
            try:
                return _truncate_extract(_fetch_extract(_EXTRACT_KO_API_URL, name_ko, client))
            except Exception:
                pass

        if sci_name:
            try:
                return _truncate_extract(_fetch_extract(_EXTRACT_EN_API_URL, sci_name, client))
            except Exception:
                pass

        return None
    except Exception:
        return None
    finally:
        if owns_client and client is not None:
            client.close()
