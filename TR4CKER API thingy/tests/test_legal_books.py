import io
import tempfile
import unittest
import zipfile
from pathlib import Path
from unittest.mock import patch

import requests

from legal_books import (
    LegalBooksError,
    _is_valid_epub,
    download_legal_book,
    normalize_book,
    search_legal_books,
)


class GutendexTests(unittest.TestCase):
    def make_book(self, **updates):
        book = {
            "id": 1342,
            "title": "Pride and Prejudice",
            "authors": [{"name": "Austen, Jane"}],
            "summaries": ["A novel."],
            "release_date": "1813-01-28",
            "languages": ["fr"],
            "copyright": False,
            "formats": {
                "application/epub+zip": "https://www.gutenberg.org/ebooks/1342.epub.images",
                "text/html": "https://www.gutenberg.org/ebooks/1342.html.images",
            },
        }
        book.update(updates)
        return book

    @staticmethod
    def epub_bytes():
        output = io.BytesIO()
        with zipfile.ZipFile(output, "w") as archive:
            archive.writestr(
                "mimetype",
                "application/epub+zip",
                compress_type=zipfile.ZIP_STORED,
            )
            archive.writestr("content.txt", "book")
        return output.getvalue()

    def test_normalizes_catalog_metadata_and_hides_provider_download_url(self):
        normalized = normalize_book(self.make_book())

        self.assertEqual(normalized["id"], "1342")
        self.assertEqual(normalized["title"], "Pride and Prejudice")
        self.assertEqual(normalized["authors"], ["Austen, Jane"])
        self.assertEqual(normalized["description"], "A novel.")
        self.assertEqual(normalized["languages"], ["fr"])
        self.assertEqual(normalized["copyright"], False)
        self.assertEqual(normalized["formats"], ["epub"])
        self.assertEqual(
            normalized["preview_link"], "https://www.gutenberg.org/ebooks/1342"
        )
        self.assertNotIn("download_url", normalized)

    def test_omits_epub_when_catalog_url_is_not_a_trusted_gutenberg_url(self):
        normalized = normalize_book(
            self.make_book(
                formats={
                    "application/epub+zip": "https://attacker.example/1342.epub"
                }
            )
        )

        self.assertEqual(normalized["formats"], [])

    def test_ignores_invalid_book_records(self):
        self.assertIsNone(normalize_book({"id": "../1", "title": "Bad"}))
        self.assertIsNone(normalize_book({"id": 1, "title": " "}))

    @patch("legal_books.requests.get")
    def test_search_uses_query_and_language_without_api_key(self, get):
        class Response:
            status_code = 200

            def raise_for_status(self):
                return None

            def json(self):
                return {"results": [self.book], "next": None}

            def close(self):
                return None

        response = Response()
        response.book = self.make_book()
        get.return_value = response

        books = search_legal_books("  Victor Hugo  ", language="fr")

        self.assertEqual(books[0]["id"], "1342")
        self.assertEqual(get.call_args.args[0], "https://gutendex.com/books/")
        self.assertEqual(
            get.call_args.kwargs["params"],
            {"search": "Victor Hugo", "languages": "fr", "page": 1},
        )
        self.assertFalse(get.call_args.kwargs["allow_redirects"])

    @patch("legal_books.requests.get")
    def test_search_rejects_unsupported_language_before_network_request(self, get):
        with self.assertRaises(ValueError):
            search_legal_books("Victor Hugo", language="fr-CA")

        get.assert_not_called()

    @patch.dict("os.environ", {"GOOGLE_BOOKS_API_KEY": "test-google-key"})
    @patch("legal_books.requests.get")
    def test_search_falls_back_to_google_after_gutendex_timeout(self, get):
        class Response:
            status_code = 200

            def raise_for_status(self):
                return None

            def json(self):
                return {
                    "items": [
                        {
                            "id": "google-volume-1",
                            "volumeInfo": {
                                "title": "Les Misérables",
                                "authors": ["Victor Hugo"],
                                "language": "fr",
                                "previewLink": "https://books.google.com/books?id=google-volume-1",
                            },
                        }
                    ]
                }

            def close(self):
                return None

        get.side_effect = [requests.exceptions.ReadTimeout(), Response()]

        books = search_legal_books("Victor Hugo", language="fr")

        self.assertEqual(books[0]["source"], "Google Books")
        self.assertEqual(books[0]["languages"], ["fr"])
        self.assertEqual(books[0]["formats"], [])
        self.assertEqual(
            get.call_args_list[1].args[0],
            "https://www.googleapis.com/books/v1/volumes",
        )
        self.assertEqual(
            get.call_args_list[1].kwargs["params"]["langRestrict"], "fr"
        )
        self.assertEqual(get.call_args_list[1].kwargs["params"]["key"], "test-google-key")

    @patch("legal_books.requests.get")
    def test_search_rejects_malformed_catalog_response(self, get):
        class Response:
            status_code = 200

            def raise_for_status(self):
                return None

            def json(self):
                return {"results": "not-a-list"}

            def close(self):
                return None

        get.return_value = Response()

        with self.assertRaises(LegalBooksError):
            search_legal_books("Victor Hugo")

    def test_epub_validation_requires_epub_mimetype(self):
        with tempfile.TemporaryDirectory() as directory:
            invalid_path = Path(directory) / "invalid.epub"
            valid_path = Path(directory) / "valid.epub"
            with zipfile.ZipFile(invalid_path, "w") as archive:
                archive.writestr("content.txt", "not an epub")
            with zipfile.ZipFile(valid_path, "w") as archive:
                archive.writestr(
                    "mimetype",
                    "application/epub+zip",
                    compress_type=zipfile.ZIP_STORED,
                )
                archive.writestr("content.txt", "epub content")

            self.assertFalse(_is_valid_epub(str(invalid_path)))
            self.assertTrue(_is_valid_epub(str(valid_path)))

    @patch("legal_books.requests.get")
    def test_download_revalidates_record_and_saves_epub_without_overwrite(self, get):
        class Response:
            status_code = 200
            headers = {}

            def __init__(self, *, payload=None, body=b""):
                self.payload = payload
                self.body = body

            def raise_for_status(self):
                return None

            def json(self):
                return self.payload

            def iter_content(self, chunk_size):
                yield self.body

            def close(self):
                return None

        book = self.make_book()
        get.side_effect = [
            Response(payload=book),
            Response(body=self.epub_bytes()),
            Response(payload=book),
        ]

        with tempfile.TemporaryDirectory() as directory:
            saved_path = download_legal_book("1342", "epub", directory)

            self.assertEqual(saved_path.read_bytes(), self.epub_bytes())
            self.assertEqual(saved_path.suffix, ".epub")
            self.assertEqual(
                get.call_args_list[0].args[0],
                "https://gutendex.com/books/1342/",
            )
            with self.assertRaises(FileExistsError):
                download_legal_book("1342", "epub", directory)

    @patch("legal_books.requests.get")
    def test_download_retries_metadata_timeout_then_saves_valid_epub(self, get):
        class Response:
            status_code = 200
            headers = {}

            def __init__(self, *, payload=None, body=b""):
                self.payload = payload
                self.body = body

            def raise_for_status(self):
                return None

            def json(self):
                return self.payload

            def iter_content(self, chunk_size):
                yield self.body

            def close(self):
                return None

        get.side_effect = [
            requests.exceptions.ReadTimeout(),
            Response(payload=self.make_book()),
            Response(body=self.epub_bytes()),
        ]

        with tempfile.TemporaryDirectory() as directory:
            saved_path = download_legal_book("1342", "epub", directory)
            self.assertTrue(saved_path.exists())

        self.assertEqual(get.call_count, 3)

    @patch("legal_books.requests.get")
    def test_download_rejects_untrusted_redirect_and_leaves_no_partial_file(self, get):
        class Response:
            status_code = 302
            headers = {"Location": "http://127.0.0.1/private"}

            def raise_for_status(self):
                return None

            def json(self):
                return self.book

            def close(self):
                return None

        metadata = Response()
        metadata.status_code = 200
        metadata.headers = {}
        metadata.book = self.make_book()
        get.side_effect = [metadata, Response()]

        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaises(LegalBooksError):
                download_legal_book("1342", "epub", directory)
            self.assertEqual(list(Path(directory).iterdir()), [])


if __name__ == "__main__":
    unittest.main()