"""Pure-Python nearest-neighbor lookup over a pre-baked light-pollution grid.

No numpy -- index arithmetic only. The only I/O is a single json.load in
load_grid(); lookup() itself never touches the filesystem.
"""

from __future__ import annotations

import json
import os
from dataclasses import dataclass


@dataclass(frozen=True)
class Grid:
    min_lat: float
    max_lat: float
    min_lng: float
    max_lng: float
    resolution: float
    nrows: int
    ncols: int
    values: list[list[float | None]]


def load_grid(path: str) -> Grid | None:
    if not os.path.exists(path):
        return None

    with open(path, encoding="utf-8") as f:
        data = json.load(f)

    bbox = data["bbox"]
    return Grid(
        min_lat=bbox["minLat"],
        max_lat=bbox["maxLat"],
        min_lng=bbox["minLng"],
        max_lng=bbox["maxLng"],
        resolution=data["resolution"],
        nrows=data["nrows"],
        ncols=data["ncols"],
        values=data["values"],
    )


def lookup(grid: Grid, lat: float, lng: float) -> float | None:
    if lat < grid.min_lat or lat > grid.max_lat:
        return None
    if lng < grid.min_lng or lng > grid.max_lng:
        return None

    row = round((lat - grid.min_lat) / grid.resolution)
    col = round((lng - grid.min_lng) / grid.resolution)

    row = max(0, min(grid.nrows - 1, row))
    col = max(0, min(grid.ncols - 1, col))

    return grid.values[row][col]
