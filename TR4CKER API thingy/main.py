from __future__ import annotations

import base64
import json
import logging
import os
import platform
import secrets
import shutil
import socket
import subprocess
import tempfile
import threading
import time
import uuid
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any, Dict, Optional

import requests
from dotenv import load_dotenv
from fastapi import BackgroundTasks, Body, Depends, FastAPI, HTTPException, Query, Response
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from torrentool.api import Torrent

from auth_api import create_auth_api
from auth_store import AuthStore
from download_progress import normalize_aria2_status
from legal_books import (
    LegalBooksError,
    download_legal_book,
    search_legal_books,
    validate_download_request,
)
from libgen_api_enhanced import LibgenSearch

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("tr4cker_bridge")

load_dotenv(Path(__file__).with_name(".env"))

API_BASE_URL = "https://tr4ker.net/api"
API_KEY = os.getenv("TR4CKER_API_KEY")

if not API_KEY:
    raise RuntimeError("Missing TR4CKER_API_KEY in environment (.env file).")

auth_store = AuthStore.from_environment()
try:
    auth_store.reconcile_startup_jobs()
except Exception:
    logger.exception("Could not reconcile startup download jobs.")

auth_router, require_api_credentials = create_auth_api(auth_store)
app = FastAPI(title="TR4CKER API bridge")
app.include_router(auth_router)
download_jobs: Dict[str, Dict[str, Any]] = {}
download_jobs_lock = threading.Lock()


class LaunchTorrentBody(BaseModel):
    """Optional launch payload. `library` defaults to `audiobooks` when omitted and chooses between the configured folder targets."""

    library: str = "audiobooks"


class LegalBookDownloadBody(BaseModel):
    format: str


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
    owner_id: str,
    slug: str,
    info: str = "",
    download_dir: str = "",
    client: str = "pending",
    status: str = "preparing",
    phase: str = "preparing",
    message: str = "Preparing torrent metadata.",
) -> Dict[str, Any]:
    job_id = str(uuid.uuid4())
    now = time.time()
    try:
        db_job = auth_store.create_download_job(
            job_id=job_id,
            owner_id=owner_id,
            slug=slug,
            info=info,
            download_dir=download_dir,
            client=client,
            status=status,
            phase=phase,
            message=message,
            created_at=now,
            updated_at=now,
        )
    except Exception:
        logger.exception("Failed to persist download job to database.")
        db_job = {
            "job_id": job_id,
            "owner_id": owner_id,
            "slug": slug,
            "info": info,
            "download_dir": download_dir,
            "client": client,
            "status": status,
            "phase": phase,
            "message": message,
            "progress": None,
            "downloaded_bytes": 0,
            "total_bytes": None,
            "download_speed": 0,
            "eta_seconds": None,
            "created_at": now,
            "updated_at": now,
        }
    with download_jobs_lock:
        download_jobs[job_id] = dict(db_job)
    return dict(db_job)


def update_download_job(job_id: str, **updates: Any) -> None:
    now = time.time()
    with download_jobs_lock:
        job = download_jobs.get(job_id)
        if job is not None:
            job.update(updates)
            job["updated_at"] = now
    try:
        auth_store.update_download_job(job_id, updated_at=now, **updates)
    except Exception:
        logger.exception(
            "Failed to update download job in database for job_id=%s", job_id
        )


def public_download_job(job: Dict[str, Any]) -> Dict[str, Any]:
    return {key: value for key, value in job.items() if not key.startswith("_") and key != "owner_id"}


def monitor_download_job(job_id: str, process: subprocess.Popen[Any]) -> None:
    return_code = process.wait()
    if return_code == 0:
        update_download_job(
            job_id,
            status="handed_off",
            phase="monitoring",
            message="Launcher exited; transfer progress is unavailable.",
        )
    else:
        update_download_job(
            job_id,
            status="failed",
            phase="failed",
            message="The torrent launcher exited with an error.",
        )


