from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)

ALLOWED = "https://lunapapa1998.github.io"
DISALLOWED = "https://evil.example.com"


def test_preflight_allowed_origin() -> None:
    response = client.options(
        "/api/health",
        headers={"Origin": ALLOWED, "Access-Control-Request-Method": "GET"},
    )
    assert response.status_code == 200
    assert response.headers.get("access-control-allow-origin") == ALLOWED


def test_get_allowed_origin() -> None:
    response = client.get("/api/health", headers={"Origin": ALLOWED})
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}
    assert response.headers.get("access-control-allow-origin") == ALLOWED


def test_get_disallowed_origin_has_no_allow_origin() -> None:
    response = client.get("/api/health", headers={"Origin": DISALLOWED})
    assert response.status_code == 200
    assert "access-control-allow-origin" not in response.headers


def test_preflight_disallowed_origin_rejected() -> None:
    response = client.options(
        "/api/health",
        headers={"Origin": DISALLOWED, "Access-Control-Request-Method": "GET"},
    )
    assert response.status_code == 400
    assert "access-control-allow-origin" not in response.headers


def test_origin_with_path_is_not_accepted() -> None:
    response = client.get(
        "/api/health", headers={"Origin": "https://lunapapa1998.github.io/look-up"}
    )
    assert "access-control-allow-origin" not in response.headers


def test_allow_origin_is_never_wildcard() -> None:
    get_response = client.get("/api/health", headers={"Origin": ALLOWED})
    preflight_response = client.options(
        "/api/health",
        headers={"Origin": ALLOWED, "Access-Control-Request-Method": "GET"},
    )
    assert get_response.headers.get("access-control-allow-origin") != "*"
    assert preflight_response.headers.get("access-control-allow-origin") != "*"
