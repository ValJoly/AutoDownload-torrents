from __future__ import annotations

import os
import re
import time
from contextlib import contextmanager
from typing import Any, Iterator

import psycopg
from psycopg.rows import dict_row


_MIGRATIONS = {
    1: (
        """CREATE TABLE users (
            id TEXT PRIMARY KEY,
            username TEXT NOT NULL CHECK (length(trim(username)) BETWEEN 1 AND 64),
            password_hash TEXT NOT NULL,
            role TEXT NOT NULL CHECK (role IN ('owner', 'member')),
            created_at DOUBLE PRECISION NOT NULL,
            disabled_at DOUBLE PRECISION
        )""",
        "CREATE UNIQUE INDEX users_username_lower_idx ON users (lower(username))",
        """CREATE TABLE sessions (
            token_hash TEXT PRIMARY KEY,
            user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            created_at DOUBLE PRECISION NOT NULL,
            expires_at DOUBLE PRECISION NOT NULL,
            revoked_at DOUBLE PRECISION
        )""",
        "CREATE INDEX sessions_user_id_idx ON sessions(user_id)",
        """CREATE TABLE invites (
            invite_id TEXT PRIMARY KEY,
            code_hash TEXT NOT NULL UNIQUE,
            created_by TEXT NOT NULL REFERENCES users(id),
            created_at DOUBLE PRECISION NOT NULL,
            expires_at DOUBLE PRECISION NOT NULL,
            consumed_at DOUBLE PRECISION,
            revoked_at DOUBLE PRECISION
        )""",
        "CREATE INDEX invites_created_by_idx ON invites(created_by)",
    ),
    2: (
        """CREATE TABLE download_jobs (
            job_id TEXT PRIMARY KEY,
            owner_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            slug TEXT NOT NULL,
            info TEXT NOT NULL DEFAULT '',
            download_dir TEXT NOT NULL DEFAULT '',
            client TEXT NOT NULL DEFAULT 'pending',
            status TEXT NOT NULL DEFAULT 'preparing',
            phase TEXT NOT NULL DEFAULT 'preparing',
            message TEXT,
            progress DOUBLE PRECISION,
            downloaded_bytes BIGINT NOT NULL DEFAULT 0,
            total_bytes BIGINT,
            download_speed BIGINT NOT NULL DEFAULT 0,
            eta_seconds BIGINT,
            created_at DOUBLE PRECISION NOT NULL,
            updated_at DOUBLE PRECISION NOT NULL
        )""",
        "CREATE INDEX download_jobs_owner_idx ON download_jobs(owner_id, updated_at DESC)",
    ),
}


