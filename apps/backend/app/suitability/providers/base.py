from __future__ import annotations

from dataclasses import dataclass, field
from typing import Protocol


@dataclass
class LayerReading:
    key: str
    status: str
    sub_score: int
    telemetry: list[dict] = field(default_factory=list)
    golden_hours: list[dict] = field(default_factory=list)
    evidence: dict = field(default_factory=dict)


class LayerProvider(Protocol):
    key: str

    def fetch(self, lat: float, lng: float, mode: str) -> LayerReading:
        ...
