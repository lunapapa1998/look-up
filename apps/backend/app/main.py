from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.routers import (
    auth_kakao,
    badges,
    observation_map,
    observations,
    species,
    starlight,
    suitability,
    tide,
    trails,
    trails_detail,
)
from app.regions.router import router as regions_router

# GitHub Pages demo origin (exact match only).
ALLOWED_ORIGINS = ["https://lunapapa1998.github.io"]

app = FastAPI()
app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_methods=["GET", "POST"],
    allow_headers=["Content-Type", "Authorization"],
    allow_credentials=False,
)

app.include_router(auth_kakao.router)
app.include_router(observations.router)
app.include_router(badges.router)
app.include_router(species.router)
app.include_router(suitability.router)
app.include_router(starlight.router)
app.include_router(trails.router)
app.include_router(trails_detail.router)
app.include_router(tide.router)
app.include_router(observation_map.router)
app.include_router(regions_router)


@app.get("/api/health")
def health() -> dict[str, str]:
    return {"status": "ok"}
