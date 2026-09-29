from __future__ import annotations

import secrets
import time
import uuid
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Response
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel, Field, SecretStr, field_validator

from auth_security import (
    create_session_token,
    hash_password,
    hash_invite_code,
    hash_session_token,
    verify_password,
)
from auth_store import AuthStore

SESSION_LIFETIME_SECONDS = 30 * 24 * 60 * 60
_DUMMY_PASSWORD_HASH = hash_password("not-a-real-user-password")


class LoginRequest(BaseModel):
    username: str = Field(min_length=1, max_length=64)
    password: SecretStr = Field(min_length=1, max_length=1024)


class InviteRequest(BaseModel):
    expires_in_seconds: int = Field(default=7 * 24 * 60 * 60, ge=3600, le=30 * 24 * 60 * 60)


class RegistrationRequest(BaseModel):
    code: str = Field(min_length=1, max_length=128)
    username: str = Field(min_length=1, max_length=64)
    password: SecretStr = Field(min_length=12, max_length=256)

    @field_validator("username")
    @classmethod
    def normalize_username(cls, value: str) -> str:
        normalized = value.strip()
        if not normalized:
            raise ValueError("Username must not be blank.")
        return normalized


def create_auth_api(
    store: AuthStore,
) -> tuple[APIRouter, Any]:
    router = APIRouter(prefix="/api/auth", tags=["authentication"])
    bearer = HTTPBearer(auto_error=False)

    def current_user(
        credentials: HTTPAuthorizationCredentials | None = Depends(bearer),
    ) -> dict[str, Any]:
        if credentials is None or credentials.scheme.lower() != "bearer":
            raise HTTPException(
                status_code=401,
                detail="Authentication required.",
                headers={"WWW-Authenticate": "Bearer"},
            )
        session = store.get_active_session(hash_session_token(credentials.credentials))
        if session is None:
            raise HTTPException(
                status_code=401,
                detail="Invalid or expired session.",
                headers={"WWW-Authenticate": "Bearer"},
            )
        return session

    def require_owner(user: dict[str, Any]) -> None:
        if user["role"] != "owner":
            raise HTTPException(status_code=403, detail="Owner access required.")

    def create_session_response(user: dict[str, Any]) -> dict[str, Any]:
        token = create_session_token()
        expires_at = time.time() + SESSION_LIFETIME_SECONDS
        store.create_session(hash_session_token(token), user["id"], expires_at=expires_at)
        return {
            "access_token": token,
            "token_type": "bearer",
            "expires_in": SESSION_LIFETIME_SECONDS,
            "user": {
                "id": user["id"],
                "username": user["username"],
                "role": user["role"],
            },
        }

    @router.post("/login")
    def login(request: LoginRequest) -> dict[str, Any]:
        user = store.get_user_by_username(request.username)
        stored_hash = user["password_hash"] if user is not None else _DUMMY_PASSWORD_HASH
        password_valid = verify_password(
            request.password.get_secret_value(), stored_hash
        )
        if user is None or user["disabled_at"] is not None or not password_valid:
            raise HTTPException(status_code=401, detail="Invalid username or password.")

        return create_session_response(user)

    @router.post("/register", status_code=201)
    def register(request: RegistrationRequest) -> dict[str, Any]:
        token = create_session_token()
        expires_at = time.time() + SESSION_LIFETIME_SECONDS
        status, user = store.redeem_invite(
            code_hash=hash_invite_code(request.code),
            user_id=str(uuid.uuid4()),
            username=request.username,
            password_hash=hash_password(request.password.get_secret_value()),
            session_token_hash=hash_session_token(token),
            session_expires_at=expires_at,
        )
        if status == "username_taken":
            raise HTTPException(status_code=409, detail="Username is already in use.")
        if user is None:
            raise HTTPException(status_code=400, detail="Invitation is invalid or unavailable.")
        return {
            "access_token": token,
            "token_type": "bearer",
            "expires_in": SESSION_LIFETIME_SECONDS,
            "user": user,
        }

    @router.post("/invites", status_code=201)
    def create_invite(
        request: InviteRequest,
        user: dict[str, Any] = Depends(current_user),
    ) -> dict[str, Any]:
        require_owner(user)
        code = secrets.token_urlsafe(32)
        invite_id = str(uuid.uuid4())
        now = time.time()
        expires_at = now + request.expires_in_seconds
        store.create_invite(
            invite_id=invite_id,
            code_hash=hash_invite_code(code),
            created_by=user["user_id"],
            expires_at=expires_at,
            created_at=now,
        )
        return {
            "invite_id": invite_id,
            "code": code,
            "created_at": now,
            "expires_at": expires_at,
            "expires_in_seconds": request.expires_in_seconds,
        }

    @router.get("/invites")
    def list_invites(
        user: dict[str, Any] = Depends(current_user),
    ) -> list[dict[str, Any]]:
        require_owner(user)
        return store.list_invites()

    @router.delete("/invites/{invite_id}", status_code=204)
    def revoke_invite(
        invite_id: str,
        user: dict[str, Any] = Depends(current_user),
    ) -> Response:
        require_owner(user)
        if not store.revoke_invite(invite_id):
            raise HTTPException(status_code=404, detail="Active invitation not found.")
        return Response(status_code=204)

    @router.get("/me")
    def get_current_user(user: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
        return user

    @router.post("/logout", status_code=204)
    def logout(
        credentials: HTTPAuthorizationCredentials | None = Depends(bearer),
    ) -> Response:
        if credentials is not None and credentials.scheme.lower() == "bearer":
            store.revoke_session(hash_session_token(credentials.credentials))
        return Response(status_code=204)

    return router, current_user