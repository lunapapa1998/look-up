from __future__ import annotations

import math
from datetime import date, datetime, timedelta, timezone

KST = timezone(timedelta(hours=9))


def get_julian_date(dt_utc: datetime) -> float:
    """Calculate astronomical Julian Date for a given UTC datetime."""
    a = (14 - dt_utc.month) // 12
    y = dt_utc.year + 4800 - a
    m = dt_utc.month + 12 * a - 3
    jdn = (
        dt_utc.day
        + (153 * m + 2) // 5
        + 365 * y
        + y // 4
        - y // 100
        + y // 400
        - 32045
    )
    day_fraction = (
        (dt_utc.hour - 12) / 24.0
        + dt_utc.minute / 1440.0
        + dt_utc.second / 86400.0
        + dt_utc.microsecond / 86400000000.0
    )
    return jdn + day_fraction


def calculate_sun_events(lat: float, lng: float, target_date: date) -> dict[str, datetime]:
    """Calculate solar events (Sunset, Civil, Nautical, and Astronomical twilight ends) in KST.

    Uses the standard NOAA / Jean Meeus solar ephemeris algorithm.
    """
    dt_noon = datetime(
        target_date.year, target_date.month, target_date.day, 12, 0, 0, tzinfo=timezone.utc
    )
    jd_noon = get_julian_date(dt_noon)
    n = jd_noon - 2451545.0 + 0.0008
    j_star = n - lng / 360.0
    m_deg = (357.5291 + 0.98560028 * j_star) % 360.0
    m_rad = math.radians(m_deg)

    c = (
        1.9148 * math.sin(m_rad)
        + 0.0200 * math.sin(2 * m_rad)
        + 0.0003 * math.sin(3 * m_rad)
    )
    lambda_sun = (m_deg + c + 180.0 + 102.9372) % 360.0
    lambda_rad = math.radians(lambda_sun)

    j_transit = 2451545.0 + j_star + 0.0053 * math.sin(m_rad) - 0.0069 * math.sin(2 * lambda_rad)

    sin_dec = math.sin(lambda_rad) * math.sin(math.radians(23.44))
    cos_dec = math.cos(math.asin(sin_dec))
    lat_rad = math.radians(lat)

    def _calc_event(altitude_deg: float) -> datetime:
        alt_rad = math.radians(altitude_deg)
        cos_omega = (math.sin(alt_rad) - math.sin(lat_rad) * sin_dec) / (
            math.cos(lat_rad) * cos_dec
        )
        cos_omega = max(-1.0, min(1.0, cos_omega))
        omega_deg = math.degrees(math.acos(cos_omega))

        jd_event = j_transit + omega_deg / 360.0
        # Convert JD to Unix timestamp: JD 2440587.5 is 1970-01-01 00:00:00 UTC
        unix_sec = (jd_event - 2440587.5) * 86400.0
        utc_dt = datetime.fromtimestamp(unix_sec, tz=timezone.utc)
        return utc_dt.astimezone(KST)

    return {
        "sunset": _calc_event(-0.833),
        "civil_twilight_end": _calc_event(-6.0),
        "nautical_twilight_end": _calc_event(-12.0),
        "astronomical_twilight_end": _calc_event(-18.0),
    }


def get_sidereal_time_hours(dt_utc: datetime, lng_deg: float) -> float:
    """Calculate Local Sidereal Time (LST) in hours (0..24) for given UTC datetime and longitude."""
    d0 = datetime(dt_utc.year, dt_utc.month, dt_utc.day, 0, 0, 0, tzinfo=timezone.utc)
    a = (14 - d0.month) // 12
    y = d0.year + 4800 - a
    m = d0.month + 12 * a - 3
    jd0 = (
        d0.day
        + (153 * m + 2) // 5
        + 365 * y
        + y // 4
        - y // 100
        + y // 400
        - 32045
        - 0.5
    )
    d = jd0 - 2451545.0
    t = d / 36525.0
    gmst_sec = 24110.54841 + 8640184.812866 * t + 0.093104 * t**2 - 6.2e-6 * t**3
    ut_hours = dt_utc.hour + dt_utc.minute / 60.0 + dt_utc.second / 3600.0
    gmst_hours = (gmst_sec / 3600.0 + ut_hours * 1.00273790935) % 24.0
    lst_hours = (gmst_hours + lng_deg / 15.0) % 24.0
    return lst_hours