def aria2_rpc(port: int, secret: str, method: str, *params: Any) -> Any:
    request_body = json.dumps(
        {
            "jsonrpc": "2.0",
            "id": "skyforge",
            "method": method,
            "params": [f"token:{secret}", *params],
        }
    ).encode("utf-8")
    request = urllib.request.Request(
        f"http://127.0.0.1:{port}/jsonrpc",
        data=request_body,
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(request, timeout=2) as response:
        result = json.loads(response.read().decode("utf-8"))
    if "error" in result:
        raise RuntimeError("aria2 RPC returned an error.")
    return result.get("result")


def _reserve_loopback_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as listener:
        listener.bind(("127.0.0.1", 0))
        return int(listener.getsockname()[1])


def _apply_aria2_status(job_id: str, status_data: Dict[str, Any]) -> bool:
    normalized = normalize_aria2_status(status_data)
    update_download_job(job_id, **normalized)
    return normalized["status"] in {"completed", "failed"}


def _stop_aria2_job(job_id: str) -> None:
    with download_jobs_lock:
        job = download_jobs.get(job_id)
        process = job.get("_aria2_process") if job else None
        port = job.get("_aria2_port") if job else None
        rpc_secret = job.get("_aria2_secret") if job else None
        config_path = job.get("_aria2_config_path") if job else None
    try:
        if process is None:
            return
        if port is not None and rpc_secret:
            try:
                aria2_rpc(port, rpc_secret, "aria2.forceShutdown")
            except (OSError, RuntimeError, urllib.error.URLError):
                pass
        try:
            process.wait(timeout=3)
        except subprocess.TimeoutExpired:
            process.terminate()
            try:
                process.wait(timeout=3)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=3)
    finally:
        if config_path:
            Path(config_path).unlink(missing_ok=True)


def _monitor_aria2_job(job_id: str) -> None:
    while True:
        with download_jobs_lock:
            job = download_jobs.get(job_id)
            if job is None:
                return
            port = job.get("_aria2_port")
            rpc_secret = job.get("_aria2_secret")
            gid = job.get("_aria2_gid")
            process = job.get("_aria2_process")
        if port is None or rpc_secret is None or gid is None:
            return
        try:
            status_data = aria2_rpc(
                port,
                rpc_secret,
                "aria2.tellStatus",
                gid,
                ["status", "totalLength", "completedLength", "downloadSpeed", "errorCode"],
            )
            if _apply_aria2_status(job_id, status_data):
                _stop_aria2_job(job_id)
                return
        except (OSError, RuntimeError, urllib.error.URLError, TimeoutError):
            if process is not None and process.poll() is not None:
                update_download_job(
                    job_id,
                    status="failed",
                    phase="failed",
                    message="aria2 stopped before the download completed.",
                )
                return
        time.sleep(2)


def _start_aria2_download(
    job_id: str,
    aria2: str,
    torrent_bytes: bytes,
    download_dir: str,
) -> None:
    port = _reserve_loopback_port()
    rpc_secret = secrets.token_urlsafe(32)
    with tempfile.NamedTemporaryFile(
        mode="w",
        encoding="utf-8",
        prefix="skyforge-aria2-",
        suffix=".conf",
        delete=False,
    ) as config_file:
        config_file.write(f"rpc-secret={rpc_secret}\n")
        config_path = config_file.name
    os.chmod(config_path, 0o600)
    process: subprocess.Popen[Any] | None = None
    try:
        process = subprocess.Popen(
            [
                aria2,
                "--enable-rpc=true",
                "--rpc-listen-all=false",
                f"--rpc-listen-port={port}",
                "--disable-ipv6=true",
                f"--dir={download_dir}",
                "--seed-time=0",
                "--console-log-level=warn",
                "--summary-interval=0",
                "--quiet=true",
                f"--conf-path={config_path}",
            ],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
    except Exception:
        Path(config_path).unlink(missing_ok=True)
        raise
    update_download_job(
        job_id,
        client="aria2c",
        status="starting",
        phase="starting",
        message="Adding the torrent to aria2.",
        _aria2_process=process,
        _aria2_port=port,
        _aria2_secret=rpc_secret,
        _aria2_config_path=config_path,
    )
    try:
        gid = None
        encoded_torrent = base64.b64encode(torrent_bytes).decode("ascii")
        for _ in range(40):
            if process.poll() is not None:
                raise RuntimeError("aria2 exited during startup.")
            try:
                gid = aria2_rpc(
                    port,
                    rpc_secret,
                    "aria2.addTorrent",
                    encoded_torrent,
                    [],
                    {"dir": download_dir, "seed-time": "0"},
                )
                break
            except (OSError, urllib.error.URLError, TimeoutError):
                time.sleep(0.1)
        if not gid:
            raise RuntimeError("aria2 RPC did not become ready.")
        update_download_job(
            job_id,
            status="running",
            phase="queued",
            message="Queued in aria2.",
            _aria2_gid=gid,
        )
        threading.Thread(target=_monitor_aria2_job, args=(job_id,), daemon=True).start()
    except Exception:
        try:
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=3)
        finally:
            Path(config_path).unlink(missing_ok=True)
        raise


