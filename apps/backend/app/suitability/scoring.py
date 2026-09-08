from __future__ import annotations

WEIGHTS_BY_MODE: dict[str, dict[str, float]] = {
    "day": {
        "environment": 0.40,
        "astronomy": 0.20,
        "lightPollution": 0.15,
        "tide": 0.25,
    },
    "night": {
        "environment": 0.35,
        "astronomy": 0.25,
        "lightPollution": 0.30,
        "tide": 0.10,
    },
}

LABEL_THRESHOLDS: list[tuple[int, str]] = [
    (85, "매우 쾌적 (Prime)"),
    (70, "쾌적"),
    (50, "보통"),
    (0, "제한적"),
]


def label_for_score(score: int) -> str:
    for threshold, label in LABEL_THRESHOLDS:
        if score >= threshold:
            return label
    return LABEL_THRESHOLDS[-1][1]


def fuse(mode: str, sub_scores: dict[str, int], statuses: dict[str, str]) -> dict:
    if mode not in WEIGHTS_BY_MODE:
        raise ValueError(f"unknown mode: {mode!r}")

    weights = WEIGHTS_BY_MODE[mode]
    layers = []
    total_weight = 0.0
    weighted_sum = 0.0
    degraded = False

    for key, weight in weights.items():
        status = statuses.get(key, "unavailable")
        sub_score = sub_scores.get(key, 0)
        if status == "unavailable":
            degraded = True
        else:
            total_weight += weight
            weighted_sum += weight * sub_score
        layers.append(
            {
                "key": key,
                "weight": weight,
                "subScore": sub_score,
                "status": status,
            }
        )

    score = round(weighted_sum / total_weight) if total_weight > 0 else 0
    score = max(0, min(100, score))

    return {
        "score": score,
        "degraded": degraded,
        "label": label_for_score(score),
        "layers": layers,
    }
