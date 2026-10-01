import importlib
import os
import unittest
from unittest.mock import patch

from fastapi import BackgroundTasks, Depends, FastAPI
from fastapi.testclient import TestClient

from auth_api import create_auth_api
from auth_security import hash_password
from database_support import PostgresTestCase


class AuthApiTests(PostgresTestCase):
    def setUp(self) -> None:
        super().setUp()
        self.app = FastAPI()
        auth_router, current_user = create_auth_api(self.store)
        self.app.include_router(auth_router)

        @self.app.get("/protected")
        def protected(user=Depends(current_user)):
            return {"username": user["username"]}

        self.client = TestClient(self.app)

    def tearDown(self) -> None:
        self.client.close()
        super().tearDown()

    def test_login_token_authenticates_and_logout_revokes_it(self) -> None:
        login = self.client.post(
            "/api/auth/login",
            json={"username": "owner", "password": "correct horse battery staple"},
        )
        self.assertEqual(login.status_code, 200)
        self.assertNotIn("password_hash", login.json())
        token = login.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}

        self.assertEqual(self.client.get("/protected", headers=headers).status_code, 200)
        self.assertEqual(self.client.get("/api/auth/me", headers=headers).json()["username"], "owner")
        self.assertEqual(self.client.post("/api/auth/logout", headers=headers).status_code, 204)
        self.assertEqual(self.client.get("/protected", headers=headers).status_code, 401)

    def test_login_rejects_invalid_credentials(self) -> None:
        response = self.client.post(
            "/api/auth/login", json={"username": "owner", "password": "wrong"}
        )

        self.assertEqual(response.status_code, 401)
        self.assertEqual(response.json()["detail"], "Invalid username or password.")

    def test_owner_can_create_and_list_invites_without_hash_disclosure(self) -> None:
        login = self.client.post(
            "/api/auth/login",
            json={"username": "owner", "password": "correct horse battery staple"},
        )
        headers = {"Authorization": f"Bearer {login.json()['access_token']}"}

        created = self.client.post(
            "/api/auth/invites",
            headers=headers,
            json={"expires_in_seconds": 3600},
        )
        listed = self.client.get("/api/auth/invites", headers=headers)

        self.assertEqual(created.status_code, 201)
        self.assertTrue(created.json()["code"])
        self.assertEqual(created.json()["expires_in_seconds"], 3600)
        self.assertEqual(listed.status_code, 200)
        self.assertEqual(len(listed.json()), 1)
        self.assertNotIn("code", listed.text)
        self.assertNotIn("token_hash", listed.text)
        self.assertNotIn("invite_hash", listed.text)

    def test_invite_registration_creates_member_session_and_consumes_code(self) -> None:
        owner_login = self.client.post(
            "/api/auth/login",
            json={"username": "owner", "password": "correct horse battery staple"},
        )
        owner_headers = {
            "Authorization": f"Bearer {owner_login.json()['access_token']}"
        }
        invite = self.client.post(
            "/api/auth/invites", headers=owner_headers, json={}
        ).json()

        registered = self.client.post(
            "/api/auth/register",
            json={
                "code": invite["code"],
                "username": "new-member",
                "password": "correct horse battery staple",
            },
        )
        token = registered.json()["access_token"]
        member_headers = {"Authorization": f"Bearer {token}"}
        current_user = self.client.get("/api/auth/me", headers=member_headers)
        reused = self.client.post(
            "/api/auth/register",
            json={
                "code": invite["code"],
                "username": "another-member",
                "password": "correct horse battery staple",
            },
        )

        self.assertEqual(registered.status_code, 201)
        self.assertEqual(registered.json()["user"]["role"], "member")
        self.assertEqual(current_user.status_code, 200)
        self.assertEqual(current_user.json()["username"], "new-member")
        self.assertEqual(reused.status_code, 400)

    def test_member_cannot_manage_invites_and_can_redeem_invite(self) -> None:
        owner_login = self.client.post(
            "/api/auth/login",
            json={"username": "owner", "password": "correct horse battery staple"},
        )
        owner_headers = {
            "Authorization": f"Bearer {owner_login.json()['access_token']}"
        }
        invite = self.client.post(
            "/api/auth/invites", headers=owner_headers, json={}
        ).json()
        registered = self.client.post(
            "/api/auth/register",
            json={
                "code": invite["code"],
                "username": "member",
                "password": "correct horse battery staple",
            },
        )
        member_headers = {
            "Authorization": f"Bearer {registered.json()['access_token']}"
        }

        self.assertEqual(
            self.client.post("/api/auth/invites", headers=member_headers, json={}).status_code,
            403,
        )
        self.assertEqual(self.client.get("/api/auth/invites", headers=member_headers).status_code, 403)

    def test_owner_can_revoke_invite_and_reject_invalid_registration(self) -> None:
        login = self.client.post(
            "/api/auth/login",
            json={"username": "owner", "password": "correct horse battery staple"},
        )
        headers = {"Authorization": f"Bearer {login.json()['access_token']}"}
        invite = self.client.post(
            "/api/auth/invites", headers=headers, json={}
        ).json()

        revoked = self.client.delete(
            f"/api/auth/invites/{invite['invite_id']}", headers=headers
        )
        rejected = self.client.post(
            "/api/auth/register",
            json={
                "code": invite["code"],
                "username": "member",
                "password": "correct horse battery staple",
            },
        )

        self.assertEqual(revoked.status_code, 204)
        self.assertEqual(rejected.status_code, 400)

    def test_registration_rejects_whitespace_username_and_short_password(self) -> None:
        for payload in (
            {"code": "unused", "username": "   ", "password": "long enough password"},
            {"code": "unused", "username": "valid-name", "password": "short"},
        ):
            with self.subTest(payload=payload):
                response = self.client.post("/api/auth/register", json=payload)
                self.assertEqual(response.status_code, 422)

    def test_non_ascii_invite_attempt_is_rejected_without_server_error(self) -> None:
        response = self.client.post(
            "/api/auth/register",
            json={
                "code": "招待コード",
                "username": "member",
                "password": "correct horse battery staple",
            },
        )

        self.assertEqual(response.status_code, 400)

    def test_protected_route_rejects_missing_bearer_token(self) -> None:
        self.assertEqual(self.client.get("/protected").status_code, 401)

    def test_existing_bridge_routes_require_a_bearer_session(self) -> None:
        database_url, bridge_store, schema = self.create_store()
        bridge_store.create_initial_owner(
            user_id="bridge-owner",
            username="owner",
            password_hash=hash_password("correct horse battery staple"),
        )
        with patch.dict(
            os.environ,
            {
                "TR4CKER_API_KEY": "test-api-key",
                "SKYFORGE_DATABASE_URL": database_url,
                "SKYFORGE_DATABASE_SCHEMA": schema,
            },
        ):
            import main

            main = importlib.reload(main)
            with TestClient(main.app) as client:
                unauthorized = client.get("/api/downloads/missing-job")
                login = client.post(
                    "/api/auth/login",
                    json={
                        "username": "owner",
                        "password": "correct horse battery staple",
                    },
                )
                token = login.json()["access_token"]
                authorized = client.get(
                    "/api/downloads/missing-job",
                    headers={"Authorization": f"Bearer {token}"},
                )
        self.drop_schema(schema)

        self.assertEqual(unauthorized.status_code, 401)
        self.assertEqual(login.status_code, 200)
        self.assertEqual(authorized.status_code, 404)

    def test_launch_queues_preparation_and_returns_a_job_immediately(self) -> None:
        database_url, bridge_store, schema = self.create_store()
        bridge_store.create_initial_owner(
            user_id="bridge-owner",
            username="owner",
            password_hash=hash_password("correct horse battery staple"),
        )
        with patch.dict(
            os.environ,
            {
                "TR4CKER_API_KEY": "test-api-key",
                "SKYFORGE_DATABASE_URL": database_url,
                "SKYFORGE_DATABASE_SCHEMA": schema,
            },
        ):
            import main

            main = importlib.reload(main)
            background_tasks = BackgroundTasks()
            with patch.object(main, "_prepare_and_launch_download") as prepare:
                response = main.launch_torrent_download(
                    "sample-torrent",
                    background_tasks,
                    main.LaunchTorrentBody(library="books"),
                    {"user_id": "bridge-owner"},
                )

        self.drop_schema(schema)
        self.assertEqual(response["status"], "preparing")
        self.assertEqual(response["phase"], "preparing")
        self.assertTrue(response["job_id"])
        self.assertNotIn("owner_id", response)
        prepare.assert_not_called()
        self.assertEqual(len(background_tasks.tasks), 1)
        self.assertEqual(
            background_tasks.tasks[0].args[1:],
            ("sample-torrent", "books"),
        )

    def test_download_status_is_visible_only_to_the_job_owner(self) -> None:
        database_url, bridge_store, schema = self.create_store()
        bridge_store.create_initial_owner(
            user_id="bridge-owner",
            username="bridge-owner",
            password_hash=hash_password("correct horse battery staple"),
        )
        bridge_store.create_user(
            user_id="bridge-member",
            username="bridge-member",
            password_hash=hash_password("correct horse battery staple"),
            role="member",
        )
        with patch.dict(
            os.environ,
            {
                "TR4CKER_API_KEY": "test-api-key",
                "SKYFORGE_DATABASE_URL": database_url,
                "SKYFORGE_DATABASE_SCHEMA": schema,
            },
        ):
            import main

            main = importlib.reload(main)
            job = main.register_download_job(
                owner_id="bridge-owner",
                slug="sample-torrent",
                status="running",
                phase="downloading",
                client="configured",
            )
            with main.download_jobs_lock:
                main.download_jobs[job["job_id"]].update(
                    _aria2_port=6800,
                    _aria2_secret="must-not-leak",
                    _aria2_gid="internal-gid",
                )

            class SuccessfulLauncher:
                def wait(self) -> int:
                    return 0

            main.monitor_download_job(job["job_id"], SuccessfulLauncher())
            with TestClient(main.app) as client:
                owner_login = client.post(
                    "/api/auth/login",
                    json={
                        "username": "bridge-owner",
                        "password": "correct horse battery staple",
                    },
                )
                member_login = client.post(
                    "/api/auth/login",
                    json={
                        "username": "bridge-member",
                        "password": "correct horse battery staple",
                    },
                )
                owner_headers = {
                    "Authorization": f"Bearer {owner_login.json()['access_token']}"
                }
                member_headers = {
                    "Authorization": f"Bearer {member_login.json()['access_token']}"
                }
                own_job = client.get(
                    f"/api/downloads/{job['job_id']}", headers=owner_headers
                )
                other_job = client.get(
                    f"/api/downloads/{job['job_id']}", headers=member_headers
                )
        self.drop_schema(schema)

        self.assertEqual(own_job.status_code, 200)
        self.assertNotIn("owner_id", own_job.json())
        self.assertNotIn("_aria2_secret", own_job.json())
        self.assertNotIn("_aria2_port", own_job.json())
        self.assertNotIn("_aria2_gid", own_job.json())
        self.assertEqual(own_job.json()["status"], "handed_off")
        self.assertEqual(other_job.status_code, 404)

    def test_list_downloads_endpoint_and_state_recovery_across_restart(self) -> None:
        database_url, bridge_store, schema = self.create_store()
        bridge_store.create_initial_owner(
            user_id="bridge-owner",
            username="bridge-owner",
            password_hash=hash_password("correct horse battery staple"),
        )
        bridge_store.create_user(
            user_id="bridge-member",
            username="bridge-member",
            password_hash=hash_password("correct horse battery staple"),
            role="member",
        )
        with patch.dict(
            os.environ,
            {
                "TR4CKER_API_KEY": "test-api-key",
                "SKYFORGE_DATABASE_URL": database_url,
                "SKYFORGE_DATABASE_SCHEMA": schema,
            },
        ):
            import main

            main = importlib.reload(main)
            job1 = main.register_download_job(
                owner_id="bridge-owner",
                slug="slug-1",
                info="Audiobook One",
                status="running",
                phase="downloading",
            )
            job2 = main.register_download_job(
                owner_id="bridge-owner",
                slug="slug-2",
                info="Ebook Two",
                status="completed",
                phase="completed",
            )
            job3 = main.register_download_job(
                owner_id="bridge-member",
                slug="slug-3",
                info="Member Book",
                status="running",
                phase="downloading",
            )

            with TestClient(main.app) as client:
                owner_login = client.post(
                    "/api/auth/login",
                    json={
                        "username": "bridge-owner",
                        "password": "correct horse battery staple",
                    },
                )
                member_login = client.post(
                    "/api/auth/login",
                    json={
                        "username": "bridge-member",
                        "password": "correct horse battery staple",
                    },
                )
                owner_token = owner_login.json()["access_token"]
                member_token = member_login.json()["access_token"]

                owner_downloads = client.get(
                    "/api/downloads",
                    headers={"Authorization": f"Bearer {owner_token}"},
                )
                self.assertEqual(owner_downloads.status_code, 200)
                owner_jobs = owner_downloads.json()
                self.assertEqual(len(owner_jobs), 2)

                owner_page = client.get(
                    "/api/downloads?limit=1&offset=1",
                    headers={"Authorization": f"Bearer {owner_token}"},
                )
                invalid_page = client.get(
                    "/api/downloads?limit=101",
                    headers={"Authorization": f"Bearer {owner_token}"},
                )
                self.assertEqual(owner_page.status_code, 200)
                self.assertEqual(len(owner_page.json()), 1)
                self.assertIn(owner_page.json()[0]["job_id"], {job1["job_id"], job2["job_id"]})
                self.assertEqual(invalid_page.status_code, 422)
                self.assertEqual(
                    {j["job_id"] for j in owner_jobs},
                    {job1["job_id"], job2["job_id"]},
                )
                self.assertNotIn("owner_id", owner_jobs[0])

                member_downloads = client.get(
                    "/api/downloads",
                    headers={"Authorization": f"Bearer {member_token}"},
                )
                self.assertEqual(member_downloads.status_code, 200)
                member_jobs = member_downloads.json()
                self.assertEqual(len(member_jobs), 1)
                self.assertEqual(member_jobs[0]["job_id"], job3["job_id"])

                # Simulate server restart by wiping in-memory dictionary
                with main.download_jobs_lock:
                    main.download_jobs.clear()

                recovered_status = client.get(
                    f"/api/downloads/{job1['job_id']}",
                    headers={"Authorization": f"Bearer {owner_token}"},
                )
                self.assertEqual(recovered_status.status_code, 200)
                self.assertEqual(recovered_status.json()["info"], "Audiobook One")

                recovered_list = client.get(
                    "/api/downloads",
                    headers={"Authorization": f"Bearer {owner_token}"},
                )
                self.assertEqual(recovered_list.status_code, 200)
                self.assertEqual(len(recovered_list.json()), 2)

        self.drop_schema(schema)


if __name__ == "__main__":
    unittest.main()