def equatorial_to_horizontal(
    ra_hours: float, dec_deg: float, lat_deg: float, lng_deg: float, dt_utc: datetime
) -> tuple[float, float]:
    """Convert equatorial coordinates (RA, Dec) to local horizontal coordinates (altitude, azimuth).

    Returns:
        (altitude_deg, azimuth_deg)
        altitude_deg: -90 to +90 degrees (above horizon is positive)
        azimuth_deg: 0 to 360 degrees (North=0, East=90, South=180, West=270)
    """
    lst_hours = get_sidereal_time_hours(dt_utc, lng_deg)
    ha_hours = (lst_hours - ra_hours) % 24.0
    ha_deg = ha_hours * 15.0

    ha_rad = math.radians(ha_deg)
    dec_rad = math.radians(dec_deg)
    lat_rad = math.radians(lat_deg)

    sin_alt = math.sin(lat_rad) * math.sin(dec_rad) + math.cos(lat_rad) * math.cos(
        dec_rad
    ) * math.cos(ha_rad)
    sin_alt = max(-1.0, min(1.0, sin_alt))
    alt_rad = math.asin(sin_alt)
    alt_deg = math.degrees(alt_rad)

    cos_az = (math.sin(dec_rad) - math.sin(lat_rad) * sin_alt) / (
        math.cos(lat_rad) * math.cos(alt_rad) + 1e-12
    )
    cos_az = max(-1.0, min(1.0, cos_az))
    az_deg = math.degrees(math.acos(cos_az))

    if math.sin(ha_rad) > 0:
        az_deg = 360.0 - az_deg

    return alt_deg, az_deg


def azimuth_to_direction(az_deg: float) -> str:
    """Convert azimuth degrees (0..360) into natural 8-compass Korean direction labels."""
    directions = ["북쪽", "북동쪽", "동쪽", "남동쪽", "남쪽", "남서쪽", "서쪽", "북서쪽"]
    idx = int((az_deg % 360.0 + 22.5) // 45) % 8
    return directions[idx]


def calculate_approx_moon(target_date: date) -> dict:
    """Calculate approximate lunar age, illumination percentage, and Korean phase name."""
    dt_utc = datetime(
        target_date.year, target_date.month, target_date.day, 12, 0, 0, tzinfo=timezone.utc
    )
    jd = get_julian_date(dt_utc)

    # Reference new moon: 2000-01-06 18:14 UTC (JD 2451549.26)
    synodic_month = 29.530588853
    days_since_ref = jd - 2451549.26
    cycles = days_since_ref / synodic_month
    phase = cycles - int(cycles)
    if phase < 0:
        phase += 1.0

    age_days = round(phase * synodic_month, 1)

    # Illumination percentage: 0% at new moon (0 or 29.5), 100% at full moon (~14.76)
    illumination_pct = round(100.0 * (1.0 - abs(age_days - 14.765) / 14.765))
    illumination_pct = max(0, min(100, illumination_pct))

    if age_days < 1.5 or age_days > 28.0:
        name = "그믐/신월"
    elif age_days < 7.0:
        name = "초승달"
    elif age_days < 9.0:
        name = "상현달"
    elif age_days < 13.5:
        name = "차오르는 달"
    elif age_days < 16.0:
        name = "보름달(만월)"
    elif age_days < 21.0:
        name = "이지러지는 달"
    elif age_days < 23.0:
        name = "하현달"
    else:
        name = "그믐달"

    return {
        "age_days": age_days,
        "illumination_pct": illumination_pct,
        "phase_name": name,
    }
