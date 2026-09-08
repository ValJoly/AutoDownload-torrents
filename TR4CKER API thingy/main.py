from __future__ import annotations

import os
import platform
import shutil
import subprocess
import tempfile
from pathlib import Path
from typing import Any, Dict, Optional

import requests
from dotenv import load_dotenv
from fastapi import Body, FastAPI, HTTPException, Query, Response
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from torrentool.api import Torrent

load_dotenv()

API_BASE_URL = "https://tr4ker.net/api"
API_KEY = os.getenv("TR4CKER_API_KEY")

if not API_KEY:
    raise RuntimeError("Missing TR4CKER_API_KEY in environment (.env file).")

app = FastAPI(title="TR4CKER API bridge")


class LaunchTorrentBody(BaseModel):
    """Optional launch payload. `library` defaults to `audiobooks` when omitted and chooses between the configured folder targets."""

    library: str = "audiobooks"


def tr4cker_headers() -> Dict[str, str]:
    return {
        "Accept": "application/json",
        "X-Api-Key": API_KEY,
    }


def request_tr4cker(url: str, *, params: Optional[Dict[str, Any]] = None, stream: bool = False) -> requests.Response:
    response = requests.get(url, params=params, headers=tr4cker_headers(), stream=stream, timeout=30)
    if response.status_code >= 400:
        try:
            detail = response.json()
        except ValueError:
            detail = response.text
        raise HTTPException(status_code=response.status_code, detail={"message": "Tr4cker API request failed", "details": detail})
    return response


@app.get("/health")
def health() -> Dict[str, str]:
    return {"status": "ok"}


@app.get("/api/torrents")
def search_torrents(
    q: str = Query(..., description="Search query"),
    cat: str = Query("livres-audio", description="Category to search in"),
    # page: int = Query(1, ge=1),
) -> Any:
    """Search Torrents from TR4CKER.

    Required parameters:
    - cat = "livres-audio"
    - q = your search term
    """
    response = request_tr4cker(
        f"{API_BASE_URL}/torrents",
        params={"cat": cat, "q": q},
    )
    return response.json()


@app.get("/api/torrents/{slug}")
def get_torrent_details(slug: str) -> Any:
    response = request_tr4cker(f"{API_BASE_URL}/torrents/{slug}")
    return response.json()


@app.get("/api/torrents/{slug}/download")
def download_torrent(slug: str) -> StreamingResponse:
    response = request_tr4cker(f"{API_BASE_URL}/torrents/{slug}/download", stream=True)

    content_type = response.headers.get("Content-Type", "application/octet-stream")
    filename = f"{slug}.torrent"
    return StreamingResponse(
        response.iter_content(chunk_size=1024 * 64),
        media_type=content_type,
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )


