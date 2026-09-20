from __future__ import annotations

from app.regions import registry


def test_sort_by_distance_from_seoul_places_ganghwa_top2():
    pairs = registry.sort_by_distance(37.5665, 126.9780)
    top2_ids = [region.id for region, _ in pairs[:2]]
    assert "ganghwa" in top2_ids


def test_sort_by_distance_from_busan_places_south_region_top2():
    pairs = registry.sort_by_distance(35.1796, 129.0756)
    top2_ids = [region.id for region, _ in pairs[:2]]
    assert "changnyeong" in top2_ids or "suncheon" in top2_ids


def test_nearest_returns_ganghwa():
    region = registry.nearest(37.7469, 126.4878)
    assert region.id == "ganghwa"


def test_get_unknown_id_returns_none():
    assert registry.get("unknown-id") is None


def test_get_ganghwa_returns_label():
    region = registry.get("ganghwa")
    assert region is not None
    assert region.label == "인천 강화군"
