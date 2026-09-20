from __future__ import annotations

from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_get_regions_returns_sorted_list():
    response = client.get("/api/regions", params={"lat": 37.5, "lng": 127.0})
    assert response.status_code == 200

    data = response.json()
    assert "nearestId" in data
    assert isinstance(data["regions"], list)

    distances = [region["distanceKm"] for region in data["regions"]]
    for a, b in zip(distances, distances[1:]):
        assert a <= b

    for region in data["regions"]:
        assert set(["id", "label", "distanceKm", "center", "hasStarSpot"]).issubset(region.keys())
