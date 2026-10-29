from __future__ import annotations

import os
import re
import tempfile
import time
from functools import lru_cache
from typing import Any
from pathlib import Path
from urllib.parse import urlparse
import zipfile

import requests


GUTENDEX_API = "https://gutendex.com/books/"
GOOGLE_BOOKS_API = "https://www.googleapis.com/books/v1/volumes"
_BOOK_ID = re.compile(r"^\d{1,8}$")
_GOOGLE_BOOK_ID = re.compile(r"^[A-Za-z0-9_-]{1,128}$")
_SUPPORTED_LANGUAGES = frozenset({"de", "en", "es", "fr", "it", "pt"})
_GUTENBERG_HOSTS = frozenset(
    {"www.gutenberg.org", "gutenberg.org", "aleph.gutenberg.org"}
)


class LegalBooksError(Exception):
    pass


OPEN_LIBRARY_SEARCH = "https://openlibrary.org/search.json"
_COVER_FIELDS = (
    "classic_cover_url",
    "cover_url",
    "coverurl",
    "poster_url",
    "poster",
    "cover",
    "image",
    "thumbnail",
)


def pick_cover_url(item: dict[str, Any]) -> str | None:
    for field in _COVER_FIELDS:
        value = item.get(field)
        if isinstance(value, str) and value.startswith("https://"):
            return value
    return None


def clean_cover_query(title: str) -> str:
    title = re.sub(r"\[[^\]]*\]|\([^)]*\)", " ", title)
    title = re.sub(r"[._]+", " ", title)
    return " ".join(title.split())[:100]


@lru_cache(maxsize=512)
def find_cover_url(title: str) -> str | None:
    query = clean_cover_query(title)
    if not query:
        return None
    try:
        response = requests.get(
            OPEN_LIBRARY_SEARCH,
            params={"q": query, "limit": 1, "fields": "cover_i"},
            timeout=6,
        )
        response.raise_for_status()
        docs = response.json().get("docs") or []
    except (requests.exceptions.RequestException, ValueError, AttributeError):
        return None
    cover_id = docs[0].get("cover_i") if docs and isinstance(docs[0], dict) else None
    if not isinstance(cover_id, int):
        return None
    return f"https://covers.openlibrary.org/b/id/{cover_id}-M.jpg"


def validate_download_request(volume_id: str, file_format: str) -> None:
    if not _BOOK_ID.fullmatch(volume_id) or file_format != "epub":
        raise ValueError("Invalid legal-book ID or format.")


def validate_language(language: str) -> str:
    language = language.strip().lower()
    if language not in _SUPPORTED_LANGUAGES:
        raise ValueError("Choose a supported book language.")
    return language


def _safe_gutenberg_url(value: Any, *, allow_mirrors: bool = False) -> str | None:
    if not isinstance(value, str):
        return None
    parsed = urlparse(value)
    hosts = _GUTENBERG_HOSTS if allow_mirrors else {"www.gutenberg.org", "gutenberg.org"}
    if (
        parsed.scheme != "https"
        or parsed.hostname not in hosts
        or parsed.port not in (None, 443)
        or parsed.username is not None
        or parsed.password is not None
    ):
        return None
    return value


def _epub_link(book: Any) -> str | None:
    if not isinstance(book, dict) or not isinstance(book.get("formats"), dict):
        return None
    book_id = str(book.get("id", ""))
    link = _safe_gutenberg_url(book["formats"].get("application/epub+zip"))
    if (
        not _BOOK_ID.fullmatch(book_id)
        or link is None
        or not urlparse(link).path.startswith(f"/ebooks/{book_id}.")
    ):
        return None
    return link


def normalize_book(book: Any) -> dict[str, Any] | None:
    if not isinstance(book, dict) or not _BOOK_ID.fullmatch(str(book.get("id", ""))):
        return None
    title = book.get("title")
    if not isinstance(title, str) or not title.strip():
        return None
    authors = book.get("authors", [])
    summaries = book.get("summaries", [])
    languages = book.get("languages", [])
    if not isinstance(authors, list):
        authors = []
    if not isinstance(summaries, list):
        summaries = []
    if not isinstance(languages, list):
        languages = []
    epub_available = _epub_link(book) is not None
    return {
        "id": str(book["id"]),
        "title": title.strip()[:300],
        "authors": [
            author["name"][:200]
            for author in authors[:10]
            if isinstance(author, dict)
            and isinstance(author.get("name"), str)
        ],
        "published_date": str(book.get("release_date") or "")[:32],
        "description": str(summaries[0] if summaries else "")[:4000],
        "languages": [
            language[:2].lower()
            for language in languages[:10]
            if isinstance(language, str) and len(language) == 2
        ],
        "copyright": book.get("copyright") if isinstance(book.get("copyright"), bool) else None,
        "preview_link": f"https://www.gutenberg.org/ebooks/{book['id']}",
        "cover_url": _safe_gutenberg_url(
            book["formats"].get("image/jpeg")
            if isinstance(book.get("formats"), dict)
            else None
        ),
        "formats": ["epub"] if epub_available else [],
        "source": "Project Gutenberg",
    }


