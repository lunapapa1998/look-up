from __future__ import annotations

from app.suitability import scoring
from app.suitability.models import (
    GoldenHour,
    Location,
    LayerScore,
    SuitabilityResponse,
    TelemetryReading,
)
from app.suitability.providers.astronomy import AstronomyProvider
from app.suitability.providers.base import LayerProvider, LayerReading
from app.suitability.providers.light_pollution import LightPollutionProvider
from app.suitability.providers.tide import TideProvider
from app.suitability.providers.weather import WeatherProvider

LAYER_KEYS: tuple[str, ...] = ("environment", "astronomy", "lightPollution", "tide")


class SuitabilityService:
    def __init__(self, providers: dict[str, LayerProvider]):
        self._providers = providers

    def get_suitability(self, lat: float, lng: float, mode: str) -> SuitabilityResponse:
        readings: dict[str, LayerReading] = {}
        for key in LAYER_KEYS:
            provider = self._providers.get(key)
            if provider is None:
                readings[key] = LayerReading(key=key, status="unavailable", sub_score=0)
                continue
            try:
                readings[key] = provider.fetch(lat, lng, mode)
            except Exception as exc:  # noqa: BLE001 -- a single bad provider must not crash the endpoint
                readings[key] = LayerReading(
                    key=key,
                    status="unavailable",
                    sub_score=0,
                    evidence={"reason": f"provider raised: {exc}"},
                )

        sub_scores = {key: reading.sub_score for key, reading in readings.items()}
        statuses = {key: reading.status for key, reading in readings.items()}
        fusion = scoring.fuse(mode, sub_scores, statuses)

        telemetry: list[TelemetryReading] = []
        golden_hours: list[GoldenHour] = []
        for key in LAYER_KEYS:
            reading = readings[key]
            telemetry.extend(TelemetryReading(**item) for item in reading.telemetry)
            golden_hours.extend(GoldenHour(**item) for item in reading.golden_hours)
        golden_hours.sort(key=lambda g: 0 if g.mode == "day" else 1)

        light_pollution_evidence = readings["lightPollution"].evidence
        sqm_value = light_pollution_evidence.get("sqmValue", 0.0)
        sky_class = light_pollution_evidence.get("skyClass", "알 수 없음")

        return SuitabilityResponse(
            mode=mode,
            location=Location(lat=lat, lng=lng),
            score=fusion["score"],
            label=fusion["label"],
            sqmValue=sqm_value,
            skyClass=sky_class,
            degraded=fusion["degraded"],
            goldenHours=golden_hours,
            telemetry=telemetry,
            layers=[LayerScore(**entry) for entry in fusion["layers"]],
        )


def get_default_providers() -> dict[str, LayerProvider]:
    return {
        "environment": WeatherProvider(),
        "astronomy": AstronomyProvider(),
        "lightPollution": LightPollutionProvider(),
        "tide": TideProvider(),
    }


_default_service = SuitabilityService(get_default_providers())


def get_suitability_service() -> SuitabilityService:
    return _default_service
