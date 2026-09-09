# TR4CKER API bridge

> A small FastAPI bridge that forwards requests to the public TR4CKER API (https://tr4ker.net/api) and provides convenience endpoints for searching, downloading, and launching torrents.

## What this project does
- Exposes a lightweight HTTP API that forwards queries to the TR4CKER API using a required API key.
- Adds convenience endpoints to stream and download `.torrent` files and to launch a torrent client on the host machine.

## Files
- `main.py`: FastAPI application and HTTP endpoints.
- `torrents_classes.py`: Typed dataclasses and helpers for the search/listing response.
- `torrent_details.py`: Typed dataclass and helpers for the torrent details response.
- `Doc`: Project documentation and architecture notes.

## Requirements
- Python 3.10+
- Packages: `fastapi`, `uvicorn`, `requests`, `python-dotenv`

Install dependencies:

```bash
python -m pip install fastapi uvicorn requests python-dotenv
```

## Environment
Create a `.env` file in the project root or set environment variables in your system. The following variables are supported:

- `TR4CKER_API_KEY` (required): API key for `tr4ker.net`.
- `TR4CKER_API_DUAL_STACK` (optional): If `true` (default), the server starts one IPv6 listener and one IPv4 listener in the same process, letting the bridge answer on both families at once.
- `TR4CKER_API_IPV6_HOST` (optional): IPv6 bind host for the IPv6 listener. Defaults to `::`.
- `TR4CKER_API_IPV4_HOST` (optional): IPv4 bind host for the IPv4 listener. Defaults to `0.0.0.0`.
- `TR4CKER_API_HOST` (optional): Single-host override when `TR4CKER_API_DUAL_STACK=false`. Use `0.0.0.0` for IPv4-only or `::` for IPv6-only.
- `TR4CKER_API_PORT` (optional): TCP port for the Uvicorn server. Defaults to `8384`.
- `TR4CKER_API_RELOAD` (optional): Toggle Uvicorn reload mode. Defaults to `false` in the dual-stack launcher because reload mode is incompatible with running multiple listeners in the same process.
- `TORRENT_DOWNLOAD_DIR` (optional): Directory where downloaded torrents will be saved.
- `TORRENT_LAUNCH_COMMAND` (optional): A shell command with placeholders to launch a torrent, e.g. `"C:\\Program Files\\qBittorrent\\qbittorrent.exe" "{torrent_path}"` or `transmission-gtk "{torrent_path}"`.
- `TORRENT_CLIENT_COMMAND` (optional): Alternative launch command. If both `TORRENT_LAUNCH_COMMAND` and `TORRENT_CLIENT_COMMAND` are unset, the app will try `aria2c`, `xdg-open`/`open`, or Windows file association.

Example `.env`:

```
TR4CKER_API_KEY=your_api_key_here
TORRENT_DOWNLOAD_DIR=C:\\Users\\you\\Downloads
```

## Running

Run with Uvicorn (development):

```bash
uvicorn main:app --host localhost --port 8384 --reload
```

Or run directly:

```bash
python main.py
```

## Exposed endpoints
- `GET /health` — simple health check.
- `GET /api/torrents?q={query}&cat={category}` — forward search to TR4CKER. `cat` defaults to `livres-audio`.
- `GET /api/torrents/{slug}` — get torrent details for `slug`.
- `GET /api/torrents/{slug}/download` — stream the `.torrent` file as an attachment.
- `POST /api/torrents/{slug}/launch` — download the `.torrent` file and attempt to launch it with a torrent client on the host.
- `GET /api/downloads/{job_id}` — return the latest in-memory status for a launched download (`running`, `completed`, or `failed`).

## Usage examples

Search (curl):

```bash
curl "http://localhost:8384/api/torrents?q=some+book&cat=livres-audio"
```

Download torrent (curl):

```bash
curl -OJ "http://localhost:8384/api/torrents/some-slug/download"
```

Launch torrent (server will attempt to start a client):

```bash
curl -X POST "http://localhost:8384/api/torrents/some-slug/launch"
```

The launch response includes a `job_id`. Poll that ID while the server-side
torrent client is running:

```bash
curl "http://localhost:8384/api/downloads/{job_id}"
```

Status jobs are kept in memory and reset when the bridge restarts. Progress is
currently reported as `null`; the app displays an indeterminate progress bar
until the client exits.

Python example calling the local bridge:

```python
import requests

resp = requests.get("http://localhost:8384/api/torrents", params={"q": "my search"})
print(resp.json())
```

## Implementation notes
- The helper `request_tr4cker()` centralizes the HTTP request and raises FastAPI `HTTPException` on upstream errors.
- The `/launch` endpoint will write a temporary `.torrent` file and try these strategies in order: `TORRENT_LAUNCH_COMMAND`, `TORRENT_CLIENT_COMMAND`, `aria2c` (if available), Windows `os.startfile`, or `xdg-open`/`open`.
- The typed response models in `torrents_classes.py` and `torrent_details.py` are convenience helpers for mapping JSON responses to Python dataclasses.

## Security & legal
- This project simply forwards requests to TR4CKER and can save and launch torrent files on the host. Ensure you comply with local laws and the TR4CKER API terms of service.

## Next steps / improvements
- Add tests for the API wrapper.
- Add proper logging and rate-limiting.
- Add unit tests around the launch strategies and environment variable handling.

---
See the `Doc` file for more detailed architecture notes and the response data model.
