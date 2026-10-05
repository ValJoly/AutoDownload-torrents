import tempfile
import unittest
from pathlib import Path

from torrent_cleanup import aria2_sidecar_paths, delete_aria2_sidecars


class TorrentCleanupTests(unittest.TestCase):
    def test_derives_sidecars_only_for_outputs_inside_library_roots(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "Books"
            output = root / "nested" / "book.epub"
            outside_output = Path(directory) / "other" / "private.epub"

            paths = aria2_sidecar_paths([str(output), str(outside_output)], [root])

        self.assertEqual(paths, [str(output) + ".aria2"])

    def test_deletes_only_tracked_sidecars_under_allowed_roots(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "Audiobooks"
            outside = Path(directory) / "outside.aria2"
            sidecar = root / "book.epub.aria2"
            sidecar.parent.mkdir(parents=True)
            outside.write_text("keep", encoding="utf-8")
            sidecar.write_text("remove", encoding="utf-8")

            delete_aria2_sidecars([str(sidecar), str(outside)], [root])

            self.assertFalse(sidecar.exists())
            self.assertTrue(outside.exists())

    def test_keeps_non_sidecar_files_and_resolves_symlink_targets(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "Books"
            outside = Path(directory) / "outside.aria2"
            wrong_suffix = root / "keep.torrent"
            link = root / "linked.aria2"
            root.mkdir()
            outside.write_text("keep", encoding="utf-8")
            wrong_suffix.write_text("keep", encoding="utf-8")
            try:
                link.symlink_to(outside)
            except (OSError, NotImplementedError):
                self.skipTest("Symlinks are unavailable in this environment")

            delete_aria2_sidecars(
                [str(outside), str(wrong_suffix), str(link)], [root]
            )

            self.assertTrue(outside.exists())
            self.assertTrue(wrong_suffix.exists())
            self.assertTrue(link.is_symlink())

    def test_ignores_unresolvable_output_paths(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / "Books"
            invalid_path = str(root / "invalid\0name.epub")

            paths = aria2_sidecar_paths([invalid_path], [root])

        self.assertEqual(paths, [])


if __name__ == "__main__":
    unittest.main()