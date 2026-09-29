from __future__ import annotations

import logging
import os
import platform
import shutil
import subprocess
import tempfile
import threading
import uuid
from pathlib import Path
from typing import Any, Dict, Optional

import requests
from dotenv import load_dotenv
from fastapi import Body, Depends, FastAPI, HTTPException, Query, Response
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from torrentool.api import Torrent

from auth_api import create_auth_api
from auth_store import AuthStore
from libgen_api_enhanced import LibgenSearch

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("tr4cker_bridge")

load_dotenv(Path(__file__).with_name(".env"))

API_BASE_URL = "https://tr4ker.net/api"
API_KEY = os.getenv("TR4CKER_API_KEY")

if not API_KEY:
    raise RuntimeError("Missing TR4CKER_API_KEY in environment (.env file).")

auth_store = AuthStore.from_environment()
auth_router, require_api_credentials = create_auth_api(auth_store)
app = FastAPI(title="TR4CKER API bridge")
app.include_router(auth_router)
download_jobs: Dict[str, Dict[str, Any]] = {}
download_jobs_lock = threading.Lock()


class LaunchTorrentBody(BaseModel):
    """Optional launch payload. `library` defaults to `audiobooks` when omitted and chooses between the configured folder targets."""

    library: str = "audiobooks"


class BookSearchFilters(BaseModel):
    """Filter criteria mapping for book search."""

    ID: Optional[str] = None
    Author: Optional[str] = None
    Title: Optional[str] = None
    Publisher: Optional[str] = None
    Year: Optional[str] = None
    Pages: Optional[str] = None
    Language: Optional[str] = None
    Size: Optional[str] = None
    Extension: Optional[str] = None

    class Config:
        extra = "allow"
        json_schema_extra = {
            "example": {
                "Language": "German",
                "Year": "2009",
                "Extension": "epub",
            }
        }


def register_download_job(
    *,
    slug: str,
    info: str,
    download_dir: str,
    client: str,
    process: Optional[subprocess.Popen[Any]],
) -> Dict[str, Any]:
    job_id = str(uuid.uuid4())
    job = {
        "job_id": job_id,
        "slug": slug,
        "info": info,
        "download_dir": download_dir,
        "client": client,
        "status": "running",
        "progress": None,
    }
    with download_jobs_lock:
        download_jobs[job_id] = job

    if process is not None:
        threading.Thread(
            target=monitor_download_job,
            args=(job_id, process),
            daemon=True,
        ).start()
    return dict(job)


def monitor_download_job(job_id: str, process: subprocess.Popen[Any]) -> None:
    return_code = process.wait()
    with download_jobs_lock:
        job = download_jobs.get(job_id)
        if job is not None:
            job["status"] = "completed" if return_code == 0 else "failed"
            job["exit_code"] = return_code


@app.get("/api/downloads/{job_id}")
def get_download_status(
    job_id: str,
    _credentials: Dict[str, Any] = Depends(require_api_credentials),
) -> Dict[str, Any]:
    with download_jobs_lock:
        job = download_jobs.get(job_id)
        if job is None:
            raise HTTPException(status_code=404, detail="Download job not found.")
        return dict(job)


def tr4cker_headers() -> Dict[str, str]:
    return {
        "Accept": "application/json",
        "X-Api-Key": API_KEY,
    }


def request_tr4cker(url: str, *, params: Optional[Dict[str, Any]] = None, stream: bool = False) -> requests.Response:
    logger.info("Forwarding request to TR4CKER: url=%s params=%s stream=%s", url, params, stream)
    response = requests.get(url, params=params, headers=tr4cker_headers(), stream=stream, timeout=30)
    logger.info("TR4CKER upstream status=%s for url=%s", response.status_code, url)
    if response.status_code >= 400:
        try:
            detail = response.json()
        except ValueError:
            detail = response.text
        logger.warning("TR4CKER upstream error for url=%s: %s", url, detail)
        raise HTTPException(status_code=response.status_code, detail={"message": "Tr4cker API request failed", "details": detail})
    return response


@app.get("/health")
def health() -> Dict[str, str]:
    return {"status": "ok"}


