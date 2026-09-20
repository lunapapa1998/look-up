import httpx
import pytest
from fastapi import HTTPException
from fastapi.testclient import TestClient

from app.main import app
from app.routers.auth_kakao import (
    FirebaseKakaoBridge,
    KakaoBridge,
    get_kakao_bridge,
    random_nickname,
)

client = TestClient(app)


class _FakeBridge:
    def kakao_profile(self, access_token: str) -> tuple[str, str | None]:
        assert access_token == "valid-token"
        return "kakao:42", "홍길동"

    def mint_custom_token(self, uid: str, display_name: str | None = None) -> str:
        assert uid == "kakao:42"
        assert display_name == "홍길동"
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
        def kakao_profile(self, access_token: str) -> tuple[str, str | None]:
            raise HTTPException(401, "카카오 로그인이 만료되었습니다. 다시 로그인해주세요")

        def mint_custom_token(  # pragma: no cover
            self, uid: str, display_name: str | None = None
        ) -> str:
            raise AssertionError("should not mint when Kakao verification fails")

    _override(_Expired())
    response = client.post("/api/auth/kakao", json={"access_token": "expired"})
    assert response.status_code == 401


def test_bridge_maps_kakao_401(monkeypatch: pytest.MonkeyPatch) -> None:
    def _fake_get(*args, **kwargs):
        return httpx.Response(401, request=httpx.Request("GET", "https://kapi.kakao.com"))

    monkeypatch.setattr(httpx, "get", _fake_get)
    with pytest.raises(HTTPException) as exc:
        FirebaseKakaoBridge().kakao_profile("bad")
    assert exc.value.status_code == 401


def test_bridge_extracts_uid_and_nickname(monkeypatch: pytest.MonkeyPatch) -> None:
    def _fake_get(*args, **kwargs):
        return httpx.Response(
            200,
            json={
                "id": 777,
                "kakao_account": {"profile": {"nickname": "별지기"}},
            },
            request=httpx.Request("GET", "https://kapi.kakao.com"),
        )

    monkeypatch.setattr(httpx, "get", _fake_get)
    assert FirebaseKakaoBridge().kakao_profile("ok") == ("kakao:777", "별지기")


def test_bridge_nickname_none_when_no_consent(monkeypatch: pytest.MonkeyPatch) -> None:
    def _fake_get(*args, **kwargs):
        return httpx.Response(
            200,
            json={"id": 777},
            request=httpx.Request("GET", "https://kapi.kakao.com"),
        )

    monkeypatch.setattr(httpx, "get", _fake_get)
    assert FirebaseKakaoBridge().kakao_profile("ok") == ("kakao:777", None)


def test_random_nickname_format() -> None:
    name = random_nickname()
    parts = name.rsplit(" ", 1)
    assert len(parts) == 2
    assert parts[1].isdigit() and 1 <= int(parts[1]) <= 9999
    # Two distinct generations should (almost always) differ.
    assert len({random_nickname() for _ in range(20)}) > 1
