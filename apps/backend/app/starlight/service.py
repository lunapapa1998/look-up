from __future__ import annotations

from datetime import date, datetime
from typing import Optional

from app.starlight.astronomy import (
    KST,
    azimuth_to_direction,
    calculate_approx_moon,
    calculate_sun_events,
    equatorial_to_horizontal,
)
from app.starlight.catalog import CELESTIAL_CATALOG, CatalogItem
from app.starlight.models import (
    CelestialTargetDetail,
    Location,
    ObservingConditions,
    StarlightForecastResponse,
    TimingInfo,
)
from app.suitability.providers.light_pollution import LightPollutionProvider


class StarlightForecastService:
    def __init__(self, light_pollution_provider: Optional[LightPollutionProvider] = None):
        self.light_pollution_provider = light_pollution_provider or LightPollutionProvider()

    def generate_forecast(
        self,
        lat: float,
        lng: float,
        target_date: Optional[date] = None,
        target_time: Optional[str] = None,
        target_id: Optional[str] = None,
        override_sqm: Optional[float] = None,
        override_moon_illumination: Optional[int] = None,
        override_twilight_end: Optional[str] = None,
    ) -> StarlightForecastResponse:
        now_kst = datetime.now(KST)
        eval_date = target_date or now_kst.date()

        # 1. Calculate solar events
        sun_events = calculate_sun_events(lat, lng, eval_date)
        sunset_str = sun_events["sunset"].strftime("%H:%M")
        civil_end_str = sun_events["civil_twilight_end"].strftime("%H:%M")
        naut_end_str = sun_events["nautical_twilight_end"].strftime("%H:%M")
        astro_end_str = (
            override_twilight_end
            if override_twilight_end
            else sun_events["astronomical_twilight_end"].strftime("%H:%M")
        )

        # 2. Determine reference time for celestial positions
        ref_time_str = target_time or astro_end_str
        try:
            hour_str, min_str = ref_time_str.split(":")
            ref_dt_kst = datetime(
                eval_date.year,
                eval_date.month,
                eval_date.day,
                int(hour_str),
                int(min_str),
                0,
                tzinfo=KST,
            )
        except Exception:
            ref_dt_kst = sun_events["astronomical_twilight_end"]
            ref_time_str = ref_dt_kst.strftime("%H:%M")

        ref_dt_utc = ref_dt_kst.astimezone(datetime.now().astimezone().tzinfo).astimezone(
            KST
        )
        # UTC conversion for sidereal time
        from datetime import timezone

        ref_dt_utc = ref_dt_kst.astimezone(timezone.utc)

        # 3. Observing conditions (Moon + Light Pollution)
        moon_info = calculate_approx_moon(eval_date)
        moon_illumination = (
            override_moon_illumination
            if override_moon_illumination is not None
            else moon_info["illumination_pct"]
        )

        if override_sqm is not None:
            sqm_val = round(override_sqm, 2)
            sky_cls = f"SQM {sqm_val:.1f}"
        else:
            lp_reading = self.light_pollution_provider.fetch(lat, lng, "night")
            sqm_val = float(lp_reading.evidence.get("sqmValue", 19.5))
            sky_cls = str(lp_reading.evidence.get("skyClass", "Class 4 양호한 다크스카이"))

        milky_way_feasible = (sqm_val >= 19.5) and (moon_illumination <= 45)

        # 4. Evaluate catalog targets
        evaluated_targets: list[tuple[CatalogItem, float, float, str, str, float]] = []
        for item in CELESTIAL_CATALOG:
            alt, az = equatorial_to_horizontal(
                item.ra_hours, item.dec_deg, lat, lng, ref_dt_utc
            )
            direction = azimuth_to_direction(az)

            # Check if above horizon
            if target_id and item.id == target_id:
                if alt <= 0:
                    continue
            elif alt < item.min_alt or alt > item.max_alt:
                continue

            # Determine observation mode for this target
            if item.target_type == "milky_way":
                if milky_way_feasible:
                    mode = "육안 관측"
                elif sqm_val >= 18.0 or moon_illumination <= 60:
                    mode = "안시 관측"
                else:
                    mode = "망원경 관측"
            elif item.target_type == "cluster":
                mode = "육안 관측" if milky_way_feasible else "쌍안경 관측"
            else:
                mode = "육안 관측"

            # Score for auto-selection: sweet spot altitude 30°~60°
            alt_score = max(0.0, 100.0 - abs(alt - 45.0) * 1.5)
            score = item.priority * 1.2 + alt_score

            # If item requires dark sky and conditions are poor, penalize
            if item.requires_dark_sky and not milky_way_feasible:
                score -= 80.0

            # Boost if user explicitly requested this target
            if target_id and item.id == target_id:
                score += 1000.0

            evaluated_targets.append((item, alt, az, direction, mode, score))

        if not evaluated_targets:
            # Fallback if nothing in catalog passed min_alt (e.g. extreme polar latitude)
            best_item = CELESTIAL_CATALOG[0]
            best_alt, best_az = equatorial_to_horizontal(
                best_item.ra_hours, best_item.dec_deg, lat, lng, ref_dt_utc
            )
            best_direction = azimuth_to_direction(best_az)
            best_mode = "관측"
            visible_models = []
        else:
            evaluated_targets.sort(key=lambda t: t[5], reverse=True)
            best_item, best_alt, best_az, best_direction, best_mode, _ = evaluated_targets[0]
            visible_models = [
                CelestialTargetDetail(
                    id=item.id,
                    name=item.name,
                    constellation=item.constellation,
                    target_type=item.target_type,
                    altitude_deg=round(alt, 1),
                    azimuth_deg=round(az, 1),
                    direction=direction,
                    observation_mode=mode,
                    description=item.description,
                )
                for item, alt, az, direction, mode, _ in evaluated_targets
            ]

        chosen_target = CelestialTargetDetail(
            id=best_item.id,
            name=best_item.name,
            constellation=best_item.constellation,
            target_type=best_item.target_type,
            altitude_deg=round(best_alt, 1),
            azimuth_deg=round(best_az, 1),
            direction=best_direction,
            observation_mode=best_mode,
            description=best_item.description,
        )

        # 5. Build forecast summary sentence
        # Template: 오늘 {시간} 일몰 및 박명 종료 후 {방위} 방위에서 {대상} {관측유형}이 시작됩니다.
        summary_sentence = (
            f"오늘 {astro_end_str} 일몰 및 박명 종료 후 "
            f"{best_direction} 방위에서 {best_item.name} {best_mode}이 시작됩니다."
        )

        return StarlightForecastResponse(
            title="야간 전환 별빛 예보",
            summary=summary_sentence,
            location=Location(lat=lat, lng=lng),
            timing=TimingInfo(
                date=eval_date.strftime("%Y-%m-%d"),
                sunset=sunset_str,
                civil_twilight_end=civil_end_str,
                nautical_twilight_end=naut_end_str,
                astronomical_twilight_end=astro_end_str,
                forecast_reference_time=ref_time_str,
            ),
            target=chosen_target,
            conditions=ObservingConditions(
                lunar_age_days=moon_info["age_days"],
                moon_illumination_pct=moon_illumination,
                moon_phase_name=moon_info["phase_name"],
                sqm_value=sqm_val,
                sky_class=sky_cls,
                milky_way_visible=milky_way_feasible,
            ),
            all_visible_targets=visible_models,
            degraded=False,
        )


_service_instance: Optional[StarlightForecastService] = None


def get_starlight_service() -> StarlightForecastService:
    global _service_instance
    if _service_instance is None:
        _service_instance = StarlightForecastService()
    return _service_instance