@app.get("/api/torrents")
def search_torrents(
    q: str = Query(..., description="Search query"),
    cat: str = Query("livres-audio", description="Category to search in"),
    _credentials: Dict[str, Any] = Depends(require_api_credentials),
    # page: int = Query(1, ge=1),
) -> Any:
    """Search Torrents from TR4CKER.

    Required parameters:
    - cat = "livres-audio"
    - q = your search term
    """
    logger.info("Incoming search request: q=%s cat=%s", q, cat)
    response = request_tr4cker(
        f"{API_BASE_URL}/torrents",
        params={"cat": cat, "q": q},
    )
    return response.json()


@app.get("/api/books/search")
def search_books(
    filters: Dict[str, Any] = Body(
        ...,
        description="Filter criteria map for book search (e.g., {'Language': 'German', 'Year': '2009'}).",
        openapi_examples={
            "language_and_year": {
                "summary": "Language and Year filter",
                "value": {"Language": "German", "Year": "2009"},
            },
            "year_and_extension": {
                "summary": "Year and Extension filter",
                "value": {"Year": "2007", "Extension": "epub"},
            },
        },
    ),
    _credentials: Dict[str, Any] = Depends(require_api_credentials),
) -> Dict[str, Any]:
    """Search books using custom field filters."""
    logger.info("Incoming book search request with filters: %s", filters)

    s = LibgenSearch(mirror="bz")
    title = filters.get("Title")
    filters_without_title = {k: v for k, v in filters.items() if k != "Title"}
    print(f"Searching books with title: {title} and filters: {filters_without_title}")

    try:
        titles = s.search_title_filtered(
            title,
            filters_without_title,
            exact_match=False,
        )
    except requests.exceptions.Timeout as exc:
        logger.warning("Book search upstream timed out: %s", exc)
        raise HTTPException(
            status_code=504,
            detail="The book search provider did not respond in time.",
        ) from exc
    except requests.exceptions.RequestException as exc:
        logger.warning("Book search upstream request failed: %s", exc)
        raise HTTPException(
            status_code=502,
            detail="The book search provider could not be reached.",
        ) from exc
    except Exception as exc:
        logger.exception("Unexpected book search provider error")
        raise HTTPException(
            status_code=502,
            detail="The book search provider returned an unexpected error.",
        ) from exc
    print(f"Book search results count: {len(titles)} for filters: {filters}")
    return {"filters": filters, "results": titles}


@app.get("/api/torrents/{slug}")
def get_torrent_details(
    slug: str,
    _credentials: Dict[str, Any] = Depends(require_api_credentials),
) -> Any:
    response = request_tr4cker(f"{API_BASE_URL}/torrents/{slug}")
    return response.json()


@app.get("/api/torrents/{slug}/download")
def download_torrent(
    slug: str,
    _credentials: Dict[str, Any] = Depends(require_api_credentials),
) -> StreamingResponse:
    response = request_tr4cker(f"{API_BASE_URL}/torrents/{slug}/download", stream=True)

    content_type = response.headers.get("Content-Type", "application/octet-stream")
    filename = f"{slug}.torrent"
    return StreamingResponse(
        response.iter_content(chunk_size=1024 * 64),
        media_type=content_type,
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )


