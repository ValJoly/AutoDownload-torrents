import unittest
from unittest.mock import Mock, patch

from c411_search import (
    C411SearchError,
    download_c411_torrent,
    parse_torznab_results,
    search_c411,
)


class C411SearchTests(unittest.TestCase):
    def test_parse_torznab_results_maps_search_fields_without_returning_api_key(self) -> None:
        results = parse_torznab_results(
            b'''<rss xmlns:torznab="http://torznab.com/schemas/2015/feed">
              <channel>
                <item>
                  <title>French audiobook</title>
                  <size>2048</size>
                  <enclosure url="https://c411.org/api/torznab?apikey=private&amp;t=get&amp;id=0123456789abcdef0123456789abcdef01234567" />
                  <torznab:attr name="seeders" value="7" />
                  <torznab:attr name="peers" value="2" />
                  <torznab:attr name="files" value="3" />
                </item>
              </channel>
            </rss>'''
        )

        self.assertEqual(
            results,
            [
                {
                    "id": "0123456789abcdef0123456789abcdef01234567",
                    "slug": "0123456789abcdef0123456789abcdef01234567",
                    "name": "French audiobook",
                    "size_bytes": 2048,
                    "file_count": 3,
                    "seeders": 7,
                    "source": "c411",
                    "cover_url": None,
                }
            ],
        )
        self.assertNotIn("private", repr(results))

    @patch("c411_search._request")
    def test_search_uses_c411_torznab_params_and_audio_category(
        self, request: Mock
    ) -> None:
        request.return_value.content = b"<rss><channel /></rss>"

        results = search_c411("book title", "livres-audio", "server-key")

        self.assertEqual(results, [])
        request.assert_called_once_with(
            {"t": "search", "q": "book title", "cat": "3030", "limit": "100"},
            "server-key",
        )

    @patch("c411_search._request")
    def test_download_uses_torznab_get_and_rejects_invalid_ids(
        self, request: Mock
    ) -> None:
        response = Mock()
        request.return_value = response

        self.assertIs(download_c411_torrent("42", "server-key"), response)
        request.assert_called_once_with({"t": "get", "id": "42"}, "server-key")
        infohash = "0123456789abcdef0123456789abcdef01234567"
        self.assertIs(download_c411_torrent(infohash, "server-key"), response)
        request.assert_called_with({"t": "get", "id": infohash}, "server-key")
        with self.assertRaises(C411SearchError):
            download_c411_torrent("https://attacker.invalid", "server-key")


if __name__ == "__main__":
    unittest.main()