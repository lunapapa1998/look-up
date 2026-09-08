from __future__ import annotations

import pytest

from app.suitability.scoring import LABEL_THRESHOLDS, fuse, label_for_score

ALL_KEYS = ["environment", "astronomy", "lightPollution", "tide"]
ALL_LIVE = {key: "live" for key in ALL_KEYS}


def test_all_zero_sub_scores_yield_score_zero() -> None:
    result = fuse("day", {key: 0 for key in ALL_KEYS}, ALL_LIVE)
    assert result["score"] == 0
    assert result["degraded"] is False


def test_all_full_sub_scores_yield_score_hundred() -> None:
    result = fuse("day", {key: 100 for key in ALL_KEYS}, ALL_LIVE)
    assert result["score"] == 100
    assert result["degraded"] is False


def test_day_and_night_modes_diverge_for_same_sub_scores() -> None:
    sub_scores = {"environment": 100, "astronomy": 0, "lightPollution": 0, "tide": 0}
    day_result = fuse("day", sub_scores, ALL_LIVE)
    night_result = fuse("night", sub_scores, ALL_LIVE)
    assert day_result["score"] != night_result["score"]


def test_unavailable_layer_is_excluded_and_renormalized() -> None:
    sub_scores = {"environment": 100, "astronomy": 100, "lightPollution": 100, "tide": 100}
    statuses = {"environment": "live", "astronomy": "live", "lightPollution": "live", "tide": "unavailable"}
    result = fuse("day", sub_scores, statuses)
    assert result["degraded"] is True
    assert result["score"] == 100
    tide_layer = next(layer for layer in result["layers"] if layer["key"] == "tide")
    assert tide_layer["weight"] == pytest.approx(0.25)
    assert tide_layer["status"] == "unavailable"
    assert tide_layer["subScore"] == 100


def test_all_layers_unavailable_yields_score_zero_no_exception() -> None:
    statuses = {key: "unavailable" for key in ALL_KEYS}
    result = fuse("day", {}, statuses)
    assert result["score"] == 0
    assert result["degraded"] is True


def test_missing_layer_defaults_to_zero_sub_score_and_unavailable_status() -> None:
    result = fuse("day", {"environment": 100}, {"environment": "live"})
    missing = next(layer for layer in result["layers"] if layer["key"] == "astronomy")
    assert missing["subScore"] == 0
    assert missing["status"] == "unavailable"
    assert result["degraded"] is True


@pytest.mark.parametrize(
    "score,expected_label",
    [
        (85, LABEL_THRESHOLDS[0][1]),
        (84, LABEL_THRESHOLDS[1][1]),
        (70, LABEL_THRESHOLDS[1][1]),
        (69, LABEL_THRESHOLDS[2][1]),
        (50, LABEL_THRESHOLDS[2][1]),
        (49, LABEL_THRESHOLDS[3][1]),
        (0, LABEL_THRESHOLDS[3][1]),
    ],
)
def test_label_for_score_boundaries(score: int, expected_label: str) -> None:
    assert label_for_score(score) == expected_label


def test_fuse_invalid_mode_raises_value_error() -> None:
    with pytest.raises(ValueError):
        fuse("dusk", {}, {})