@app.post("/api/torrents/{slug}/launch")
def launch_torrent_download(
    slug: str,
    body: Optional[LaunchTorrentBody] = Body(default=None),
    _credentials: Dict[str, Any] = Depends(require_api_credentials),
) -> Dict[str, Any]:
    """Download a .torrent file, validate it with torrentool, then launch it through a configured or discovered client.

    Optional body parameter: `library` can be `audiobooks` (default) or `books`.
    The chosen branch is appended to `TORRENT_DOWNLOAD_DIR`, where `AUDIOBOOKS` and `BOOKS`
    point to the environment-relative folders such as `'\\Audiobooks'` and `'\\Books'`.

    Launching a torrent requires a valid bearer session issued by `/api/auth/login`.
    """
    library_value = body.library if body else "audiobooks"
    logger.info("Incoming launch request: slug=%s library=%s", slug, library_value)

    torrent_response = request_tr4cker(f"{API_BASE_URL}/torrents/{slug}/download", stream=True)
    raw_bytes = torrent_response.content

    if not raw_bytes:
        raise HTTPException(status_code=500, detail="Downloaded torrent file is empty.")

    logger.info("Downloaded torrent bytes=%s for slug=%s", len(raw_bytes), slug)

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
            process = subprocess.Popen(command, shell=True, start_new_session=True)
        except Exception as exc:
            raise HTTPException(status_code=500, detail=f"Could not launch torrent with TORRENT_LAUNCH_COMMAND: {exc}") from exc
        return register_download_job(slug=slug, info=parsed.name, download_dir=download_dir_str, client="configured", process=process) | {"path": torrent_path, "command": command}

    if client_command:
        command = client_command.format(torrent_path=torrent_path, slug=slug, download_dir=download_dir_str)
        try:
            process = subprocess.Popen(command, shell=True, start_new_session=True)
        except Exception as exc:
            raise HTTPException(status_code=500, detail=f"Could not launch torrent with TORRENT_CLIENT_COMMAND: {exc}") from exc
        return register_download_job(slug=slug, info=parsed.name, download_dir=download_dir_str, client="configured", process=process) | {"path": torrent_path, "command": command}

    aria2 = local_aria2_path() or shutil.which("aria2c")
    if aria2:
        print(f"Launching torrent with aria2c: {aria2} --seed-time=0 --dir {download_dir_str} {torrent_path}")
        try:
            process = subprocess.Popen(
                [aria2, "--seed-time=0", "--dir", download_dir_str, torrent_path],
                start_new_session=True,
            )
        except Exception as exc:
            raise HTTPException(status_code=500, detail=f"Could not launch aria2c: {exc}") from exc
        return register_download_job(slug=slug, info=parsed.name, download_dir=download_dir_str, client="aria2c", process=process) | {"path": torrent_path}

    system = platform.system()
    if system == "Windows":
        try:
            os.startfile(torrent_path)  # type: ignore[attr-defined]
            return register_download_job(slug=slug, info=parsed.name, download_dir=download_dir_str, client="default_file_association", process=None) | {"path": torrent_path}
        except Exception as exc:  # pragma: no cover - platform dependent
            raise HTTPException(status_code=500, detail=f"Could not launch torrent file via Windows file association: {exc}") from exc

    opener = "xdg-open" if system == "Linux" else "open"
    opener_path = shutil.which(opener)
    if opener_path:
        try:
            process = subprocess.Popen([opener_path, torrent_path], start_new_session=True)
        except Exception as exc:
            raise HTTPException(status_code=500, detail=f"Could not launch torrent file via {opener}: {exc}") from exc
        return register_download_job(slug=slug, info=parsed.name, download_dir=download_dir_str, client=opener, process=process) | {"path": torrent_path}

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
    """Prefer a workspace-local aria2 binary only when it matches the current OS.

    The repository ships a Windows-only aria2 bundle. In Linux containers, the
    service must not prefer that binary because it cannot execute inside Docker.
    """
    project_root = Path(__file__).resolve().parent
    system = platform.system()

    if system == "Windows":
        candidates = [
            project_root / "aria2-1.37.0-win-64bit-build1" / "aria2c.exe",
        ]
    elif system == "Linux":
        candidates = [
            project_root / "aria2-1.37.0-win-64bit-build1" / "aria2c",
        ]
    else:
        candidates = []

    for candidate in candidates:
        if candidate.exists():
            return str(candidate)
    return None


if __name__ == "__main__":
    import threading
    import uvicorn

    port = int(os.getenv("TR4CKER_API_PORT", "8384"))
    dual_stack = os.getenv("TR4CKER_API_DUAL_STACK", "true").lower() in {
        "1",
        "true",
        "yes",
        "on",
    }
    reload_enabled = os.getenv("TR4CKER_API_RELOAD", "false").lower() in {
        "1",
        "true",
        "yes",
        "on",
    }

    if dual_stack:
        ipv6_host = os.getenv("TR4CKER_API_IPV6_HOST", "::")
        ipv4_host = os.getenv("TR4CKER_API_IPV4_HOST", "0.0.0.0")

        def serve_one(host: str) -> None:
            config = uvicorn.Config(
                "main:app",
                host=host,
                port=port,
                reload=False,
                log_level="info",
            )
            server = uvicorn.Server(config)
            server.run()

        threads = [
            threading.Thread(target=serve_one, args=(ipv6_host,), daemon=True),
            threading.Thread(target=serve_one, args=(ipv4_host,), daemon=True),
        ]
        for thread in threads:
            thread.start()
        threading.Event().wait()
    else:
        custom_host = os.getenv("TR4CKER_API_HOST", "0.0.0.0")
        uvicorn.run("main:app", host=custom_host, port=port, reload=reload_enabled)
