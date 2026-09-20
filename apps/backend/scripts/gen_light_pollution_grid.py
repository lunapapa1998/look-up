"""One-time offline generator for the bundled Korea light-pollution SQM grid.

This script is NOT part of `just check` and NOT part of the pytest suite. It is
run manually, exactly once (or whenever the source raster is refreshed), after
acquiring a World Atlas 2015 (Falchi et al.) GeoTIFF artificial-sky-brightness
raster. See `apps/backend/scripts/README.md` for how to obtain that raster.

What it does:
1. Opens the input GeoTIFF with rasterio.
2. Crops to the Korea bounding box (approximately 33-39 degrees N latitude,
   124-132 degrees E longitude).
3. Samples the raster on a regular lat/lng grid at a configurable resolution
   (default 0.05 degrees).
4. Converts each sampled brightness value (mcd/m^2) to SQM via
   `app.suitability.lightpollution.convert.brightness_to_sqm`.
5. Writes the result as JSON matching the exact schema consumed by
   `app.suitability.lightpollution.grid.load_grid`: a top-level object with
   `bbox` (`minLat`/`maxLat`/`minLng`/`maxLng`), `resolution`, `nrows`,
   `ncols`, and `values` (a 2D list; row 0 is at `minLat`, rows increase
   toward `maxLat`; col 0 is at `minLng`, cols increase toward `maxLng`).

The output JSON can be dropped directly at
`apps/backend/app/suitability/data/kr_light_pollution_grid.json` to activate
real light-pollution data in the running app (see the provider's
`LIGHT_POLLUTION_GRID_PATH` default in `app/suitability/config.py`).
"""

from __future__ import annotations

import argparse
import json
import os

# rasterio (and its numpy dependency) are offline-only tool dependencies --
# NOT part of the app's runtime dependencies (not in pyproject.toml) and not
# installed by default. This import will fail unless you `pip install
# rasterio` first; see apps/backend/scripts/README.md.
import numpy as np
import rasterio

from app.suitability.lightpollution.convert import brightness_to_sqm

KOREA_MIN_LAT = 33.0
KOREA_MAX_LAT = 39.0
KOREA_MIN_LNG = 124.0
KOREA_MAX_LNG = 132.0

DEFAULT_OUTPUT = "app/suitability/data/kr_light_pollution_grid.json"
DEFAULT_RESOLUTION = 0.05


def build_grid(
    input_path: str,
    resolution: float,
    min_lat: float = KOREA_MIN_LAT,
    max_lat: float = KOREA_MAX_LAT,
    min_lng: float = KOREA_MIN_LNG,
    max_lng: float = KOREA_MAX_LNG,
) -> dict:
    nrows = int(round((max_lat - min_lat) / resolution)) + 1
    ncols = int(round((max_lng - min_lng) / resolution)) + 1

    values: list[list[float | None]] = [[None] * ncols for _ in range(nrows)]

    with rasterio.open(input_path) as dataset:
        band = dataset.read(1, masked=True)

        for row in range(nrows):
            lat = min_lat + row * resolution
            for col in range(ncols):
                lng = min_lng + col * resolution

                try:
                    src_row, src_col = dataset.index(lng, lat)
                except (IndexError, ValueError):
                    continue

                if src_row < 0 or src_row >= band.shape[0]:
                    continue
                if src_col < 0 or src_col >= band.shape[1]:
                    continue

                pixel = band[src_row, src_col]
                if np.ma.is_masked(pixel):
                    continue

                brightness = float(pixel)
                values[row][col] = brightness_to_sqm(brightness)

    return {
        "bbox": {
            "minLat": min_lat,
            "maxLat": max_lat,
            "minLng": min_lng,
            "maxLng": max_lng,
        },
        "resolution": resolution,
        "nrows": nrows,
        "ncols": ncols,
        "values": values,
    }


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Crop/sample a World Atlas 2015 GeoTIFF over Korea and emit the "
            "bundled SQM grid JSON consumed by app.suitability.lightpollution.grid.load_grid."
        )
    )
    parser.add_argument(
        "--input",
        required=True,
        help="Path to the source World Atlas 2015 brightness GeoTIFF",
    )
    parser.add_argument(
        "--output",
        default=DEFAULT_OUTPUT,
        help=f"Output JSON path (default: {DEFAULT_OUTPUT})",
    )
    parser.add_argument(
        "--resolution",
        type=float,
        default=DEFAULT_RESOLUTION,
        help=f"Grid sampling step in degrees (default: {DEFAULT_RESOLUTION})",
    )
    args = parser.parse_args()

    grid = build_grid(args.input, args.resolution)

    os.makedirs(os.path.dirname(args.output) or ".", exist_ok=True)

    with open(args.output, "w", encoding="utf-8") as f:
        json.dump(grid, f)


if __name__ == "__main__":
    main()