@app.get("/api/downloads")
def list_downloads(
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0),
    credentials: Dict[str, Any] = Depends(require_api_credentials),
) -> list[Dict[str, Any]]:
    user_id = credentials["user_id"]
    try:
        db_jobs = auth_store.list_download_jobs(user_id, limit=limit, offset=offset)
    except Exception:
        logger.exception("Failed to list download jobs from database.")
        with download_jobs_lock:
            db_jobs = sorted(
                (j for j in download_jobs.values() if j.get("owner_id") == user_id),
                key=lambda job: (
                    job.get("updated_at", 0),
                    job.get("created_at", 0),
                    job["job_id"],
                ),
                reverse=True,
            )[offset : offset + limit]

    results: list[Dict[str, Any]] = []
    for job in db_jobs:
        job_id = job["job_id"]
        with download_jobs_lock:
            mem_job = download_jobs.get(job_id)
        if (
            mem_job
            and mem_job.get("client") == "aria2c"
            and mem_job.get("status") in {"starting", "running"}
            and mem_job.get("_aria2_port")
            and mem_job.get("_aria2_secret")
            and mem_job.get("_aria2_gid")
        ):
            try:
                status_data = aria2_rpc(
                    mem_job["_aria2_port"],
                    mem_job["_aria2_secret"],
                    "aria2.tellStatus",
                    mem_job["_aria2_gid"],
                    ["status", "totalLength", "completedLength", "downloadSpeed", "errorCode"],
                )
                _apply_aria2_status(job_id, status_data)
                with download_jobs_lock:
                    mem_job = download_jobs.get(job_id)
                if mem_job:
                    job = mem_job
            except (OSError, RuntimeError, urllib.error.URLError, TimeoutError):
                pass
        results.append(public_download_job(job))
    return results


@app.get("/api/downloads/{job_id}")
def get_download_status(
    job_id: str,
    credentials: Dict[str, Any] = Depends(require_api_credentials),
) -> Dict[str, Any]:
    with download_jobs_lock:
        job = download_jobs.get(job_id)
    if job is None:
        try:
            job = auth_store.get_download_job(job_id, owner_id=credentials["user_id"])
        except Exception:
            logger.exception("Failed to query download job from database for job_id=%s", job_id)
            job = None

    if job is None or job.get("owner_id") != credentials["user_id"]:
        raise HTTPException(status_code=404, detail="Download job not found.")

    response = public_download_job(job)
    with download_jobs_lock:
        mem_job = download_jobs.get(job_id)
    if (
        mem_job
        and mem_job.get("client") == "aria2c"
        and mem_job.get("status") in {"starting", "running"}
        and mem_job.get("_aria2_port")
        and mem_job.get("_aria2_secret")
        and mem_job.get("_aria2_gid")
    ):
        try:
            status_data = aria2_rpc(
                mem_job["_aria2_port"],
                mem_job["_aria2_secret"],
                "aria2.tellStatus",
                mem_job["_aria2_gid"],
                ["status", "totalLength", "completedLength", "downloadSpeed", "errorCode"],
            )
            _apply_aria2_status(job_id, status_data)
            with download_jobs_lock:
                response = public_download_job(download_jobs[job_id])
        except (OSError, RuntimeError, urllib.error.URLError, TimeoutError):
            pass
    return response


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


@app.get("/api/books/free/search")
def search_free_books(
    q: str = Query(..., min_length=2, max_length=120),
    lang: str = Query("fr", min_length=2, max_length=2),
    _credentials: Dict[str, Any] = Depends(require_api_credentials),
) -> Dict[str, Any]:
    try:
        results = search_legal_books(q, language=lang)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    except LegalBooksError as exc:
        logger.warning("Legal-book catalog request failed: %s", exc)
        raise HTTPException(
            status_code=502,
            detail="The legal-book catalog is temporarily unavailable.",
        ) from exc
    return {"language": lang.lower(), "results": results}


def _prepare_legal_book_download(
    job_id: str, volume_id: str, file_format: str
) -> None:
    try:
        books_dir = resolve_download_dir("books")
        saved_path = download_legal_book(volume_id, file_format, books_dir)
        size = saved_path.stat().st_size
        update_download_job(
            job_id,
            info=saved_path.stem,
            download_dir=str(saved_path.parent),
            client="project_gutenberg",
            status="completed",
            phase="completed",
            message=f"Saved {saved_path.name}",
            progress=1.0,
            downloaded_bytes=size,
            total_bytes=size,
        )
    except FileExistsError:
        update_download_job(
            job_id,
            status="failed",
            phase="failed",
            message="This book format is already saved in the Books folder.",
        )
    except Exception:
        logger.exception("Could not save legal book for job_id=%s", job_id)
        update_download_job(
            job_id,
            status="failed",
            phase="failed",
            message="Could not verify or save this book. Check the bridge logs.",
        )