class AuthStore:
    @classmethod
    def from_environment(cls) -> AuthStore:
        database_url = os.getenv("SKYFORGE_DATABASE_URL")
        if not database_url:
            raise RuntimeError("Missing SKYFORGE_DATABASE_URL.")
        return cls(
            database_url,
            schema=os.getenv("SKYFORGE_DATABASE_SCHEMA", "public"),
        )

    def __init__(self, database_url: str, *, schema: str = "public") -> None:
        if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", schema):
            raise ValueError("Invalid PostgreSQL schema name.")
        self.database_url = database_url
        self.schema = schema
        self._migrate()

    @contextmanager
    def _connect(self) -> Iterator[psycopg.Connection[dict[str, Any]]]:
        with psycopg.connect(self.database_url, row_factory=dict_row) as connection:
            connection.execute(f'SET search_path TO "{self.schema}"')
            yield connection

    def _migrate(self) -> None:
        with self._connect() as connection:
            connection.execute(
                """CREATE TABLE IF NOT EXISTS schema_migrations (
                    version INTEGER PRIMARY KEY,
                    applied_at DOUBLE PRECISION NOT NULL
                )"""
            )
            current = connection.execute(
                "SELECT COALESCE(MAX(version), 0) AS version FROM schema_migrations"
            ).fetchone()["version"]
            if current > max(_MIGRATIONS):
                raise RuntimeError("The auth database was created by a newer version.")
            for version, statements in _MIGRATIONS.items():
                if version <= current:
                    continue
                with connection.transaction():
                    for statement in statements:
                        connection.execute(statement)
                    connection.execute(
                        "INSERT INTO schema_migrations (version, applied_at) VALUES (%s, %s)",
                        (version, time.time()),
                    )

    def create_user(
        self,
        *,
        user_id: str,
        username: str,
        password_hash: str,
        role: str,
    ) -> None:
        with self._connect() as connection:
            connection.execute(
                """INSERT INTO users (id, username, password_hash, role, created_at)
                   VALUES (%s, %s, %s, %s, %s)""",
                (user_id, username.strip(), password_hash, role, time.time()),
            )

    def create_initial_owner(
        self, *, user_id: str, username: str, password_hash: str
    ) -> bool:
        with self._connect() as connection:
            with connection.transaction():
                connection.execute("LOCK TABLE users IN EXCLUSIVE MODE")
                if connection.execute("SELECT 1 FROM users LIMIT 1").fetchone():
                    return False
                connection.execute(
                    """INSERT INTO users
                       (id, username, password_hash, role, created_at)
                       VALUES (%s, %s, %s, 'owner', %s)""",
                    (user_id, username.strip(), password_hash, time.time()),
                )
        return True

    def get_user_by_username(self, username: str) -> dict[str, Any] | None:
        with self._connect() as connection:
            row = connection.execute(
                "SELECT * FROM users WHERE lower(username) = lower(%s)",
                (username.strip(),),
            ).fetchone()
        return row

    def create_session(
        self,
        token_hash: str,
        user_id: str,
        *,
        expires_at: float,
        created_at: float | None = None,
    ) -> None:
        with self._connect() as connection:
            connection.execute(
                """INSERT INTO sessions (token_hash, user_id, created_at, expires_at)
                   VALUES (%s, %s, %s, %s)""",
                (
                    token_hash,
                    user_id,
                    created_at if created_at is not None else time.time(),
                    expires_at,
                ),
            )

    def get_active_session(
        self, token_hash: str, *, now: float | None = None
    ) -> dict[str, Any] | None:
        with self._connect() as connection:
            row = connection.execute(
                """SELECT sessions.user_id, users.username, users.role
                   FROM sessions JOIN users ON users.id = sessions.user_id
                   WHERE sessions.token_hash = %s
                     AND sessions.revoked_at IS NULL
                     AND sessions.expires_at > %s
                     AND users.disabled_at IS NULL""",
                (token_hash, now if now is not None else time.time()),
            ).fetchone()
        return row

    def revoke_session(
        self, token_hash: str, *, revoked_at: float | None = None
    ) -> None:
        with self._connect() as connection:
            connection.execute(
                """UPDATE sessions SET revoked_at = %s
                   WHERE token_hash = %s AND revoked_at IS NULL""",
                (revoked_at if revoked_at is not None else time.time(), token_hash),
            )

    def create_invite(
        self,
        *,
        invite_id: str,
        code_hash: str,
        created_by: str,
        expires_at: float,
        created_at: float | None = None,
    ) -> None:
        with self._connect() as connection:
            connection.execute(
                """INSERT INTO invites
                   (invite_id, code_hash, created_by, created_at, expires_at)
                   VALUES (%s, %s, %s, %s, %s)""",
                (
                    invite_id,
                    code_hash,
                    created_by,
                    created_at if created_at is not None else time.time(),
                    expires_at,
                ),
            )

    def list_invites(self, *, now: float | None = None) -> list[dict[str, Any]]:
        current_time = now if now is not None else time.time()
        with self._connect() as connection:
            rows = connection.execute(
                """SELECT invite_id, created_by, created_at, expires_at,
                          consumed_at, revoked_at,
                          CASE
                            WHEN consumed_at IS NOT NULL THEN 'consumed'
                            WHEN revoked_at IS NOT NULL THEN 'revoked'
                            WHEN expires_at <= %s THEN 'expired'
                            ELSE 'active'
                          END AS status
                   FROM invites ORDER BY created_at DESC""",
                (current_time,),
            ).fetchall()
        return rows

    def revoke_invite(self, invite_id: str, *, revoked_at: float | None = None) -> bool:
        current_time = revoked_at if revoked_at is not None else time.time()
        with self._connect() as connection:
            result = connection.execute(
                """UPDATE invites SET revoked_at = %s
                   WHERE invite_id = %s AND consumed_at IS NULL AND revoked_at IS NULL
                     AND expires_at > %s""",
                (current_time, invite_id, current_time),
            )
        return result.rowcount == 1

    def redeem_invite(
        self,
        *,
        code_hash: str,
        user_id: str,
        username: str,
        password_hash: str,
        session_token_hash: str,
        session_expires_at: float,
        now: float | None = None,
    ) -> tuple[str, dict[str, Any] | None]:
        current_time = now if now is not None else time.time()
        with self._connect() as connection:
            with connection.transaction():
                invite = connection.execute(
                    """SELECT invite_id FROM invites
                       WHERE code_hash = %s AND consumed_at IS NULL
                         AND revoked_at IS NULL AND expires_at > %s
                       FOR UPDATE""",
                    (code_hash, current_time),
                ).fetchone()
                if invite is None:
                    return "invalid_invite", None

                inserted = connection.execute(
                    """INSERT INTO users
                       (id, username, password_hash, role, created_at)
                       VALUES (%s, %s, %s, 'member', %s)
                       ON CONFLICT DO NOTHING
                       RETURNING id""",
                    (user_id, username.strip(), password_hash, current_time),
                ).fetchone()
                if inserted is None:
                    return "username_taken", None

                connection.execute(
                    "UPDATE invites SET consumed_at = %s WHERE invite_id = %s",
                    (current_time, invite["invite_id"]),
                )
                connection.execute(
                    """INSERT INTO sessions
                       (token_hash, user_id, created_at, expires_at)
                       VALUES (%s, %s, %s, %s)""",
                    (session_token_hash, user_id, current_time, session_expires_at),
                )
        return "created", {
            "id": user_id,
            "username": username.strip(),
            "role": "member",
        }

    def create_download_job(
        self,
        *,
        job_id: str,
        owner_id: str,
        slug: str,
        info: str = "",
        download_dir: str = "",
        client: str = "pending",
        status: str = "preparing",
        phase: str = "preparing",
        message: str | None = "Preparing torrent metadata.",
        progress: float | None = None,
        downloaded_bytes: int = 0,
        total_bytes: int | None = None,
        download_speed: int = 0,
        eta_seconds: int | None = None,
        created_at: float | None = None,
        updated_at: float | None = None,
    ) -> dict[str, Any]:
        now = time.time()
        c_at = created_at if created_at is not None else now
        u_at = updated_at if updated_at is not None else now
        with self._connect() as connection:
            connection.execute(
                """INSERT INTO download_jobs
                   (job_id, owner_id, slug, info, download_dir, client,
                    status, phase, message, progress, downloaded_bytes,
                    total_bytes, download_speed, eta_seconds, created_at, updated_at)
                   VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)""",
                (
                    job_id,
                    owner_id,
                    slug,
                    info,
                    download_dir,
                    client,
                    status,
                    phase,
                    message,
                    progress,
                    downloaded_bytes,
                    total_bytes,
                    download_speed,
                    eta_seconds,
                    c_at,
                    u_at,
                ),
            )
        return {
            "job_id": job_id,
            "owner_id": owner_id,
            "slug": slug,
            "info": info,
            "download_dir": download_dir,
            "client": client,
            "status": status,
            "phase": phase,
            "message": message,
            "progress": progress,
            "downloaded_bytes": downloaded_bytes,
            "total_bytes": total_bytes,
            "download_speed": download_speed,
            "eta_seconds": eta_seconds,
            "created_at": c_at,
            "updated_at": u_at,
        }

    def update_download_job(
        self,
        job_id: str,
        *,
        updated_at: float | None = None,
        **updates: Any,
    ) -> None:
        allowed_columns = {
            "slug",
            "info",
            "download_dir",
            "client",
            "status",
            "phase",
            "message",
            "progress",
            "downloaded_bytes",
            "total_bytes",
            "download_speed",
            "eta_seconds",
        }
        filtered_updates = {k: v for k, v in updates.items() if k in allowed_columns}
        if not filtered_updates:
            return
        filtered_updates["updated_at"] = (
            updated_at if updated_at is not None else time.time()
        )
        set_clauses = [f"{col} = %s" for col in filtered_updates.keys()]
        values = list(filtered_updates.values()) + [job_id]
        with self._connect() as connection:
            connection.execute(
                f"UPDATE download_jobs SET {', '.join(set_clauses)} WHERE job_id = %s",
                tuple(values),
            )

    def get_download_job(
        self, job_id: str, owner_id: str | None = None
    ) -> dict[str, Any] | None:
        with self._connect() as connection:
            if owner_id is not None:
                row = connection.execute(
                    "SELECT * FROM download_jobs WHERE job_id = %s AND owner_id = %s",
                    (job_id, owner_id),
                ).fetchone()
            else:
                row = connection.execute(
                    "SELECT * FROM download_jobs WHERE job_id = %s",
                    (job_id,),
                ).fetchone()
        return row

    def list_download_jobs(
        self, owner_id: str, *, limit: int = 50, offset: int = 0
    ) -> list[dict[str, Any]]:
        with self._connect() as connection:
            rows = connection.execute(
                """SELECT * FROM download_jobs
                   WHERE owner_id = %s
                   ORDER BY updated_at DESC, created_at DESC, job_id DESC
                   LIMIT %s OFFSET %s""",
                (owner_id, limit, offset),
            ).fetchall()
        return rows

    def reconcile_startup_jobs(self) -> int:
        now = time.time()
        with self._connect() as connection:
            result = connection.execute(
                """UPDATE download_jobs
                   SET status = 'interrupted',
                       phase = 'interrupted',
                       message = 'Process stopped when the bridge restarted.',
                       updated_at = %s
                   WHERE status IN ('preparing', 'starting', 'running', 'queued', 'downloading')""",
                (now,),
            )
            return result.rowcount

