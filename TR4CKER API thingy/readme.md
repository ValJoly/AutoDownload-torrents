# SkyForge API Bridge

A small FastAPI service that forwards search, details, and download requests to the public TR4CKER API and adds a local torrent launch flow for the SkyForge Flutter client.

## What the service does

This service exposes a compact HTTP layer for the app:

- Forwards TR4CKER search, details, and download requests.
- Streams `.torrent` files to the client.
- Stores launch/download job metadata in memory.
- Starts a local torrent client or `aria2c` when the user triggers launch.
- Reports aria2 byte/percentage/speed/ETA progress and lifecycle-only status for external launchers.
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
- `POSTGRES_DB`, `POSTGRES_USER`, and `POSTGRES_PASSWORD` — credentials used by the PostgreSQL service.
- `SKYFORGE_DATABASE_URL` — connection URL for the API and owner-provisioning command.

If `.env` does not exist, copy `.env.example` to `.env`; otherwise merge the
required PostgreSQL entries into the existing file so you do not overwrite your
TR4CKER key. Replace every placeholder and keep `.env` private. The PostgreSQL
password in `SKYFORGE_DATABASE_URL` must be URL-encoded; using a generated
hexadecimal password avoids URL escaping issues.

Create the first owner locally with `python provision_owner.py`, or in Compose
with `docker compose exec skyforge python provision_owner.py`. This prompts for
the username and password and can succeed only while the database has no users.
The owner signs in to the app, creates invitations in the Invitations screen,
and shares each code with one new member. Codes expire after seven days by
default, can be revoked before use, and are displayed only when created. A new
member chooses a username and password in the app's invite-based sign-up flow.
The app signs in through `POST /api/auth/login` or registers through
`POST /api/auth/register`; protected requests use a revocable bearer token. Do
not expose this bridge over public plain HTTP; use a trusted VPN or terminate
HTTPS in front of it.

## Run locally

For local development, provide a reachable PostgreSQL instance and set
`SKYFORGE_DATABASE_URL` in `.env` before launching the API.

```bash
python main.py
```

Or run the FastAPI app with Uvicorn:

```bash
uvicorn main:app --host 0.0.0.0 --port 8384 --reload
```

## Run with Docker

Run the complete API and PostgreSQL stack with Compose:

```bash
docker compose up --build -d
```

Compose mounts `I:\Books` to `/downloads` and overrides the container's
`TORRENT_DOWNLOAD_DIR` to `/downloads`. The existing library layout is
preserved, so downloads are written to `I:\Books\Books` or
`I:\Books\Audiobooks`. Set `TORRENT_HOST_DOWNLOAD_DIR` in the Compose
environment if the host folder is different. Docker Desktop must be allowed
to access the drive.

Compose stores PostgreSQL data in the named `postgres_data` volume and does not
publish the database port on the host. The ignored `data/` directory is mounted
read-only into SkyForge only for an optional legacy SQLite import. The host
download directory remains a separate bind mount.

### Migrating from the previous SQLite deployment

Stop the old bridge before migration and make a separate backup of
`data/skyforge.sqlite3`. Merge PostgreSQL credentials and `SKYFORGE_DATABASE_URL`
from `.env.example` into `.env` without overwriting existing secrets, then start
only the database:

```bash
docker compose up -d db
```

Import accounts and invitation state before starting the API:

```bash
docker compose run --rm skyforge python import_sqlite_auth.py /migration/skyforge.sqlite3
docker compose up -d skyforge
```

The importer refuses a populated PostgreSQL auth database, preserves user
password hashes and invite status, and deliberately omits old sessions. Users
must sign in again. It never modifies or deletes the SQLite source. If this is a
fresh install, skip the import and provision the first owner after starting the
stack. Keep the SQLite backup until owner sign-in and invite flows have been
verified against PostgreSQL.

To roll back before accepting the migration, stop the new stack and restore the
previous application/database backup together. Do not point an old SQLite-backed
application at the PostgreSQL volume. Back up the PostgreSQL named volume using
`pg_dump` before upgrades; keep PostgreSQL on the pinned major version and use
the PostgreSQL upgrade procedure before changing major versions.

Back up the database to a custom-format dump with:

```bash
docker compose exec -T db sh -c 'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc' > skyforge.dump
```

Restore into a stopped/maintenance stack with:

```bash
docker compose exec -T db sh -c 'pg_restore -U "$POSTGRES_USER" -d "$POSTGRES_DB" --clean --if-exists' < skyforge.dump
```

Provision a fresh Compose owner only after the database is healthy:

```bash
docker compose exec skyforge python provision_owner.py
```

Backend tests use an isolated PostgreSQL database; set
`SKYFORGE_TEST_DATABASE_URL` before running `python -m pytest -q`.

## Exposed endpoints

- `GET /health` — health check.
- `POST /api/auth/login` — authenticate with `{"username": "...", "password": "..."}` and receive a bearer session.
- `POST /api/auth/register` — redeem an invitation with `{"code": "...", "username": "...", "password": "..."}` and receive a member session.
- `GET /api/auth/me` — return the authenticated account.
- `POST /api/auth/logout` — revoke the current bearer session.
- `POST /api/auth/invites` — owner-only; create a one-use invitation and return its code once.
- `GET /api/auth/invites` — owner-only; list invitation status without returning codes.
- `DELETE /api/auth/invites/{invite_id}` — owner-only; revoke an active invitation.
- `GET /api/torrents?q={query}&cat={category}` — forward search requests to TR4CKER.
- `GET /api/books/search` — search books with the supplied filter map.
- `GET /api/torrents/{slug}` — fetch torrent detail metadata.
- `GET /api/torrents/{slug}/download` — stream the `.torrent` file.
- `POST /api/torrents/{slug}/launch` — download the `.torrent` file and attempt to launch a local client. This route and other `/api` routes require a bearer session.
- `GET /api/downloads/{job_id}` — fetch the latest progress for a job owned by the authenticated user.

Launch returns a job immediately while the bridge fetches and validates the
torrent metadata. When `aria2c` is available, the bridge uses its JSON-RPC
interface bound to loopback only to report real downloaded/total bytes, speed,
and ETA. The RPC port and secret are not exposed to the app or published by
Compose. Custom commands and OS file associations report preparation and
handoff states only; SkyForge does not invent percentage progress for clients
that do not provide telemetry. Jobs remain in memory and disappear when the
bridge restarts.

## Notes

The Docker image installs the system `aria2` package so Linux containers do not fail when the app falls back to `aria2c` for launching `.torrent` files. A repository-local Windows binary bundle remains available for Windows hosts only.