@app.post("/api/books/free/{book_id}/download", status_code=202)
def download_free_book(
    book_id: str,
    background_tasks: BackgroundTasks,
    body: LegalBookDownloadBody,
    credentials: Dict[str, Any] = Depends(require_api_credentials),
) -> Dict[str, Any]:
    try:
        validate_download_request(book_id, body.format)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc

    books_dir = resolve_download_dir("books")
    job = register_download_job(
        owner_id=credentials["user_id"],
        slug=book_id,
        info=f"Project Gutenberg {book_id}",
        download_dir=str(books_dir),
        client="project_gutenberg",
        status="preparing",
        phase="preparing",
        message="Verifying the EPUB listing and preparing the file.",
    )
    background_tasks.add_task(
        _prepare_legal_book_download,
        job["job_id"],
        book_id,
        body.format,
    )
    return public_download_job(job)


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


def _prepare_and_launch_download(job_id: str, slug: str, library: str) -> None:
    torrent_path: str | None = None
    try:
        response = request_tr4cker(f"{API_BASE_URL}/torrents/{slug}/download", stream=True)
        try:
            raw_bytes = response.content
        finally:
            response.close()
        if not raw_bytes:
            raise ValueError("The upstream torrent file is empty.")

        download_dir = resolve_download_dir(library)
        download_dir.mkdir(parents=True, exist_ok=True)
        download_dir_str = str(download_dir)
        with tempfile.NamedTemporaryFile(suffix=".torrent", delete=False) as temp_file:
            torrent_path = temp_file.name
            temp_file.write(raw_bytes)

        parsed = Torrent.from_file(torrent_path)
        update_download_job(
            job_id,
            info=parsed.name,
            download_dir=download_dir_str,
            status="starting",
            phase="starting",
            message="Torrent metadata is ready; starting the download client.",
            _torrent_path=torrent_path,
        )

        launch_command = os.getenv("TORRENT_LAUNCH_COMMAND")
        client_command = os.getenv("TORRENT_CLIENT_COMMAND")
        if launch_command or client_command:
            command_template = launch_command or client_command
            command = command_template.format(
                torrent_path=torrent_path,
                slug=slug,
                download_dir=download_dir_str,
            )
            process = subprocess.Popen(command, shell=True, start_new_session=True)
            client = "configured"
            update_download_job(
                job_id,
                client=client,
                status="running",
                phase="monitoring",
                message="External client started; transfer progress is unavailable.",
            )
            threading.Thread(
                target=monitor_download_job,
                args=(job_id, process),
                daemon=True,
            ).start()
            return

        aria2 = local_aria2_path() or shutil.which("aria2c")
        if aria2:
            _start_aria2_download(job_id, aria2, raw_bytes, download_dir_str)
            Path(torrent_path).unlink(missing_ok=True)
            return

        system = platform.system()
        if system == "Windows":
            os.startfile(torrent_path)  # type: ignore[attr-defined]
            update_download_job(
                job_id,
                client="default_file_association",
                status="unknown",
                phase="handed_off",
                message="Torrent opened in the default client; transfer progress is unavailable.",
            )
            return

        opener = "xdg-open" if system == "Linux" else "open"
        opener_path = shutil.which(opener)
        if opener_path:
            process = subprocess.Popen([opener_path, torrent_path], start_new_session=True)
            update_download_job(
                job_id,
                client=opener,
                status="running",
                phase="monitoring",
                message="Torrent opened in an external client; transfer progress is unavailable.",
            )
            threading.Thread(
                target=monitor_download_job,
                args=(job_id, process),
                daemon=True,
            ).start()
            return
        raise RuntimeError(
            "No torrent launcher is configured. Set TORRENT_LAUNCH_COMMAND or TORRENT_CLIENT_COMMAND, or install aria2c."
        )
    except Exception:
        logger.exception("Download preparation or launcher failed for job_id=%s", job_id)
        if torrent_path is not None:
            Path(torrent_path).unlink(missing_ok=True)
        update_download_job(
            job_id,
            status="failed",
            phase="failed",
            message="Could not prepare or start this download. Check the bridge logs.",
        )


@app.post("/api/torrents/{slug}/launch")
def launch_torrent_download(
    slug: str,
    background_tasks: BackgroundTasks,
    body: Optional[LaunchTorrentBody] = Body(default=None),
    credentials: Dict[str, Any] = Depends(require_api_credentials),
) -> Dict[str, Any]:
    """Return a progress job immediately and prepare/launch in the background."""
    library_value = body.library if body else "audiobooks"
    job = register_download_job(owner_id=credentials["user_id"], slug=slug)
    background_tasks.add_task(_prepare_and_launch_download, job["job_id"], slug, library_value)
    return public_download_job(job)


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
