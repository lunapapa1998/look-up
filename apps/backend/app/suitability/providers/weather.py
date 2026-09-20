"""Live KMA (기상청 API 허브) adapter for the environment (weather) layer.

Parsing (`parse`) is separated from network I/O (`fetch`) so the fusion logic
can be unit tested against fixture values with zero network calls. `parse`
operates on scalar grid values already extracted for a single point -- it
never raises.
"""

from __future__ import annotations

from datetime import datetime, timedelta, timezone
from dataclasses import replace
import logging
from threading import Lock, Thread
import time

import httpx

from app.suitability.config import get_weather_config
from app.suitability.providers.base import LayerReading

_COMPASS_DIRECTIONS = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]

_SKY_LABELS = {1: "맑음", 3: "구름많음", 4: "흐림"}
_SKY_SCORES = {1: 100, 3: 60, 4: 20}
_SKY_UNKNOWN_LABEL = "알수없음"
_SKY_UNKNOWN_SCORE = 50

_PTY_LABELS = {0: "없음", 1: "비", 2: "비/눈", 3: "눈", 4: "소나기"}
_PTY_UNKNOWN_LABEL = "알수없음"

_PRECIP_PENALTY = 0.3

_GRID_VARS = ("SKY", "REH", "WSD", "VEC", "PTY")
_NO_DATA_THRESHOLD = -90.0

# Standard KMA 동네예보 (Lambert) grid dimensions. The API Hub grid endpoints
# return the whole national grid flattened row-major (y increasing from the
# bottom), wrapped at an arbitrary number of values per physical line and with
# comma separators -- so a single ny row spans multiple lines and cannot be
# read line-by-line. Values are indexed (ny-1)*NX_MAX + (nx-1) over the flat
# token stream. Confirmed live against Seoul (nx=61, ny=128) 2026-09-08.
_GRID_NX_MAX = 149
_KST = timezone(timedelta(hours=9))
_REQUEST_TIMEOUT_SECONDS = 10.0
_REQUEST_ATTEMPTS = 3
_RETRY_BASE_DELAY_SECONDS = 0.2
_CACHE_FRESH_SECONDS = 10 * 60
_CACHE_TTL_SECONDS = 2 * 60 * 60

logger = logging.getLogger(__name__)


def _request_text(
    client: httpx.Client,
    url: str,
    params: dict,
    *,
    attempts: int = _REQUEST_ATTEMPTS,
) -> str:
    """Fetch KMA text with bounded retries for transient HTTP failures."""
    last_error: httpx.HTTPError | None = None
    for attempt in range(attempts):
        try:
            response = client.get(url, params=params)
            response.raise_for_status()
            return response.text
        except httpx.HTTPError as exc:
            last_error = exc
            if attempt + 1 < attempts:
                time.sleep(_RETRY_BASE_DELAY_SECONDS * (2**attempt))
    assert last_error is not None
    raise last_error


def _compass_direction(degrees: float) -> str:
    index = round(degrees / 45) % len(_COMPASS_DIRECTIONS)
    return _COMPASS_DIRECTIONS[index]


def _flatten_tokens(text: str) -> list[str]:
    tokens: list[str] = []
    for line in text.splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        tokens.extend(stripped.replace(",", " ").split())
    return tokens


def _parse_xy_response(text: str) -> tuple[int, int]:
    lines = [line for line in text.splitlines() if line.strip() and not line.strip().startswith("#")]
    if not lines:
        raise ValueError("no valid (non-comment) line in xy response")
    tokens = lines[-1].replace(",", " ").split()
    if len(tokens) < 2:
        raise ValueError(f"expected at least 2 tokens in xy line, got {tokens!r}")
    nx, ny = int(tokens[-2]), int(tokens[-1])
    return nx, ny


def _parse_grid_value(text: str, nx: int, ny: int, nx_max: int = _GRID_NX_MAX) -> float:
    tokens = _flatten_tokens(text)
    index = (ny - 1) * nx_max + (nx - 1)
    if not 0 <= index < len(tokens):
        raise ValueError(f"grid index {index} out of range (tokens={len(tokens)})")
    value = float(tokens[index])
    if value <= _NO_DATA_THRESHOLD:
        raise ValueError(f"no-data sentinel value: {value!r}")
    return value


