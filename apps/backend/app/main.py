from fastapi import FastAPI

from app.routers import (
    badges,
    observation_map,
    observations,
    species,
    suitability,
    trails,
    trails_detail,
)

app = FastAPI()

app.include_router(observations.router)
app.include_router(badges.router)
app.include_router(species.router)
app.include_router(suitability.router)
app.include_router(trails.router)
app.include_router(trails_detail.router)
app.include_router(observation_map.router)


@app.get("/api/health")
def health() -> dict[str, str]:
    return {"status": "ok"}
