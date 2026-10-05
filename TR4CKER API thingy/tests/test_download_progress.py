import unittest
from pathlib import Path
from tempfile import TemporaryDirectory

from download_progress import normalize_aria2_status
from torrent_cleanup import aria2_sidecar_paths, delete_aria2_sidecars


class Aria2ProgressTests(unittest.TestCase):
    def test_active_download_reports_fraction_bytes_speed_and_eta(self) -> None:
        progress = normalize_aria2_status(
            {
                "status": "active",
                "totalLength": "1000",
                "completedLength": "250",
                "downloadSpeed": "50",
                "errorCode": "0",
            }
        )

        self.assertEqual(progress["status"], "running")
        self.assertEqual(progress["phase"], "downloading")
        self.assertEqual(progress["progress"], 0.25)
        self.assertEqual(progress["downloaded_bytes"], 250)
        self.assertEqual(progress["total_bytes"], 1000)
        self.assertEqual(progress["download_speed"], 50)
        self.assertEqual(progress["eta_seconds"], 15)

    def test_completed_download_reports_full_progress(self) -> None:
        progress = normalize_aria2_status(
            {
                "status": "complete",
                "totalLength": "1000",
                "completedLength": "1000",
                "downloadSpeed": "0",
                "errorCode": "0",
            }
        )

        self.assertEqual(progress["status"], "completed")
        self.assertEqual(progress["progress"], 1.0)
        self.assertEqual(progress["eta_seconds"], 0)

    def test_unknown_total_is_indeterminate_and_errors_are_failed(self) -> None:
        indeterminate = normalize_aria2_status(
            {
                "status": "active",
                "totalLength": "0",
                "completedLength": "0",
                "downloadSpeed": "0",
            }
        )
        failed = normalize_aria2_status(
            {
                "status": "error",
                "errorCode": "3",
                "errorMessage": "network failure",
            }
        )

        self.assertIsNone(indeterminate["progress"])
        self.assertEqual(indeterminate["phase"], "downloading")
        self.assertEqual(failed["status"], "failed")
        self.assertEqual(failed["phase"], "failed")
        self.assertNotIn("errorMessage", failed)

    def test_completed_aria2_cleanup_removes_tracked_sidecars_only(self) -> None:
        with TemporaryDirectory() as directory:
            root = Path(directory) / "Books"
            book = root / "book.epub"
            sidecar = Path(f"{book}.aria2")
            book.parent.mkdir(parents=True)
            book.write_bytes(b"completed book")
            sidecar.write_text("aria2 state", encoding="utf-8")
            status = normalize_aria2_status(
                {
                    "status": "complete",
                    "totalLength": "100",
                    "completedLength": "100",
                    "downloadSpeed": "0",
                    "errorCode": "0",
                }
            )

            if status["status"] == "completed":
                tracked = aria2_sidecar_paths([str(book)], [root])
                delete_aria2_sidecars(tracked, [root])

            self.assertFalse(sidecar.exists())
            self.assertTrue(book.exists())

    def test_incomplete_aria2_job_preserves_its_sidecar(self) -> None:
        with TemporaryDirectory() as directory:
            root = Path(directory) / "Audiobooks"
            book = root / "book.m4b"
            sidecar = Path(f"{book}.aria2")
            sidecar.parent.mkdir(parents=True)
            sidecar.write_text("resume state", encoding="utf-8")
            status = normalize_aria2_status(
                {
                    "status": "active",
                    "totalLength": "100",
                    "completedLength": "50",
                    "downloadSpeed": "10",
                    "errorCode": "0",
                }
            )

            if status["status"] == "completed":
                delete_aria2_sidecars([str(sidecar)], [root])

            self.assertEqual(status["status"], "running")
            self.assertTrue(sidecar.exists())


if __name__ == "__main__":
    unittest.main()
