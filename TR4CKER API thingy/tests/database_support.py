from __future__ import annotations

import os
import unittest
import uuid

import psycopg
from psycopg import sql

from auth_security import hash_password
from auth_store import AuthStore


class PostgresTestCase(unittest.TestCase):
    def setUp(self) -> None:
        self.database_url = os.getenv("SKYFORGE_TEST_DATABASE_URL")
        if not self.database_url:
            raise unittest.SkipTest("Set SKYFORGE_TEST_DATABASE_URL to run PostgreSQL tests.")
        self.schema = f"test_{uuid.uuid4().hex}"
        with psycopg.connect(self.database_url, autocommit=True) as connection:
            connection.execute(
                sql.SQL("CREATE SCHEMA {}").format(sql.Identifier(self.schema))
            )
        self.store = AuthStore(self.database_url, schema=self.schema)
        self.store.create_user(
            user_id="user-1",
            username="owner",
            password_hash=hash_password("correct horse battery staple"),
            role="owner",
        )

    def tearDown(self) -> None:
        if getattr(self, "database_url", None) and getattr(self, "schema", None):
            with psycopg.connect(self.database_url, autocommit=True) as connection:
                connection.execute(
                    sql.SQL("DROP SCHEMA IF EXISTS {} CASCADE").format(
                        sql.Identifier(self.schema)
                    )
                )

    def create_store(self) -> tuple[str, AuthStore, str]:
        schema = f"test_{uuid.uuid4().hex}"
        with psycopg.connect(self.database_url, autocommit=True) as connection:
            connection.execute(sql.SQL("CREATE SCHEMA {}").format(sql.Identifier(schema)))
        return self.database_url, AuthStore(self.database_url, schema=schema), schema

    def drop_schema(self, schema: str) -> None:
        with psycopg.connect(self.database_url, autocommit=True) as connection:
            connection.execute(
                sql.SQL("DROP SCHEMA IF EXISTS {} CASCADE").format(sql.Identifier(schema))
            )
