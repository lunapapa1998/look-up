from __future__ import annotations

import re

_SEED: dict[str, dict[str, str | None]] = {
    "platalea minor": {
        "nameKo": "저어새",
        "naturalMonument": "천연기념물 제205-1호",
        "koreaEndangered": "멸종위기 I급",
        "iucn": "EN",
    },
    "egretta eulophotes": {
        "nameKo": "노랑부리백로",
        "naturalMonument": "천연기념물 제361호",
        "koreaEndangered": "멸종위기 I급",
        "iucn": "VU",
    },
    "ciconia boyciana": {
        "nameKo": "황새",
        "naturalMonument": "천연기념물 제199호",
        "koreaEndangered": "멸종위기 I급",
        "iucn": "EN",
    },
    "grus japonensis": {
        "nameKo": "두루미",
        "naturalMonument": "천연기념물 제202호",
        "koreaEndangered": "멸종위기 I급",
        "iucn": "VU",
    },
    "grus vipio": {
        "nameKo": "재두루미",
        "naturalMonument": "천연기념물 제203호",
        "koreaEndangered": "멸종위기 II급",
        "iucn": "VU",
    },
    "grus monacha": {
        "nameKo": "흑두루미",
        "naturalMonument": "천연기념물 제228호",
        "koreaEndangered": "멸종위기 II급",
        "iucn": "VU",
    },
    "haematopus ostralegus": {
        "nameKo": "검은머리물떼새",
        "naturalMonument": "천연기념물 제326호",
        "koreaEndangered": "멸종위기 II급",
        "iucn": "NT",
    },
    "numenius madagascariensis": {
        "nameKo": "알락꼬리마도요",
        "naturalMonument": None,
        "koreaEndangered": "멸종위기 II급",
        "iucn": "EN",
    },
    "cygnus columbianus": {
        "nameKo": "고니",
        "naturalMonument": "천연기념물 제201-2호",
        "koreaEndangered": "멸종위기 II급",
        "iucn": "LC",
    },
    "cygnus cygnus": {
        "nameKo": "큰고니",
        "naturalMonument": "천연기념물 제201-3호",
        "koreaEndangered": "멸종위기 II급",
        "iucn": "LC",
    },
}


def _normalize(text: str) -> str:
    return re.sub(r"\s+", " ", text.strip().lower())


def lookup_conservation(sci_name: str | None, name_ko: str | None) -> dict | None:
    entry = None

    if sci_name:
        entry = _SEED.get(_normalize(sci_name))

    if entry is None and name_ko:
        normalized_ko = name_ko.strip()
        for candidate in _SEED.values():
            if candidate["nameKo"] == normalized_ko:
                entry = candidate
                break

    if entry is None:
        return None

    return {
        "naturalMonument": entry["naturalMonument"],
        "koreaEndangered": entry["koreaEndangered"],
        "iucn": entry["iucn"],
    }
