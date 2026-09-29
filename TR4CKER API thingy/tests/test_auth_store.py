import psycopg
from concurrent.futures import ThreadPoolExecutor

from auth_security import (
    create_session_token,
    hash_password,
    hash_invite_code,
    hash_session_token,
    verify_password,
)
from database_support import PostgresTestCase


class AuthStoreTests(PostgresTestCase):
    def setUp(self) -> None:
        super().setUp()

    def test_session_survives_store_reopen(self) -> None:
        self.store.create_session("token-hash", "user-1", expires_at=200)

        session = type(self.store)(self.database_url, schema=self.schema).get_active_session(
            "token-hash", now=100
        )

        self.assertEqual(session["username"], "owner")
        self.assertEqual(session["role"], "owner")

    def test_expired_session_is_not_active(self) -> None:
        self.store.create_session("token-hash", "user-1", expires_at=100)

        self.assertIsNone(self.store.get_active_session("token-hash", now=100))

    def test_revoked_session_is_not_active(self) -> None:
        self.store.create_session("token-hash", "user-1", expires_at=200)
        self.store.revoke_session("token-hash", revoked_at=100)

        self.assertIsNone(self.store.get_active_session("token-hash", now=101))

    def test_username_uniqueness_is_case_insensitive(self) -> None:
        with self.assertRaises(psycopg.errors.UniqueViolation):
            self.store.create_user(
                user_id="user-2",
                username="OWNER",
                password_hash="another-hash",
                role="member",
            )

    def test_initial_owner_can_only_be_created_once(self) -> None:
        _, store, schema = self.create_store()

        self.assertTrue(
            store.create_initial_owner(
                user_id="first-owner",
                username="owner",
                password_hash="hash",
            )
        )
        self.assertFalse(
            store.create_initial_owner(
                user_id="second-owner",
                username="attacker",
                password_hash="hash",
            )
        )
        self.drop_schema(schema)

    def test_password_hash_is_salted_and_verifiable(self) -> None:
        password_hash = hash_password("correct horse battery staple")

        self.assertNotEqual(password_hash, "correct horse battery staple")
        self.assertTrue(verify_password("correct horse battery staple", password_hash))
        self.assertFalse(verify_password("wrong password", password_hash))

    def test_only_session_token_hash_is_needed_for_lookup(self) -> None:
        token = create_session_token()
        token_hash = hash_session_token(token)
        self.store.create_session(token_hash, "user-1", expires_at=200)

        session = self.store.get_active_session(token_hash, now=100)

        self.assertTrue(token)
        self.assertEqual(session["user_id"], "user-1")

    def test_invite_code_is_stored_only_as_hash_and_can_be_revoked(self) -> None:
        code = "high-entropy-invite"
        self.store.create_invite(
            invite_id="invite-1",
            code_hash=hash_invite_code(code),
            created_by="user-1",
            created_at=10,
            expires_at=100,
        )

        invite = self.store.list_invites(now=50)[0]
        with self.store._connect() as connection:
            stored = connection.execute(
                "SELECT code_hash FROM invites WHERE invite_id = %s",
                ("invite-1",),
            ).fetchone()["code_hash"]

        self.assertEqual(invite["status"], "active")
        self.assertNotIn("code_hash", invite)
        self.assertNotEqual(stored, code)
        self.assertTrue(self.store.revoke_invite("invite-1", revoked_at=60))
        self.assertEqual(self.store.list_invites(now=60)[0]["status"], "revoked")
        self.assertFalse(self.store.revoke_invite("invite-1", revoked_at=70))

    def test_invite_redemption_is_single_use_and_creates_session_atomically(self) -> None:
        self.store.create_invite(
            invite_id="invite-1",
            code_hash="code-hash",
            created_by="user-1",
            created_at=10,
            expires_at=200,
        )

        status, user = self.store.redeem_invite(
            code_hash="code-hash",
            user_id="user-2",
            username="member",
            password_hash="password-hash",
            session_token_hash="session-hash",
            session_expires_at=300,
            now=100,
        )
        repeated_status, repeated_user = self.store.redeem_invite(
            code_hash="code-hash",
            user_id="user-3",
            username="other-member",
            password_hash="password-hash",
            session_token_hash="other-session-hash",
            session_expires_at=300,
            now=101,
        )

        self.assertEqual(status, "created")
        self.assertEqual(user["role"], "member")
        self.assertEqual(self.store.get_active_session("session-hash", now=101)["user_id"], "user-2")
        self.assertEqual(repeated_status, "invalid_invite")
        self.assertIsNone(repeated_user)

    def test_concurrent_invite_redemption_creates_only_one_member(self) -> None:
        self.store.create_invite(
            invite_id="invite-race",
            code_hash="race-code-hash",
            created_by="user-1",
            created_at=10,
            expires_at=200,
        )

        def redeem(suffix: str) -> str:
            status, _ = self.store.redeem_invite(
                code_hash="race-code-hash",
                user_id=f"user-{suffix}",
                username=f"member-{suffix}",
                password_hash="password-hash",
                session_token_hash=f"session-{suffix}",
                session_expires_at=300,
                now=100,
            )
            return status

        with ThreadPoolExecutor(max_workers=2) as executor:
            outcomes = list(executor.map(redeem, ("a", "b")))

        self.assertCountEqual(outcomes, ["created", "invalid_invite"])
        with self.store._connect() as connection:
            members = connection.execute(
                "SELECT count(*) AS count FROM users WHERE role = 'member'"
            ).fetchone()["count"]
        self.assertEqual(members, 1)

    def test_username_conflict_does_not_consume_invite(self) -> None:
        self.store.create_invite(
            invite_id="invite-1",
            code_hash="code-hash",
            created_by="user-1",
            created_at=10,
            expires_at=200,
        )

        status, user = self.store.redeem_invite(
            code_hash="code-hash",
            user_id="user-2",
            username="OWNER",
            password_hash="password-hash",
            session_token_hash="session-hash",
            session_expires_at=300,
            now=100,
        )

        self.assertEqual(status, "username_taken")
        self.assertIsNone(user)
        self.assertEqual(self.store.list_invites(now=100)[0]["status"], "active")

    def test_schema_migration_is_versioned(self) -> None:
        with self.store._connect() as connection:
            version = connection.execute(
                "SELECT MAX(version) AS version FROM schema_migrations"
            ).fetchone()["version"]

        self.assertEqual(version, 1)


if __name__ == "__main__":
    unittest.main()