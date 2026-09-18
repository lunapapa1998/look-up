from __future__ import annotations

from pathlib import Path

from app.suitability.lightpollution.grid import load_grid, lookup

FIXTURE_PATH = str(Path(__file__).parent / "fixtures" / "lp_grid_sample.json")

SEOUL_LAT, SEOUL_LNG = 37.57, 126.98
MOUNTAIN_LAT, MOUNTAIN_LNG = 37.95, 127.45


def test_load_grid_returns_grid_with_expected_shape():
    grid = load_grid(FIXTURE_PATH)
    assert grid is not None
    assert grid.nrows == 3
    assert grid.ncols == 3


def test_load_grid_missing_path_returns_none():
    assert load_grid("/nonexistent/path/does_not_exist.json") is None


def test_lookup_seoul_returns_low_sqm():
    grid = load_grid(FIXTURE_PATH)
    assert lookup(grid, SEOUL_LAT, SEOUL_LNG) == 17.5


def test_lookup_mountain_returns_high_sqm():
    grid = load_grid(FIXTURE_PATH)
    assert lookup(grid, MOUNTAIN_LAT, MOUNTAIN_LNG) == 21.5


def test_mountain_sqm_greater_than_seoul_sqm():
    grid = load_grid(FIXTURE_PATH)
    seoul_sqm = lookup(grid, SEOUL_LAT, SEOUL_LNG)
    mountain_sqm = lookup(grid, MOUNTAIN_LAT, MOUNTAIN_LNG)
    assert mountain_sqm > seoul_sqm


def test_lookup_outside_bbox_returns_none():
    grid = load_grid(FIXTURE_PATH)
    assert lookup(grid, 10.0, 10.0) is None
