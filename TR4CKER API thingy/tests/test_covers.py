import unittest
from unittest.mock import MagicMock, patch

import requests

from legal_books import clean_cover_query, find_cover_url, pick_cover_url


class CoverLookupTests(unittest.TestCase):
    def test_pick_cover_prefers_upstream_https_field(self):
        self.assertEqual(
            pick_cover_url({"poster_url": "http://x/a.jpg", "classic_cover_url": "https://x/c.jpg"}),
            "https://x/c.jpg",
        )
        self.assertIsNone(pick_cover_url({"poster_url": "javascript:1", "name": "n"}))
        self.assertEqual(pick_cover_url({"coverurl": "https://x/d.jpg"}), "https://x/d.jpg")

    def setUp(self):
        find_cover_url.cache_clear()

    def test_cleans_release_noise(self):
        self.assertEqual(
            clean_cover_query("[Livre] Le.Petit_Prince (2020) [epub]"),
            "Le Petit Prince",
        )

    @patch("legal_books.requests.get")
    def test_returns_open_library_cover(self, get):
        response = MagicMock()
        response.json.return_value = {"docs": [{"cover_i": 123}]}
        get.return_value = response
        self.assertEqual(
            find_cover_url("Le Petit Prince"),
            "https://covers.openlibrary.org/b/id/123-M.jpg",
        )

    @patch("legal_books.requests.get")
    def test_no_match_or_failure_returns_none(self, get):
        response = MagicMock()
        response.json.return_value = {"docs": [{}]}
        get.return_value = response
        self.assertIsNone(find_cover_url("nothing"))
        find_cover_url.cache_clear()
        get.side_effect = requests.exceptions.Timeout()
        self.assertIsNone(find_cover_url("timeout"))


if __name__ == "__main__":
    unittest.main()
