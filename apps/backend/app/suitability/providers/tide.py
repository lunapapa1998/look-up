"""Honest stub for the tide layer.

The KHOA (Korea Hydrographic and Oceanographic Agency) tide API is not yet
integrated -- a future slice will replace this with a live adapter once a key
is issued. Until then this returns fixed, deterministic placeholder data and
always reports status="stub" so callers never mistake it for real data.
"""

from __future__ import annotations

from app.suitability.providers.base import LayerReading

_SUB_SCORE = 70


class TideProvider:
    key = "tide"

    def fetch(self, lat: float, lng: float, mode: str) -> LayerReading:
        golden_hours = []
        if mode == "day":
            golden_hours = [
                {
                    "mode": "day",
                    "label": "낮 · 탐조 골든타임",
                    "timeRange": "14:00 - 17:30",
                    "description": "만조 2시간 전 갯벌 유입 피크 (스텁 데이터)",
                }
            ]

        return LayerReading(
            key=self.key,
            status="stub",
            sub_score=_SUB_SCORE,
            telemetry=[
                {
                    "kind": "tide",
                    "label": "조위 상태",
                    "value": "만조 16:15 (스텁 데이터)",
                }
            ],
            golden_hours=golden_hours,
            evidence={
                "reason": "KHOA 조석 API 미연동 상태 -- 키 발급 전까지의 결정적 placeholder입니다.",
            },
        )
