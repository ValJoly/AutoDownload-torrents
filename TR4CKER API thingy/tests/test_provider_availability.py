import importlib
import os
import unittest
from unittest.mock import Mock, patch

from fastapi.testclient import TestClient

from auth_store import AuthStore


class ProviderAvailabilityTests(unittest.TestCase):
    def test_endpoint_reports_configured_sources_without_exposing_keys(self) -> None:
        auth_store = Mock()
        auth_store.list_completed_download_job_cleanup_artifacts.return_value = []
        auth_store.reconcile_startup_jobs.return_value = 0
        with (
            patch.dict(
                os.environ,
                {
                    "TR4CKER_API_KEY": "tracker-secret",
                    "C411_API_KEY": "",
                },
            ),
            patch.object(AuthStore, "from_environment", return_value=auth_store),
        ):
            import main

            main = importlib.reload(main)
            with TestClient(main.app) as client:
                unavailable = client.get("/api/providers")
                os.environ["C411_API_KEY"] = "c411-secret"
                available = client.get("/api/providers")

        self.assertEqual(unavailable.json(), {"tr4cker": True, "c411": False})
        self.assertEqual(available.json(), {"tr4cker": True, "c411": True})
        self.assertNotIn("tracker-secret", available.text)
        self.assertNotIn("c411-secret", available.text)


if __name__ == "__main__":
    unittest.main()
