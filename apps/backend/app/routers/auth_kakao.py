"""Kakao → Firebase custom-token bridge.

The app performs the Kakao OAuth flow and sends us the resulting access token.
We verify it against Kakao, then mint a Firebase custom token for a stable,
namespaced uid (``kakao:<id>``) so the rest of the backend keeps verifying a
single, uniform Firebase identity.

Both outbound calls (Kakao profile lookup, Firebase token minting) live behind
a small service Protocol so tests can inject fakes without real network or
credentials.
"""
from __future__ import annotations

import os
import random
from functools import lru_cache
from typing import Protocol

import httpx
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

router = APIRouter(prefix="/api/auth", tags=["auth"])

_KAKAO_USER_ME = "https://kapi.kakao.com/v2/user/me"
_KAKAO_UID_PREFIX = "kakao:"

# App-themed random display names for users without a provider nickname
# (e.g. Kakao without 닉네임 consent). Generated once and persisted so the name
# stays stable across logins.
_NICKNAME_ADJECTIVES = (
    "반짝이는", "고요한", "별헤는", "달빛", "새벽", "떠오르는", "머무는", "푸른",
)
_NICKNAME_NOUNS = (
    "관측자", "갯벌지기", "별지기", "은하수", "밤하늘", "여행자", "노을", "달무리",
)


def random_nickname() -> str:
    adjective = random.choice(_NICKNAME_ADJECTIVES)
    noun = random.choice(_NICKNAME_NOUNS)
    return f"{adjective} {noun} {random.randint(1, 9999)}"


class KakaoLoginRequest(BaseModel):
    access_token: str = Field(min_length=1)


class KakaoLoginResponse(BaseModel):
    custom_token: str


class KakaoBridge(Protocol):
    def kakao_profile(self, access_token: str) -> tuple[str, str | None]: ...
    def mint_custom_token(
        self, uid: str, display_name: str | None = None
    ) -> str: ...


class FirebaseKakaoBridge:
    """Real bridge: talks to Kakao's API and Firebase Admin."""

    def kakao_profile(self, access_token: str) -> tuple[str, str | None]:
        """Returns (uid, nickname). Nickname is None when the Kakao app has no
        닉네임(profile_nickname) consent or the user did not agree."""
        try:
            response = httpx.get(
                _KAKAO_USER_ME,
                headers={"Authorization": f"Bearer {access_token}"},
                timeout=10.0,
            )
        except httpx.HTTPError:
            raise HTTPException(502, "카카오 인증 서버에 연결하지 못했습니다") from None
        if response.status_code == 401:
            raise HTTPException(401, "카카오 로그인이 만료되었습니다. 다시 로그인해주세요")
        if response.status_code != 200:
            raise HTTPException(502, "카카오 인증에 실패했습니다")
        data = response.json()
        kakao_id = data.get("id")
        if kakao_id is None:
            raise HTTPException(502, "카카오 사용자 정보를 확인하지 못했습니다")
        profile = (data.get("kakao_account") or {}).get("profile") or {}
        nickname = profile.get("nickname")
        return f"{_KAKAO_UID_PREFIX}{kakao_id}", nickname

    def mint_custom_token(self, uid: str, display_name: str | None = None) -> str:
        project = os.getenv("FIREBASE_PROJECT_ID", "").strip()
        if not project:
            raise HTTPException(503, "로그인 서버 설정이 필요합니다")
        # Imported lazily so the module (and its tests, which inject a fake
        # bridge) does not require firebase-admin to be installed/configured.
        import firebase_admin
        from firebase_admin import auth

        try:
            app = firebase_admin.get_app("lookup")
        except ValueError:
            try:
                app = firebase_admin.initialize_app(
                    options={"projectId": project}, name="lookup"
                )
            except Exception:
                raise HTTPException(503, "로그인 서버 자격 증명 설정이 필요합니다") from None
        # Ensure the Firebase user has a displayName so the app can show it
        # uniformly via user.displayName. Priority: real Kakao nickname > an
        # existing (previously set/generated) name > a new random app-themed
        # nickname. Persisting it keeps the name stable across logins.
        # Best-effort: failures here must not block login.
        try:
            existing = auth.get_user(uid, app=app)
        except auth.UserNotFoundError:
            existing = None
        except Exception:
            existing = None
        final_name = display_name or (
            None if (existing and existing.display_name) else random_nickname()
        )
        if final_name:
            try:
                if existing is not None:
                    auth.update_user(uid, display_name=final_name, app=app)
                else:
                    auth.create_user(uid=uid, display_name=final_name, app=app)
            except Exception:
                pass
        try:
            token = auth.create_custom_token(uid, app=app)
        except Exception:
            raise HTTPException(503, "로그인 토큰을 발급하지 못했습니다") from None
        return token.decode("utf-8") if isinstance(token, bytes) else token


@lru_cache
def _default_bridge() -> KakaoBridge:
    return FirebaseKakaoBridge()


def get_kakao_bridge() -> KakaoBridge:
    return _default_bridge()


@router.post("/kakao", response_model=KakaoLoginResponse)
def kakao_login(
    body: KakaoLoginRequest,
    bridge: KakaoBridge = Depends(get_kakao_bridge),
) -> KakaoLoginResponse:
    uid, nickname = bridge.kakao_profile(body.access_token)
    return KakaoLoginResponse(
        custom_token=bridge.mint_custom_token(uid, nickname)
    )
