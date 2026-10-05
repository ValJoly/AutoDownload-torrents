import importlib
import os
import tempfile
import psycopg
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
from unittest.mock import patch

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

        self.assertEqual(version, 3)

    def test_cleanup_artifacts_are_persisted_and_listed_only_for_completed_jobs(self) -> None:
        for job_id, status in (
            ("job-completed", "completed"),
            ("job-interrupted", "interrupted"),
        ):
            self.store.create_download_job(
                job_id=job_id,
                owner_id="user-1",
                slug=job_id,
                download_dir="/downloads/Books",
                status=status,
            )
            self.store.set_download_job_cleanup_artifacts(
                job_id,
                ["/downloads/Books/book.epub.aria2"],
            )

        artifacts = self.store.list_completed_download_job_cleanup_artifacts()

        self.assertEqual(
            artifacts,
            [
                {
                    "job_id": "job-completed",
                    "download_dir": "/downloads/Books",
                    "path": "/downloads/Books/book.epub.aria2",
                }
            ],
        )
        self.store.clear_download_job_cleanup_artifacts("job-completed")
        self.assertEqual(self.store.list_completed_download_job_cleanup_artifacts(), [])

    def test_startup_cleans_completed_owned_sidecars_only(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            books = Path(directory) / "Books"
            books.mkdir()
            completed_sidecar = books / "completed.epub.aria2"
            interrupted_sidecar = books / "interrupted.epub.aria2"
            untracked_torrent = books / "manual.torrent"
            for path in (completed_sidecar, interrupted_sidecar, untracked_torrent):
                path.write_text("test artifact", encoding="utf-8")

            for job_id, status, sidecar in (
                ("job-cleanup-completed", "completed", completed_sidecar),
                ("job-cleanup-interrupted", "running", interrupted_sidecar),
            ):
                self.store.create_download_job(
                    job_id=job_id,
                    owner_id="user-1",
                    slug=job_id,
                    download_dir=str(books),
                    status=status,
                )
                self.store.set_download_job_cleanup_artifacts(
                    job_id, [str(sidecar)]
                )

            with patch.dict(
                os.environ,
                {
                    "TR4CKER_API_KEY": "test-api-key",
                    "SKYFORGE_DATABASE_URL": self.database_url,
                    "SKYFORGE_DATABASE_SCHEMA": self.schema,
                    "TORRENT_DOWNLOAD_DIR": directory,
                    "BOOKS": "Books",
                    "AUDIOBOOKS": "Audiobooks",
                },
            ):
                import main

                importlib.reload(main)

            self.assertFalse(completed_sidecar.exists())
            self.assertTrue(interrupted_sidecar.exists())
            self.assertTrue(untracked_torrent.exists())
            self.assertEqual(
                self.store.get_download_job("job-cleanup-interrupted")["status"],
                "interrupted",
            )

    def test_download_jobs_crud_and_owner_isolation(self) -> None:
        self.store.create_user(
            user_id="user-2",
            username="other-user",
            password_hash="hash",
            role="member",
        )
        job1 = self.store.create_download_job(
            job_id="job-1",
            owner_id="user-1",
            slug="slug-1",
            info="Book One",
            status="preparing",
            created_at=10,
            updated_at=10,
        )
        job2 = self.store.create_download_job(
            job_id="job-2",
            owner_id="user-1",
            slug="slug-2",
            info="Audiobook Two",
            status="running",
            created_at=20,
            updated_at=20,
        )
        self.store.create_download_job(
            job_id="job-3",
            owner_id="user-2",
            slug="slug-3",
            info="Book Three",
            status="running",
            created_at=30,
            updated_at=30,
        )

        user1_jobs = self.store.list_download_jobs("user-1")
        self.assertEqual(len(user1_jobs), 2)
        self.assertEqual([j["job_id"] for j in user1_jobs], ["job-2", "job-1"])
        self.assertEqual(user1_jobs[0]["info"], "Audiobook Two")

        user2_jobs = self.store.list_download_jobs("user-2")
        self.assertEqual(len(user2_jobs), 1)
        self.assertEqual(user2_jobs[0]["job_id"], "job-3")

        self.store.update_download_job(
            "job-1",
            status="completed",
            phase="completed",
            progress=1.0,
            downloaded_bytes=1000,
            total_bytes=1000,
            updated_at=40,
        )
        updated_job = self.store.get_download_job("job-1", owner_id="user-1")
        self.assertIsNotNone(updated_job)
        self.assertEqual(updated_job["status"], "completed")
        self.assertEqual(updated_job["progress"], 1.0)
        self.assertEqual(updated_job["downloaded_bytes"], 1000)

        # Confirm job-1 is now top of the list because updated_at was set to 40
        user1_jobs_after_update = self.store.list_download_jobs("user-1")
        self.assertEqual([j["job_id"] for j in user1_jobs_after_update], ["job-1", "job-2"])

        # Cannot get job-3 when querying as user-1
        self.assertIsNone(self.store.get_download_job("job-3", owner_id="user-1"))

    def test_download_job_listing_supports_offset_pagination(self) -> None:
        for index in range(5):
            self.store.create_download_job(
                job_id=f"page-job-{index}",
                owner_id="user-1",
                slug=f"slug-{index}",
                status="completed",
                created_at=index,
                updated_at=index,
            )

        first_page = self.store.list_download_jobs("user-1", limit=2, offset=0)
        second_page = self.store.list_download_jobs("user-1", limit=2, offset=2)

        self.assertEqual([job["job_id"] for job in first_page], ["page-job-4", "page-job-3"])
        self.assertEqual([job["job_id"] for job in second_page], ["page-job-2", "page-job-1"])

    def test_reconcile_startup_jobs_marks_active_jobs_as_interrupted(self) -> None:
        self.store.create_download_job(
            job_id="job-running",
            owner_id="user-1",
            slug="slug-1",
            status="running",
            phase="downloading",
        )
        self.store.create_download_job(
            job_id="job-completed",
            owner_id="user-1",
            slug="slug-2",
            status="completed",
            phase="completed",
        )
        self.store.create_download_job(
            job_id="job-preparing",
            owner_id="user-1",
            slug="slug-3",
            status="preparing",
            phase="preparing",
        )

        reconciled_count = self.store.reconcile_startup_jobs()
        self.assertEqual(reconciled_count, 2)

        running_job = self.store.get_download_job("job-running")
        completed_job = self.store.get_download_job("job-completed")
        preparing_job = self.store.get_download_job("job-preparing")

        self.assertEqual(running_job["status"], "interrupted")
        self.assertEqual(running_job["phase"], "interrupted")
        self.assertEqual(completed_job["status"], "completed")
        self.assertEqual(preparing_job["status"], "interrupted")


if __name__ == "__main__":
    unittest.main()