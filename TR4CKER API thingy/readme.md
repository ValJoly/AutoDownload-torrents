# SkyForge API Bridge

A small FastAPI service that forwards search, details, and download requests to the public TR4CKER API and adds a local torrent launch flow for the SkyForge Flutter client.

## What the service does

This service exposes a compact HTTP layer for the app:

- Forwards TR4CKER search, details, and download requests.
- Streams `.torrent` files to the client.
- Stores launch/download job metadata in memory.
- Starts a local torrent client or `aria2c` when the user triggers launch.
- Supports dual-stack IPv4/IPv6 listeners when configured.

## Repository layout

- `main.py` — FastAPI app, routes, launch orchestration, and Uvicorn bootstrap.
- `torrents_classes.py` — typed helpers for torrent search/listing models.
- `torrent_details.py` — typed helpers for torrent detail responses.
- `Dockerfile` — container definition for the service.
- `docker-compose.yml` — Compose file for local deployment.

## Requirements

- Python 3.11+
- Packages listed in `requirements.txt`
- A valid `TR4CKER_API_KEY` in the environment or `.env`

Install dependencies:

```bash
python -m pip install -r requirements.txt
```

## Environment variables

Create a `.env` file in the service folder or export the keys in your shell.

```env
TR4CKER_API_KEY=your_api_key_here
TORRENT_DOWNLOAD_DIR=C:\Users\you\Downloads
# Used only by Docker Compose; this is the Windows folder shared with the container.
TORRENT_HOST_DOWNLOAD_DIR=I:/Books
SKYFORGE_AUTH_ENABLED=true
SKYFORGE_AUTH_USERNAME=skyforge
SKYFORGE_AUTH_PASSWORD=change-me
```

Supported variables:

- `TR4CKER_API_KEY` — required.
- `TR4CKER_API_DUAL_STACK` — enable IPv4 and IPv6 listeners together.
- `TR4CKER_API_IPV6_HOST` — IPv6 bind address for the IPv6 listener.
- `TR4CKER_API_IPV4_HOST` — IPv4 bind address for the IPv4 listener.
- `TR4CKER_API_HOST` — single-host override when dual-stack is disabled.
- `TR4CKER_API_PORT` — service port, default `8384`.
- `TR4CKER_API_RELOAD` — enable reload mode for development.
- `TORRENT_DOWNLOAD_DIR` — base path where torrent targets are stored.
- `TORRENT_HOST_DOWNLOAD_DIR` — Windows host folder mounted as `/downloads` in Docker; defaults to `I:/Books`.
- `TORRENT_LAUNCH_COMMAND` — a custom launch shell command.
- `TORRENT_CLIENT_COMMAND` — alternative client launch command.
- `SKYFORGE_AUTH_ENABLED` — enable HTTP Basic authentication for the API routes.
- `SKYFORGE_AUTH_USERNAME` — username expected by the API routes.
- `SKYFORGE_AUTH_PASSWORD` — password expected by the API routes.

The app settings page should carry the same username and password pair. The bridge client sends them as an `Authorization: Basic base64(username:password)` header on every protected API request.

## Run locally

Use the app directly:

```bash
python main.py
```

Or run the FastAPI app with Uvicorn:

```bash
uvicorn main:app --host 0.0.0.0 --port 8384 --reload
```

## Run with Docker

The container can be started with Compose:

```bash
docker compose up --build -d
```

Compose mounts `I:\Books` to `/downloads` and overrides the container's
`TORRENT_DOWNLOAD_DIR` to `/downloads`. The existing library layout is
preserved, so downloads are written to `I:\Books\Books` or
`I:\Books\Audiobooks`. Set `TORRENT_HOST_DOWNLOAD_DIR` in the Compose
environment if the host folder is different. Docker Desktop must be allowed
to access the drive.

Or directly:

```bash
docker build -t skyforge:latest .
docker run --name SkyForge -p 8384:8384 \
  -v "I:/Books:/downloads" \
  -e TORRENT_DOWNLOAD_DIR=/downloads \
  --env-file .env -d skyforge:latest
```

## Exposed endpoints

- `GET /health` — health check.
- `GET /api/torrents?q={query}&cat={category}` — forward search requests to TR4CKER.
- `GET /api/torrents/{slug}` — fetch torrent detail metadata.
- `GET /api/torrents/{slug}/download` — stream the `.torrent` file.
- `POST /api/torrents/{slug}/launch` — download the `.torrent` file and attempt to launch a local client. This route is protected by the configured Basic Auth username/password pair in `SKYFORGE_AUTH_USERNAME` and `SKYFORGE_AUTH_PASSWORD`.
- `GET /api/downloads/{job_id}` — fetch the latest download job state.

## Notes

The Docker image installs the system `aria2` package so Linux containers do not fail when the app falls back to `aria2c` for launching `.torrent` files. A repository-local Windows binary bundle remains available for Windows hosts only.
