from fastapi import FastAPI

from app.routers import badges, observations

app = FastAPI()

app.include_router(observations.router)
app.include_router(badges.router)


@app.get("/api/health")
def health() -> dict[str, str]:
    return {"status": "ok"}
