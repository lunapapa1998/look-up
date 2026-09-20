import httpx
import pytest
from fastapi import HTTPException
from fastapi.testclient import TestClient

from app.main import app
from app.routers.auth_kakao import FirebaseKakaoBridge, KakaoBridge, get_kakao_bridge

client = TestClient(app)


class _FakeBridge:
    def kakao_uid(self, access_token: str) -> str:
        assert access_token == "valid-token"
        return "kakao:42"

    def mint_custom_token(self, uid: str) -> str:
        assert uid == "kakao:42"
        return f"custom-for-{uid}"


def _override(bridge: KakaoBridge):
    app.dependency_overrides[get_kakao_bridge] = lambda: bridge
    return bridge


def teardown_function() -> None:
    app.dependency_overrides.pop(get_kakao_bridge, None)


def test_kakao_login_returns_custom_token() -> None:
    _override(_FakeBridge())
    response = client.post("/api/auth/kakao", json={"access_token": "valid-token"})
    assert response.status_code == 200
    assert response.json() == {"custom_token": "custom-for-kakao:42"}


def test_kakao_login_rejects_empty_token() -> None:
    _override(_FakeBridge())
    response = client.post("/api/auth/kakao", json={"access_token": ""})
    assert response.status_code == 422


def test_kakao_login_propagates_expired_kakao_token() -> None:
    class _Expired:
        def kakao_uid(self, access_token: str) -> str:
            raise HTTPException(401, "카카오 로그인이 만료되었습니다. 다시 로그인해주세요")

        def mint_custom_token(self, uid: str) -> str:  # pragma: no cover
            raise AssertionError("should not mint when Kakao verification fails")

    _override(_Expired())
    response = client.post("/api/auth/kakao", json={"access_token": "expired"})
    assert response.status_code == 401


def test_bridge_maps_kakao_401(monkeypatch: pytest.MonkeyPatch) -> None:
    def _fake_get(*args, **kwargs):
        return httpx.Response(401, request=httpx.Request("GET", "https://kapi.kakao.com"))

    monkeypatch.setattr(httpx, "get", _fake_get)
    with pytest.raises(HTTPException) as exc:
        FirebaseKakaoBridge().kakao_uid("bad")
    assert exc.value.status_code == 401


def test_bridge_builds_prefixed_uid(monkeypatch: pytest.MonkeyPatch) -> None:
    def _fake_get(*args, **kwargs):
        return httpx.Response(
            200,
            json={"id": 777},
            request=httpx.Request("GET", "https://kapi.kakao.com"),
        )

    monkeypatch.setattr(httpx, "get", _fake_get)
    assert FirebaseKakaoBridge().kakao_uid("ok") == "kakao:777"
