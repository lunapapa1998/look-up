from __future__ import annotations

import json
from pathlib import Path

from app.observation.ebird import aggregate_by_location, parse_recent_obs

FIXTURES_DIR = Path(__file__).parent / "fixtures"


def _load_json(name: str) -> list[dict]:
    return json.loads((FIXTURES_DIR / name).read_text(encoding="utf-8"))


def test_parse_recent_obs_returns_normalized_records():
    payload = _load_json("ebird_recent_ganghwa.json")
    parsed = parse_recent_obs(payload)

    assert len(parsed) == 10

    row8 = parsed[7]
    assert row8["nameKo"] == "검은머리물떼새"
    assert row8["count"] is None

    row2 = parsed[1]
    assert row2["nameKo"] == "알락꼬리마도요"
    assert row2["nameSci"] == "Numenius madagascariensis"
    assert row2["speciesCode"] == "bktgod1"
    assert row2["count"] == 280
    assert row2["obsDt"] == "2026-09-09 16:16"
    assert row2["lat"] == 37.4715
    assert row2["lng"] == 126.5312
    assert row2["locId"] == "L1163669"
    assert row2["locName"] == "영종도--송산만과 갯벌(신불도 남단)"


def test_aggregate_by_location_groups_in_first_seen_order():
    payload = _load_json("ebird_recent_ganghwa.json")
    parsed = parse_recent_obs(payload)
    groups = aggregate_by_location(parsed)

    assert len(groups) == 3
    assert [group["locId"] for group in groups] == ["L1163669", "L1234567", "L2345678"]


def test_aggregate_by_location_l1163669():
    payload = _load_json("ebird_recent_ganghwa.json")
    parsed = parse_recent_obs(payload)
    groups = aggregate_by_location(parsed)
    group = groups[0]

    assert group["speciesCount"] == 4
    assert group["mostRecentObsDt"] == "2026-09-09 16:16"
    assert group["lat"] == 37.4715
    assert group["lng"] == 126.5312

    bktgod1 = next(s for s in group["topSpecies"] if s["speciesCode"] == "bktgod1")
    assert bktgod1["count"] == 280
    assert bktgod1["obsDt"] == "2026-09-09 16:16"


def test_aggregate_by_location_l1234567():
    payload = _load_json("ebird_recent_ganghwa.json")
    parsed = parse_recent_obs(payload)
    groups = aggregate_by_location(parsed)
    group = groups[1]

    assert group["speciesCount"] == 3
    codes = [s["speciesCode"] for s in group["topSpecies"]]
    assert "eurost1" in codes
    eurost1 = next(s for s in group["topSpecies"] if s["speciesCode"] == "eurost1")
    assert eurost1["count"] is None
    assert group["topSpecies"][-1]["speciesCode"] == "eurost1"


def test_aggregate_by_location_l2345678():
    payload = _load_json("ebird_recent_ganghwa.json")
    parsed = parse_recent_obs(payload)
    groups = aggregate_by_location(parsed)
    group = groups[2]

    assert group["speciesCount"] == 2
