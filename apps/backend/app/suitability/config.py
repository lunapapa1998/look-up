from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import unquote

from dotenv import find_dotenv, load_dotenv

load_dotenv(find_dotenv())


@dataclass(frozen=True)
class WeatherConfig:
    provider: str
    kma_base_url: str
    kma_api_key: str


def get_weather_config() -> WeatherConfig:
    return WeatherConfig(
        provider=os.getenv("WEATHER_PROVIDER", "kma"),
        kma_base_url=os.getenv(
            "KMA_APIHUB_BASE_URL", "https://apihub.kma.go.kr/api/typ01/cgi-bin/url"
        ),
        kma_api_key=os.getenv("KMA_APIHUB_KEY", ""),
    )


@dataclass(frozen=True)
class AstronomyConfig:
    riseset_base_url: str
    lunph_base_url: str
    service_key: str


def get_astronomy_config() -> AstronomyConfig:
    decoded_key = os.getenv("DATA_GO_KR_SERVICE_KEY_DECODED", "")
    service_key = decoded_key if decoded_key else unquote(os.getenv("DATA_GO_KR_SERVICE_KEY", ""))
    return AstronomyConfig(
        riseset_base_url=os.getenv("KASI_RISESET_BASE_URL", ""),
        lunph_base_url=os.getenv("KASI_LUNPH_BASE_URL", ""),
        service_key=service_key,
    )


@dataclass(frozen=True)
class TideConfig:
    base_url: str
    service_key: str


def get_tide_config() -> TideConfig:
    decoded_key = os.getenv("DATA_GO_KR_SERVICE_KEY_DECODED", "")
    service_key = decoded_key if decoded_key else unquote(os.getenv("DATA_GO_KR_SERVICE_KEY", ""))
    return TideConfig(
        base_url=os.getenv(
            "TIDE_API_BASE_URL",
            "https://apis.data.go.kr/1192136/tideFcstHghLw/GetTideFcstHghLwApiService",
        ),
        service_key=service_key,
    )


@dataclass(frozen=True)
class TrailsConfig:
    durunubi_base_url: str
    tourapi_base_url: str
    service_key: str


def get_trails_config() -> TrailsConfig:
    decoded_key = os.getenv("DATA_GO_KR_SERVICE_KEY_DECODED", "")
    service_key = decoded_key if decoded_key else unquote(os.getenv("DATA_GO_KR_SERVICE_KEY", ""))
    return TrailsConfig(
        durunubi_base_url=os.getenv(
            "DURUNUBI_BASE_URL", "https://apis.data.go.kr/B551011/Durunubi"
        ),
        tourapi_base_url=os.getenv(
            "TOURAPI_BASE_URL", "https://apis.data.go.kr/B551011/KorService2"
        ),
        service_key=service_key,
    )


@dataclass(frozen=True)
class ObservationConfig:
    ebird_token: str
    ebird_base_url: str


def get_observation_config() -> ObservationConfig:
    return ObservationConfig(
        ebird_token=os.getenv("EBIRD_API_TOKEN", ""),
        ebird_base_url=os.getenv("EBIRD_API_BASE_URL", "https://api.ebird.org/v2"),
    )


@dataclass(frozen=True)
class LightPollutionConfig:
    grid_path: str


def get_light_pollution_config() -> LightPollutionConfig:
    default_grid_path = Path(__file__).parent / "data" / "kr_light_pollution_grid.json"
    return LightPollutionConfig(
        grid_path=os.getenv("LIGHT_POLLUTION_GRID_PATH", str(default_grid_path)),
    )


def validate_coordinates(lat: float, lng: float) -> None:
    if not -90 <= lat <= 90:
        raise ValueError(f"lat out of range: {lat!r}")
    if not -180 <= lng <= 180:
        raise ValueError(f"lng out of range: {lng!r}")


@dataclass(frozen=True)
class WikipediaConfig:
    ko_base_url: str
    en_base_url: str


def get_wikipedia_config() -> WikipediaConfig:
    return WikipediaConfig(
        ko_base_url=os.getenv(
            "WIKIPEDIA_KO_BASE_URL", "https://ko.wikipedia.org/api/rest_v1/page/summary"
        ),
        en_base_url=os.getenv(
            "WIKIPEDIA_EN_BASE_URL", "https://en.wikipedia.org/api/rest_v1/page/summary"
        ),
    )