class WeatherProvider:
    key = "environment"

    def __init__(self, client: httpx.Client | None = None):
        self._client = client
        self._cache: dict[tuple[float, float, str], tuple[float, LayerReading]] = {}
        self._cache_lock = Lock()

    @staticmethod
    def _cache_key(lat: float, lng: float, mode: str) -> tuple[float, float, str]:
        return (round(lat, 2), round(lng, 2), mode)

    def _remember(self, lat: float, lng: float, mode: str, reading: LayerReading) -> None:
        with self._cache_lock:
            self._cache[self._cache_key(lat, lng, mode)] = (time.monotonic(), reading)

    def _cached_fallback(
        self, lat: float, lng: float, mode: str, reason: str
    ) -> LayerReading | None:
        with self._cache_lock:
            cached = self._cache.get(self._cache_key(lat, lng, mode))
        if cached is None:
            return None
        cached_at, reading = cached
        age_seconds = time.monotonic() - cached_at
        if age_seconds > _CACHE_TTL_SECONDS:
            return None
        return replace(
            reading,
            status="approx",
            evidence={
                **reading.evidence,
                "fallback": "cached KMA reading",
                "cacheAgeSeconds": round(age_seconds),
                "liveFailure": reason,
            },
        )

    def _fresh_cached(self, lat: float, lng: float, mode: str) -> LayerReading | None:
        with self._cache_lock:
            cached = self._cache.get(self._cache_key(lat, lng, mode))
        if cached is None:
            return None
        cached_at, reading = cached
        if time.monotonic() - cached_at > _CACHE_FRESH_SECONDS:
            return None
        return reading

    def parse(self, values: dict, mode: str) -> LayerReading:
        sky_code = int(values["SKY"])
        pty_code = int(values["PTY"])
        humidity = float(values["REH"])
        wind_speed = float(values["WSD"])
        wind_deg = float(values["VEC"])

        sky_label = _SKY_LABELS.get(sky_code, _SKY_UNKNOWN_LABEL)
        sky_score = _SKY_SCORES.get(sky_code, _SKY_UNKNOWN_SCORE)
        pty_label = _PTY_LABELS.get(pty_code, _PTY_UNKNOWN_LABEL)
        precipitation_detected = pty_code != 0

        humidity_score = max(0, 1 - humidity / 100) * 100
        wind_score = max(0, 1 - wind_speed / 10) * 100

        if mode == "night":
            base_sub_score = sky_score * 0.45 + humidity_score * 0.35 + wind_score * 0.20
        else:
            base_sub_score = wind_score * 0.5 + sky_score * 0.5

        sub_score = base_sub_score * _PRECIP_PENALTY if precipitation_detected else base_sub_score
        sub_score = max(0, min(100, round(sub_score)))

        wind_direction = _compass_direction(wind_deg)

        telemetry = [
            {"kind": "sky", "label": "하늘상태", "value": sky_label},
            {"kind": "humidity", "label": "습도", "value": f"{humidity:.0f}%"},
            {
                "kind": "wind",
                "label": "풍속·풍향",
                "value": f"{wind_speed:.1f} m/s ({wind_direction})",
            },
            {"kind": "precip", "label": "강수형태", "value": pty_label},
        ]

        return LayerReading(
            key=self.key,
            status="live",
            sub_score=int(sub_score),
            telemetry=telemetry,
            golden_hours=[],
            evidence={
                "skyCode": sky_code,
                "ptyCode": pty_code,
                "precipitationDetected": precipitation_detected,
            },
        )

    def fetch(self, lat: float, lng: float, mode: str) -> LayerReading:
        config = get_weather_config()
        if not config.kma_api_key:
            return LayerReading(
                key=self.key,
                status="unavailable",
                sub_score=0,
                evidence={"reason": "KMA_APIHUB_KEY not configured"},
            )
        if config.provider != "kma":
            return LayerReading(
                key=self.key,
                status="unavailable",
                sub_score=0,
                evidence={"reason": f"unsupported weather provider: {config.provider}"},
            )

        cached = self._fresh_cached(lat, lng, mode)
        if cached is not None:
            return cached

        client = self._client
        owns_client = client is None
        if owns_client:
            client = httpx.Client(timeout=_REQUEST_TIMEOUT_SECONDS)

        try:
            xy_text = _request_text(
                client,
                f"{config.kma_base_url}/nph-dfs_xy_lonlat",
                {"lon": lng, "lat": lat, "help": 1, "authKey": config.kma_api_key},
            )
            nx, ny = _parse_xy_response(xy_text)

            # 초단기예보(vsrt): published hourly at :30, forecasts +0~6h. Unlike
            # 실황(odam) it includes SKY (하늘상태), which the scoring uses as the
            # cloud/운량 proxy. Use the previous :30 base and the next full hour
            # as the forecast target -- both confirmed available live.
            base = (datetime.now(_KST) - timedelta(hours=1)).replace(
                minute=30, second=0, microsecond=0
            )
            tmfc = base.strftime("%Y%m%d%H%M")
            tmef = (base.replace(minute=0) + timedelta(hours=1)).strftime("%Y%m%d%H00")

            values: dict = {}
            for var_name in _GRID_VARS:
                # One request per variable: the grid text layout for a
                # multi-variable request is ambiguous to parse reliably, so
                # each variable is fetched (and parsed) independently.
                grid_text = _request_text(
                    client,
                    f"{config.kma_base_url}/nph-dfs_vsrt_grd",
                    {
                        "tmfc": tmfc,
                        "tmef": tmef,
                        "vars": var_name,
                        "authKey": config.kma_api_key,
                    },
                )
                values[var_name] = _parse_grid_value(grid_text, nx, ny)

            # The KMA measurements are mode-independent. Cache both scored
            # projections from one live payload so day/night switching never
            # repeats the same six external requests.
            readings = {
                cached_mode: self.parse(values, cached_mode)
                for cached_mode in ("day", "night")
            }
            for cached_mode, reading in readings.items():
                self._remember(lat, lng, cached_mode, reading)
            return readings[mode]
        except (httpx.HTTPError, ValueError, IndexError) as exc:
            reason = f"KMA weather request failed: {exc}"
            cached = self._cached_fallback(lat, lng, mode, reason)
            if cached is not None:
                logger.warning(
                    "KMA weather live request failed for lat=%s lng=%s; using cached reading: %s",
                    lat,
                    lng,
                    exc,
                )
                return cached
            logger.warning(
                "KMA weather unavailable after retries for lat=%s lng=%s: %s",
                lat,
                lng,
                exc,
            )
            return LayerReading(
                key=self.key,
                status="unavailable",
                sub_score=0,
                evidence={"reason": reason},
            )
        finally:
            if owns_client:
                client.close()


