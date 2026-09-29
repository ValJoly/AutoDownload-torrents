from __future__ import annotations

import argparse
import os
import sqlite3
from contextlib import closing
from pathlib import Path

from dotenv import load_dotenv

from auth_store import AuthStore


def import_auth_data(source_path: Path, store: AuthStore) -> tuple[int, int]:
    if not source_path.is_file():
        raise FileNotFoundError(f"SQLite source database not found: {source_path}")

    source_uri = f"file:{source_path.resolve().as_posix()}?mode=ro"
    with closing(sqlite3.connect(source_uri, uri=True)) as source:
        source.row_factory = sqlite3.Row
        version = source.execute("PRAGMA user_version").fetchone()[0]
        if version not in (1, 2):
            raise RuntimeError(f"Unsupported SQLite auth schema version: {version}")

        tables = {
            row[0]
            for row in source.execute(
                "SELECT name FROM sqlite_master WHERE type = 'table'"
            )
        }
        if not {"users", "sessions"}.issubset(tables):
            raise RuntimeError("SQLite source is missing auth tables.")

        users = source.execute(
            """SELECT id, username, password_hash, role, created_at, disabled_at
               FROM users ORDER BY created_at, id"""
        ).fetchall()
        invites = (
            source.execute(
                """SELECT invite_id, code_hash, created_by, created_at, expires_at,
                          consumed_at, revoked_at
                   FROM invites ORDER BY created_at, invite_id"""
            ).fetchall()
            if version >= 2 and "invites" in tables
            else []
        )

    with store._connect() as target:
        with target.transaction():
            existing = target.execute(
                """SELECT
                     EXISTS (SELECT 1 FROM users) AS users_exist,
                     EXISTS (SELECT 1 FROM invites) AS invites_exist,
                     EXISTS (SELECT 1 FROM sessions) AS sessions_exist"""
            ).fetchone()
            if any(existing.values()):
                raise RuntimeError(
                    "PostgreSQL auth tables are not empty; refusing to merge SQLite data."
                )
            for user in users:
                target.execute(
                    """INSERT INTO users
                       (id, username, password_hash, role, created_at, disabled_at)
                       VALUES (%s, %s, %s, %s, %s, %s)""",
                    tuple(user[key] for key in (
                        "id", "username", "password_hash", "role", "created_at", "disabled_at"
                    )),
                )
            for invite in invites:
                target.execute(
                    """INSERT INTO invites
                       (invite_id, code_hash, created_by, created_at, expires_at,
                        consumed_at, revoked_at)
                       VALUES (%s, %s, %s, %s, %s, %s, %s)""",
                    tuple(invite[key] for key in (
                        "invite_id", "code_hash", "created_by", "created_at",
                        "expires_at", "consumed_at", "revoked_at"
                    )),
                )
    return len(users), len(invites)


def main() -> int:
    load_dotenv(Path(__file__).with_name(".env"))
    parser = argparse.ArgumentParser(
        description="Import accounts and invitations from the legacy SQLite auth database."
    )
    parser.add_argument(
        "sqlite_path",
        nargs="?",
        default=os.getenv(
            "SKYFORGE_LEGACY_SQLITE_PATH",
            str(Path(__file__).with_name("data") / "skyforge.sqlite3"),
        ),
    )
    args = parser.parse_args()

    try:
        users, invites = import_auth_data(Path(args.sqlite_path), AuthStore.from_environment())
    except (OSError, RuntimeError, sqlite3.Error) as error:
        parser.error(str(error))
    print(f"Imported {users} user(s) and {invites} invitation(s). Existing sessions were not imported.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
