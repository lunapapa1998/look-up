# Offline scripts

Scripts in this directory are **manually run, one-time tools** — they are not
part of `just check`, not part of the pytest suite, and must not be imported
by any test or app code.

## `gen_light_pollution_grid.py` — generate the bundled Korea SQM grid

This script turns a World Atlas 2015 brightness raster into the bundled JSON
grid consumed by the light-pollution provider at runtime
(`app/suitability/lightpollution/grid.load_grid`). It only needs to be run
once (or whenever the source raster is refreshed) — the app itself never
touches rasterio or the original GeoTIFF.

### 1. Acquire the source raster

Download the **World Atlas 2015 (Falchi et al.) World Atlas of Artificial
Night Sky Brightness** GeoTIFF from its official public data repository (the
dataset's canonical release, not a re-host). Any World Atlas 2015 brightness
GeoTIFF that covers Korea (roughly 33-39°N, 124-132°E) works; no specific URL
is required here.

### 2. rasterio is not an app dependency

`rasterio` is only needed to run this script — it is **not** added to
`apps/backend/pyproject.toml`, since the running app never needs it.

### 3. Run the script

From `apps/backend`, use `uv run --with rasterio` to add `rasterio` as an
ephemeral dependency for just this invocation (a plain `pip install` would
land outside `uv`'s managed environment and the script would fail with a
missing `rasterio` import):

```sh
uv run --with rasterio python scripts/gen_light_pollution_grid.py \
  --input path/to/world_atlas_2015.tif
```

This relies on the script's default `--output` path (see below), which
already resolves to `app/suitability/data/kr_light_pollution_grid.json`
relative to `apps/backend`.

Arguments:

| Flag | Required | Default | Notes |
|---|---|---|---|
| `--input` | yes | — | Path to the source World Atlas 2015 GeoTIFF |
| `--output` | no | `app/suitability/data/kr_light_pollution_grid.json` | Output JSON path |
| `--resolution` | no | `0.05` | Grid sampling step, in degrees |

The script crops the raster to the Korea bounding box (~33-39°N, 124-132°E),
samples it on a regular lat/lng grid at `--resolution` degrees, converts each
sampled brightness value to SQM, and writes the result as JSON.

### 4. Commit the generated grid

Once generated, commit `kr_light_pollution_grid.json` to the repo at:

```
apps/backend/app/suitability/data/kr_light_pollution_grid.json
```

The provider's default config path
(`get_light_pollution_config().grid_path` in `app/suitability/config.py`)
already points here, so committing the file is enough to activate it — no
code change needed. Once present, the light-pollution layer starts returning
`status="approx"` (real grid data) for real coordinates instead of
`status="stub"` (synthetic fallback).