@app.post("/api/torrents/{slug}/launch")
def launch_torrent_download(slug: str, body: Optional[LaunchTorrentBody] = Body(default=None)) -> Dict[str, Any]:
    """Download a .torrent file, validate it with torrentool, then launch it through a configured or discovered client.

    Optional body parameter: `library` can be `audiobooks` (default) or `books`.
    The chosen branch is appended to `TORRENT_DOWNLOAD_DIR`, where `AUDIOBOOKS` and `BOOKS`
    point to the environment-relative folders such as `'\\Audiobooks'` and `'\\Books'`.
    """
    torrent_response = request_tr4cker(f"{API_BASE_URL}/torrents/{slug}/download", stream=True)
    raw_bytes = torrent_response.content

    if not raw_bytes:
        raise HTTPException(status_code=500, detail="Downloaded torrent file is empty.")

    library_value = body.library if body else "audiobooks"
    download_dir = resolve_download_dir(library_value)
    download_dir.mkdir(parents=True, exist_ok=True)
    download_dir_str = str(download_dir)

    with tempfile.NamedTemporaryFile(suffix=".torrent", delete=False) as temp_file:
        temp_file.write(raw_bytes)
        torrent_path = temp_file.name

    try:
        parsed = Torrent.from_file(torrent_path)
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Downloaded torrent file is not a valid .torrent: {exc}") from exc

    launch_command = os.getenv("TORRENT_LAUNCH_COMMAND")
    client_command = os.getenv("TORRENT_CLIENT_COMMAND")

    if launch_command:
        command = launch_command.format(torrent_path=torrent_path, slug=slug, download_dir=download_dir_str)
        try:
            subprocess.Popen(command, shell=True, start_new_session=True)
        except Exception as exc:
            raise HTTPException(status_code=500, detail=f"Could not launch torrent with TORRENT_LAUNCH_COMMAND: {exc}") from exc
        return {"status": "started", "slug": slug, "path": torrent_path, "command": command, "info": parsed.name, "download_dir": download_dir_str}

    if client_command:
        command = client_command.format(torrent_path=torrent_path, slug=slug, download_dir=download_dir_str)
        try:
            subprocess.Popen(command, shell=True, start_new_session=True)
        except Exception as exc:
            raise HTTPException(status_code=500, detail=f"Could not launch torrent with TORRENT_CLIENT_COMMAND: {exc}") from exc
        return {"status": "started", "slug": slug, "path": torrent_path, "command": command, "info": parsed.name, "download_dir": download_dir_str}

    aria2 = local_aria2_path() or shutil.which("aria2c")
    if aria2:
        print(f"Launching torrent with aria2c: {aria2} --seed-time=0 --dir {download_dir_str} {torrent_path}")
        try:
            subprocess.Popen(
                [aria2, "--seed-time=0", "--dir", download_dir_str, torrent_path],
                start_new_session=True,
            )
        except Exception as exc:
            raise HTTPException(status_code=500, detail=f"Could not launch aria2c: {exc}") from exc
        return {"status": "started", "slug": slug, "path": torrent_path, "client": "aria2c", "info": parsed.name, "download_dir": download_dir_str}

    system = platform.system()
    if system == "Windows":
        try:
            os.startfile(torrent_path)  # type: ignore[attr-defined]
            return {"status": "started", "slug": slug, "path": torrent_path, "client": "default_file_association", "info": parsed.name, "download_dir": download_dir_str}
        except Exception as exc:  # pragma: no cover - platform dependent
            raise HTTPException(status_code=500, detail=f"Could not launch torrent file via Windows file association: {exc}") from exc

    opener = "xdg-open" if system == "Linux" else "open"
    opener_path = shutil.which(opener)
    if opener_path:
        try:
            subprocess.Popen([opener_path, torrent_path], start_new_session=True)
        except Exception as exc:
            raise HTTPException(status_code=500, detail=f"Could not launch torrent file via {opener}: {exc}") from exc
        return {"status": "started", "slug": slug, "path": torrent_path, "client": opener, "info": parsed.name, "download_dir": download_dir_str}

    raise HTTPException(
        status_code=500,
        detail="No torrent launcher is configured. Set TORRENT_LAUNCH_COMMAND or TORRENT_CLIENT_COMMAND, or install aria2c.",
    )


def resolve_download_dir(library: Optional[str] = None) -> Path:
    """Resolve the final branch directory by joining `TORRENT_DOWNLOAD_DIR` with one plain branch folder only.

    `BOOKS` and `AUDIOBOOKS` must be plain folder names such as `Books` or `Audiobooks`.
    They are interpreted as exactly one child folder and never nested again under the base folder.
    """
    requested = (library or "audiobooks").strip().lower()
    if requested in {"book", "books"}:
        branch_env = "BOOKS"
        default_branch = "Books"
    else:
        branch_env = "AUDIOBOOKS"
        default_branch = "Audiobooks"

    branch_value = os.getenv(branch_env, default_branch).strip()
    branch_value = branch_value.replace("/", "").replace("\\", "")
    branch_value = branch_value.strip("\\/")

    if Path(branch_value).is_absolute():
        return Path(branch_value)

    base_dir = Path(os.getenv("TORRENT_DOWNLOAD_DIR", r"I:\Books")).expanduser()
    # Normalize the base directory once so we never carry an extra `Books` token from the root.
    base_dir = Path(str(base_dir).replace("\\", "/").replace("//", "/")).expanduser()
    return base_dir / branch_value


def local_aria2_path() -> Optional[str]:
    """Prefer the workspace-local aria2 bundle included with this repository, if present."""
    project_root = Path(__file__).resolve().parent
    candidates = [
        project_root / "aria2-1.37.0-win-64bit-build1" / "aria2c.exe",
        project_root / "aria2-1.37.0-win-64bit-build1" / "aria2c",
    ]
    for candidate in candidates:
        if candidate.exists():
            return str(candidate)
    return None


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("main:app", host="localhost", port=8384, reload=True)
