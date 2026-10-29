# SkyForge API Bridge

A small FastAPI service that forwards search, details, and download requests to the public TR4CKER API and adds a local torrent launch flow for the SkyForge Flutter client.

## What the service does

This service exposes a compact HTTP layer for the app:

- Forwards TR4CKER search, details, and download requests, and searches C411 through its Torznab API.
- Streams `.torrent` files to the client.
- Persists per-user launch/download job metadata in PostgreSQL.
- Starts a local torrent client or `aria2c` when the user triggers launch.
- Reports aria2 byte/percentage/speed/ETA progress and lifecycle-only status for external launchers.
- Removes tracked aria2 `.aria2` sidecars after completed downloads and retries cleanup for completed jobs on startup.
- Supports dual-stack IPv4/IPv6 listeners when configured.

Cleanup is limited to exact aria2 sidecar paths recorded for completed jobs and
resolved beneath the configured Books or Audiobooks directory. Interrupted
downloads retain their resume sidecars. Existing `.aria2` or `.torrent` files
without a bridge ownership record are not swept; bridge-created `.torrent`
inputs are temporary files outside the library folders.

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
- `C411_API_KEY` — optional; C411 API key from the account's integrations page.
- `GOOGLE_BOOKS_API_KEY` — optional. Used only for preview-only search fallback when Gutendex times out or has no matching results.
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
- `GET /api/providers` — report whether TR4CKER and C411 are configured without returning API keys.
- `POST /api/auth/login` — authenticate with `{"username": "...", "password": "..."}` and receive a bearer session.
- `POST /api/auth/register` — redeem an invitation with `{"code": "...", "username": "...", "password": "..."}` and receive a member session.
- `GET /api/auth/me` — return the authenticated account.
- `POST /api/auth/logout` — revoke the current bearer session.
- `POST /api/auth/invites` — owner-only; create a one-use invitation and return its code once.
- `GET /api/auth/invites` — owner-only; list invitation status without returning codes.
- `DELETE /api/auth/invites/{invite_id}` — owner-only; revoke an active invitation.
- `GET /api/torrents?q={query}&cat={category}&source={tr4cker|c411}` — search torrents. `source` defaults to `tr4cker`; C411 uses `https://c411.org/api/torznab` with `t=search`. C411 category values map `livres-audio` to `3030` and `livres` to `7020`. Requests honor Jackett's configured 4.1-second interval.
- `POST /api/torrents/{slug}/launch` — accepts `{"library":"audiobooks","source":"c411"}` for C411 results; `source` defaults to `tr4cker`.
- `GET /api/books/search` — search books with the supplied filter map.
- `GET /api/torrents/{slug}` — fetch torrent detail metadata.
- `GET /api/torrents/{slug}/download` — stream the `.torrent` file.
- `GET /api/books/free/search?q={query}&lang={language}&gutenberg_only={true|false}` — search Gutendex first; `lang` defaults to `fr` and supports `fr`, `en`, `es`, `de`, `it`, or `pt`. `gutenberg_only=true` disables Google Books fallback; otherwise, if Gutendex is slow or returns no matches and `GOOGLE_BOOKS_API_KEY` is configured, Google Books preview results may be returned.
- `POST /api/books/free/{book_id}/download` with `{"format":"epub"}` — revalidate the Gutendex record and save its EPUB under the configured Books folder. Jobs appear in the authenticated user's downloads history. The bridge never accepts a client-supplied download URL.
- `POST /api/torrents/{slug}/launch` — download the `.torrent` file and attempt to launch a local client. All `/api` routes except provider availability require a bearer session.
- `GET /api/downloads?limit=50&offset=0` — list the authenticated user's saved download jobs, newest-updated first. `limit` must be between 1 and 100; `offset` is zero-based.
- `GET /api/downloads/{job_id}` — fetch the latest progress for a job owned by the authenticated user.

Launch returns a job immediately while the bridge fetches and validates the
torrent metadata. When `aria2c` is available, the bridge uses its JSON-RPC
interface bound to loopback only to report real downloaded/total bytes, speed,
and ETA. The RPC port and secret are not exposed to the app or published by
Compose. Custom commands and OS file associations report preparation and
handoff states only; SkyForge does not invent percentage progress for clients
that do not provide telemetry. Job details are persisted in PostgreSQL and can
be listed after the Flutter app is reopened. A bridge restart marks jobs that
were still active as interrupted; it does not resume their torrent-client
processes.

The separate Free books catalog tries Gutendex first and defaults to French;
English, Spanish, German, Italian, and Portuguese are also available. If
Gutendex times out or has no matches, the bridge can use Google Books for
preview-only results when `GOOGLE_BOOKS_API_KEY` is configured. Only Gutendex
records with an EPUB are saved locally; the bridge re-fetches the record and
validates the provider URL and downloaded file. Project Gutenberg's copyright
flag reflects US status only and is not a determination of rights in other
countries.

## Notes

The Docker image installs the system `aria2` package so Linux containers do not fail when the app falls back to `aria2c` for launching `.torrent` files. A repository-local Windows binary bundle remains available for Windows hosts only.