def _safe_google_link(value: Any) -> str | None:
    if not isinstance(value, str):
        return None
    parsed = urlparse(value)
    if (
        parsed.scheme != "https"
        or parsed.hostname != "books.google.com"
        or parsed.port not in (None, 443)
        or parsed.username is not None
        or parsed.password is not None
    ):
        return None
    return value


def normalize_google_book(volume: Any) -> dict[str, Any] | None:
    if not isinstance(volume, dict) or not _GOOGLE_BOOK_ID.fullmatch(
        str(volume.get("id", ""))
    ):
        return None
    info = volume.get("volumeInfo")
    if not isinstance(info, dict):
        return None
    title = info.get("title")
    if not isinstance(title, str) or not title.strip():
        return None
    authors = info.get("authors", [])
    if not isinstance(authors, list):
        authors = []
    language = info.get("language")
    links = info.get("imageLinks")
    thumbnail = links.get("thumbnail") if isinstance(links, dict) else None
    if isinstance(thumbnail, str) and thumbnail.startswith("http://"):
        thumbnail = "https://" + thumbnail[len("http://"):]
    return {
        "id": f"google-{volume['id']}",
        "title": title.strip()[:300],
        "authors": [author[:200] for author in authors[:10] if isinstance(author, str)],
        "published_date": str(info.get("publishedDate") or "")[:32],
        "description": str(info.get("description") or "")[:4000],
        "languages": [language.lower()] if isinstance(language, str) and len(language) == 2 else [],
        "copyright": None,
        "preview_link": _safe_google_link(info.get("previewLink")),
        "cover_url": _safe_google_link(thumbnail),
        "formats": [],
        "source": "Google Books",
    }


def _is_valid_epub(path: str) -> bool:
    try:
        with zipfile.ZipFile(path) as archive:
            names = archive.namelist()
            return bool(names) and names[0] == "mimetype" and archive.read("mimetype") == b"application/epub+zip"
    except (OSError, zipfile.BadZipFile, KeyError):
        return False


def _search_gutendex(query: str, language: str) -> list[dict[str, Any]]:
    try:
        response = requests.get(
            GUTENDEX_API,
            params={
                "search": query,
                "languages": language,
                "page": 1,
            },
            timeout=6,
            allow_redirects=False,
        )
        if response.status_code != 200:
            raise LegalBooksError("The legal-book catalog is unavailable.")
        response.raise_for_status()
        payload = response.json()
    except requests.exceptions.Timeout as exc:
        raise LegalBooksError("The Project Gutenberg catalog timed out.") from None
    except (requests.exceptions.RequestException, ValueError):
        raise LegalBooksError("The legal-book catalog is unavailable.") from None
    finally:
        if "response" in locals():
            response.close()

    if not isinstance(payload, dict):
        raise LegalBooksError("The Project Gutenberg catalog returned invalid data.")
    items = payload.get("results", [])
    if not isinstance(items, list):
        raise LegalBooksError("The Project Gutenberg catalog returned invalid data.")
    records = []
    for item in items:
        normalized = normalize_book(item)
        if normalized is not None:
            records.append(normalized)
    return records


def _search_gutendex_terms(query: str, language: str) -> list[dict[str, Any]] | None:
    terms = list(dict.fromkeys(re.findall(r"[^\W_]+", query.casefold())))
    if not 2 <= len(terms) <= 3:
        return None

    matches: dict[str, dict[str, Any]] = {}
    successful_search = False
    for term in terms:
        try:
            books = _search_gutendex(term, language)
        except LegalBooksError:
            continue
        successful_search = True
        for book in books:
            searchable = " ".join([book["title"], *book["authors"]]).casefold()
            if all(term in searchable for term in terms):
                matches.setdefault(book["id"], book)

    return list(matches.values()) if successful_search else None


def _search_google_books(query: str, language: str) -> list[dict[str, Any]]:
    key = os.getenv("GOOGLE_BOOKS_API_KEY")
    if not key:
        raise LegalBooksError("The backup book catalog is not configured.")
    try:
        response = requests.get(
            GOOGLE_BOOKS_API,
            params={
                "q": query,
                "filter": "free-ebooks",
                "printType": "books",
                "langRestrict": language,
                "maxResults": 40,
                "key": key,
            },
            timeout=12,
            allow_redirects=False,
        )
        if response.status_code != 200:
            raise LegalBooksError("The backup book catalog is unavailable.")
        response.raise_for_status()
        payload = response.json()
    except requests.exceptions.Timeout:
        raise LegalBooksError("The backup book catalog timed out.") from None
    except (requests.exceptions.RequestException, ValueError):
        raise LegalBooksError("The backup book catalog is unavailable.") from None
    finally:
        if "response" in locals():
            response.close()

    if not isinstance(payload, dict) or not isinstance(payload.get("items", []), list):
        raise LegalBooksError("The backup book catalog returned invalid data.")
    return [
        normalized
        for volume in payload.get("items", [])
        if (normalized := normalize_google_book(volume)) is not None
    ]