class ProgressiveWeatherProvider:
    """Serve cached weather immediately and refresh KMA in the background."""

    key = "environment"

    def __init__(self, provider: WeatherProvider | None = None):
        self._provider = provider or WeatherProvider()
        self._refresh_lock = Lock()
        self._refreshing: set[tuple[float, float]] = set()

    @staticmethod
    def _location_key(lat: float, lng: float) -> tuple[float, float]:
        return (round(lat, 2), round(lng, 2))

    def _start_refresh(self, lat: float, lng: float, mode: str) -> None:
        key = self._location_key(lat, lng)
        with self._refresh_lock:
            if key in self._refreshing:
                return
            self._refreshing.add(key)

        def refresh() -> None:
            try:
                self._provider.fetch(lat, lng, mode)
            finally:
                with self._refresh_lock:
                    self._refreshing.discard(key)

        Thread(target=refresh, name="kma-weather-refresh", daemon=True).start()

    def fetch(self, lat: float, lng: float, mode: str) -> LayerReading:
        fresh = self._provider._fresh_cached(lat, lng, mode)
        if fresh is not None:
            return fresh

        stale = self._provider._cached_fallback(
            lat, lng, mode, "KMA refresh in progress"
        )
        self._start_refresh(lat, lng, mode)
        if stale is not None:
            return stale
        return LayerReading(
            key=self.key,
            status="loading",
            sub_score=0,
            evidence={"reason": "KMA refresh in progress"},
        )
