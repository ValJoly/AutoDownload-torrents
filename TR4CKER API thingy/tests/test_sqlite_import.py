from __future__ import annotations

import hashlib
import sqlite3
import tempfile
from pathlib import Path

from database_support import PostgresTestCase
from import_sqlite_auth import import_auth_data


class SqliteImportTests(PostgresTestCase):
    def _make_source(self, path: Path) -> None:
        connection = sqlite3.connect(path)
        try:
            connection.executescript(
                """
                CREATE TABLE users (
                    id TEXT PRIMARY KEY,
                    username TEXT NOT NULL,
                    password_hash TEXT NOT NULL,
                    role TEXT NOT NULL,
                    created_at REAL NOT NULL,
                    disabled_at REAL
                );
                CREATE TABLE sessions (
                    token_hash TEXT PRIMARY KEY,
                    user_id TEXT NOT NULL,
                    created_at REAL NOT NULL,
                    expires_at REAL NOT NULL,
                    revoked_at REAL
                );
                CREATE TABLE invites (
                    invite_id TEXT PRIMARY KEY,
                    code_hash TEXT NOT NULL UNIQUE,
                    created_by TEXT NOT NULL,
                    created_at REAL NOT NULL,
                    expires_at REAL NOT NULL,
                    consumed_at REAL,
                    revoked_at REAL
                );
                PRAGMA user_version = 2;
                """
            )
            connection.executemany(
                "INSERT INTO users VALUES (?, ?, ?, ?, ?, ?)",
                [
                    ("owner-1", "owner", "password-hash", "owner", 10, None),
                    ("member-1", "member", "member-hash", "member", 11, 15),
                ],
            )
            connection.execute(
                "INSERT INTO sessions VALUES (?, ?, ?, ?, NULL)",
                ("old-session-hash", "owner-1", 12, 1000),
            )
            connection.executemany(
                "INSERT INTO invites VALUES (?, ?, ?, ?, ?, ?, ?)",
                [
                    ("invite-1", "invite-hash-1", "owner-1", 20, 200, None, None),
                    ("invite-2", "invite-hash-2", "owner-1", 21, 201, 22, None),
                    ("invite-3", "invite-hash-3", "owner-1", 22, 202, None, 23),
                ],
            )
            connection.commit()
        finally:
            connection.close()

    def test_import_preserves_users_and_invites_but_not_sessions_or_source(self) -> None:
        with tempfile.TemporaryDirectory(prefix="legacy source with spaces ") as directory:
            source_path = Path(directory) / "legacy.sqlite3"
            self._make_source(source_path)
            original_hash = hashlib.sha256(source_path.read_bytes()).hexdigest()
            _, destination, schema = self.create_store()

            counts = import_auth_data(source_path, destination)

            with destination._connect() as connection:
                users = connection.execute(
                    "SELECT id, username, role, disabled_at FROM users ORDER BY id"
                ).fetchall()
                invites = connection.execute(
                    "SELECT invite_id, consumed_at, revoked_at FROM invites ORDER BY invite_id"
                ).fetchall()
                sessions = connection.execute("SELECT count(*) AS count FROM sessions").fetchone()

            self.assertEqual(counts, (2, 3))
            self.assertEqual([user["id"] for user in users], ["member-1", "owner-1"])
            self.assertEqual(users[0]["disabled_at"], 15)
            self.assertEqual(invites[1]["consumed_at"], 22)
            self.assertEqual(invites[2]["revoked_at"], 23)
            self.assertEqual(sessions["count"], 0)
            self.assertEqual(
                hashlib.sha256(source_path.read_bytes()).hexdigest(), original_hash
            )

            with self.assertRaisesRegex(RuntimeError, "not empty"):
                import_auth_data(source_path, destination)
            self.drop_schema(schema)

    def test_import_refuses_to_merge_and_rolls_back(self) -> None:
        with tempfile.TemporaryDirectory(prefix="legacy source with spaces ") as directory:
            source_path = Path(directory) / "legacy.sqlite3"
            self._make_source(source_path)

            with self.assertRaisesRegex(RuntimeError, "not empty"):
                import_auth_data(source_path, self.store)

            with self.store._connect() as connection:
                count = connection.execute("SELECT count(*) AS count FROM users").fetchone()["count"]
            self.assertEqual(count, 1)