def search_legal_books(
    query: str,
    *,
    language: str = "fr",
    gutenberg_only: bool = False,
) -> list[dict[str, Any]]:
    query = query.strip()
    if not 2 <= len(query) <= 120:
        raise ValueError("Search text must be between 2 and 120 characters.")
    language = validate_language(language)
    try:
        books = _search_gutendex(query, language)
    except LegalBooksError as error:
        if "timed out" in str(error).lower():
            term_books = _search_gutendex_terms(query, language)
            if term_books is not None:
                return term_books
        if gutenberg_only:
            raise
        return _search_google_books(query, language)
    if books:
        return books
    term_books = _search_gutendex_terms(query, language)
    if term_books is not None:
        return term_books
    if gutenberg_only or not os.getenv("GOOGLE_BOOKS_API_KEY"):
        return books
    return _search_google_books(query, language)


def _gutendex_book(book_id: str) -> dict[str, Any]:
    for attempt in range(3):
        try:
            response = requests.get(
                f"{GUTENDEX_API}{book_id}/",
                timeout=(5, 20),
                allow_redirects=False,
            )
        except requests.exceptions.Timeout:
            if attempt == 2:
                raise LegalBooksError("The free-book catalog timed out.") from None
            time.sleep(0.5 * (attempt + 1))
            continue
        except requests.exceptions.RequestException:
            raise LegalBooksError("The legal-book catalog is unavailable.") from None

        try:
            if response.status_code != 200:
                raise LegalBooksError("The legal-book catalog is unavailable.")
            response.raise_for_status()
            book = response.json()
        except (requests.exceptions.RequestException, ValueError):
            raise LegalBooksError("The legal-book catalog is unavailable.") from None
        finally:
            response.close()
        break

    if not isinstance(book, dict) or str(book.get("id", "")) != book_id:
        raise LegalBooksError("The legal-book catalog returned invalid data.")
    return book


def _download_epub(url: str) -> requests.Response:
    for _ in range(5):
        try:
            response = requests.get(
                url,
                timeout=(5, 30),
                stream=True,
                allow_redirects=False,
            )
        except requests.exceptions.RequestException:
            raise LegalBooksError("The book file could not be retrieved.") from None
        if response.status_code == 200:
            return response
        if response.status_code not in {301, 302, 303, 307, 308}:
            response.close()
            raise LegalBooksError("The book provider did not return a direct file.")
        redirect = response.headers.get("Location")
        response.close()
        next_url = _safe_gutenberg_url(
            requests.compat.urljoin(url, redirect), allow_mirrors=True
        ) if redirect else None
        if next_url is None:
            raise LegalBooksError("The book provider returned an unsafe redirect.")
        url = next_url
    raise LegalBooksError("The book provider returned too many redirects.")


def download_legal_book(
    volume_id: str,
    file_format: str,
    destination: str | os.PathLike[str],
) -> Path:
    validate_download_request(volume_id, file_format)
    book = _gutendex_book(volume_id)
    normalized = normalize_book(book)
    link = _epub_link(book)
    if link is None:
        raise ValueError("EPUB is not available for this book.")
    if normalized is None:
        raise LegalBooksError("The legal-book catalog returned invalid data.")

    title = re.sub(r'[<>:"/\\|?*\x00-\x1f]', "_", normalized["title"])
    title = title.strip(" .")[:100] or "Book"
    target_dir = Path(destination)
    target_dir.mkdir(parents=True, exist_ok=True)
    output_path = target_dir / f"{title} - {volume_id}.{file_format}"
    if output_path.exists():
        raise FileExistsError("This book format is already saved.")

    response = _download_epub(link)
    temp_path: str | None = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="wb", prefix=".legal-book-", suffix=".part", dir=target_dir, delete=False
        ) as temp_file:
            temp_path = temp_file.name
            size = 0
            header = b""
            for chunk in response.iter_content(chunk_size=64 * 1024):
                if not chunk:
                    continue
                if not header:
                    header = chunk[:8]
                size += len(chunk)
                if size > 100 * 1024 * 1024:
                    raise LegalBooksError("The book file exceeds the 100 MB limit.")
                temp_file.write(chunk)
        if not _is_valid_epub(temp_path):
            raise LegalBooksError("The provider returned an invalid EPUB file.")

        os.link(temp_path, output_path)
        return output_path
    except requests.exceptions.RequestException:
        raise LegalBooksError("The book file could not be retrieved.") from None
    finally:
        response.close()
        if temp_path is not None:
            try:
                os.unlink(temp_path)
            except FileNotFoundError:
                pass