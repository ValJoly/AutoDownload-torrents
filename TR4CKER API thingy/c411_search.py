from __future__ import annotations

import re
import threading
import time
import xml.etree.ElementTree as ET
from urllib.parse import parse_qs, urlparse

import requests

from legal_books import pick_cover_url

C411_API_URL = "https://c411.org/api/torznab"
C411_CATEGORIES = {"livres": "7020", "livres-audio": "3030"}
_TORRENT_ID_PATTERN = re.compile(r"(?:\d{1,32}|[a-fA-F0-9]{40})")
_REQUEST_INTERVAL = 4.1
_request_lock = threading.Lock()
_last_request_at = 0.0


class C411SearchError(Exception):
    pass


def _request(params: dict[str, str], api_key: str) -> requests.Response:
    global _last_request_at
    with _request_lock:
        delay = _REQUEST_INTERVAL - (time.monotonic() - _last_request_at)
        if delay > 0:
            time.sleep(delay)
        _last_request_at = time.monotonic()
        try:
            response = requests.get(
                C411_API_URL,
                params={"apikey": api_key, **params},
                timeout=30,
            )
            response.raise_for_status()
            return response
        except requests.RequestException as error:
            raise C411SearchError("C411 API request failed.") from error


def _local_name(tag: str) -> str:
    return tag.rsplit("}", 1)[-1]


def _child_text(element: ET.Element, name: str) -> str:
    for child in element:
        if _local_name(child.tag) == name:
            return (child.text or "").strip()
    return ""


def _number(value: str) -> int:
    try:
        return max(0, int(value))
    except ValueError:
        return 0


def _attributes(item: ET.Element) -> dict[str, str]:
    return {
        child.attrib["name"]: child.attrib.get("value", "")
        for child in item.iter()
        if _local_name(child.tag) == "attr" and child.attrib.get("name")
    }


def _download_id(item: ET.Element) -> str | None:
    for child in item:
        if _local_name(child.tag) != "enclosure":
            continue
        candidate = parse_qs(urlparse(child.attrib.get("url", "")).query).get("id", [""])[0]
        if _TORRENT_ID_PATTERN.fullmatch(candidate):
            return candidate
    return None


def parse_torznab_results(content: bytes) -> list[dict[str, object]]:
    try:
        root = ET.fromstring(content)
    except ET.ParseError as error:
        raise C411SearchError("C411 returned invalid Torznab XML.") from error

    if _local_name(root.tag) != "rss":
        raise C411SearchError("C411 returned an unexpected response.")

    results = []
    for item in root.iter():
        if _local_name(item.tag) != "item":
            continue
        torrent_id = _download_id(item)
        name = _child_text(item, "title")
        if torrent_id is None or not name:
            continue

        attributes = _attributes(item)
        results.append(
            {
                "id": torrent_id,
                "slug": torrent_id,
                "name": name,
                "size_bytes": _number(_child_text(item, "size")),
                "file_count": _number(attributes.get("files", "")),
                "seeders": _number(attributes.get("seeders", "")),
                "source": "c411",
                "cover_url": pick_cover_url(attributes),
            }
        )
    return results


def search_c411(query: str, category: str, api_key: str) -> list[dict[str, object]]:
    c411_category = C411_CATEGORIES.get(category)
    if c411_category is None:
        raise C411SearchError("C411 does not support this category.")
    response = _request(
        {"t": "search", "q": query, "cat": c411_category, "limit": "100"},
        api_key,
    )
    return parse_torznab_results(response.content)


def download_c411_torrent(torrent_id: str, api_key: str) -> requests.Response:
    if not _TORRENT_ID_PATTERN.fullmatch(torrent_id):
        raise C411SearchError("Invalid C411 torrent ID.")
    return _request({"t": "get", "id": torrent_id}, api_key)