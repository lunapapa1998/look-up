from __future__ import annotations

import math

from app.suitability.lightpollution.convert import (
    bortle_description,
    brightness_to_sqm,
    sqm_to_bortle,
)


def test_sqm_to_bortle_class_1_boundary():
    assert sqm_to_bortle(21.99) == 1
    assert sqm_to_bortle(22.5) == 1


def test_sqm_to_bortle_class_2_boundary():
    assert sqm_to_bortle(21.98) == 2
    assert sqm_to_bortle(21.89) == 2


def test_sqm_to_bortle_class_3_boundary():
    assert sqm_to_bortle(21.88) == 3
    assert sqm_to_bortle(21.69) == 3


def test_sqm_to_bortle_class_4_boundary():
    assert sqm_to_bortle(21.68) == 4
    assert sqm_to_bortle(21.25) == 4


def test_sqm_to_bortle_class_5_boundary():
    assert sqm_to_bortle(21.24) == 5
    assert sqm_to_bortle(20.49) == 5


def test_sqm_to_bortle_class_6_boundary():
    assert sqm_to_bortle(20.48) == 6
    assert sqm_to_bortle(19.50) == 6


def test_sqm_to_bortle_class_7_boundary():
    assert sqm_to_bortle(19.49) == 7
    assert sqm_to_bortle(18.94) == 7


def test_sqm_to_bortle_class_8_boundary():
    assert sqm_to_bortle(18.93) == 8
    assert sqm_to_bortle(18.38) == 8


def test_sqm_to_bortle_class_9_boundary():
    assert sqm_to_bortle(18.37) == 9


def test_sqm_to_bortle_clamps_far_below_all_thresholds():
    assert sqm_to_bortle(0.0) == 9
    assert sqm_to_bortle(-5.0) == 9


def test_brightness_to_sqm_zero_returns_natural_sky_value():
    assert brightness_to_sqm(0.0) == 22.0


def test_brightness_to_sqm_negative_returns_natural_sky_value():
    assert brightness_to_sqm(-1.0) == 22.0


def test_brightness_to_sqm_positive_returns_float_without_raising():
    result = brightness_to_sqm(5.0)
    assert isinstance(result, float)


def test_brightness_to_sqm_small_positive_stays_below_natural_ceiling():
    result = brightness_to_sqm(0.05)
    assert result < 22.0
    assert result > 20.0


def test_brightness_to_sqm_never_exceeds_natural_ceiling():
    for brightness in (0.0001, 0.001, 0.01, 0.1, 1, 10, 100, 1000, 10000, 100000, 1000000):
        assert brightness_to_sqm(brightness) <= 22.0 + 1e-9


def test_brightness_to_sqm_bright_city_matches_old_formula():
    brightness = 5000000
    old_formula_result = math.log10(brightness / 108000000) / -0.4
    assert abs(brightness_to_sqm(brightness) - old_formula_result) < 0.01


def test_bortle_description_labels():
    assert bortle_description(1) == "최적 다크스카이"
    assert bortle_description(2) == "최적 다크스카이"
    assert bortle_description(3) == "양호한 다크스카이"
    assert bortle_description(4) == "양호한 다크스카이"
    assert bortle_description(5) == "보통 도심 근교"
    assert bortle_description(6) == "보통 도심 근교"
    assert bortle_description(7) == "광해 심각"
    assert bortle_description(9) == "광해 심각"
