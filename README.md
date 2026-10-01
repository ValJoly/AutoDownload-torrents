# SkyForge

SkyForge is a Flutter-first torrent discovery and download companion for book and audiobook collections. It pairs a mobile UI with a small FastAPI bridge that forwards searches to the public TR4CKER API, downloads `.torrent` files, and can launch an installed torrent client or an `aria2c` session.

## Project structure

This workspace contains two connected parts:

- `AutoTorrent/` — the Flutter application UI.
- `TR4CKER API thingy/` — the FastAPI bridge and Docker packaging.

## Features

- Search and browse torrent results from TR4CKER.
- Search books separately in the Free books catalog; only books marked public domain for France with a direct supported format are offered.
- Save eligible EPUB/PDF books to the bridge computer's configured Books folder and see them in download history.
- Download `.torrent` files from the bridge.
- Launch torrent files from the configured command, an installed client, or `aria2c`.
- Persist the bridge URL in the mobile settings.
- Serve the API through dual-stack IPv4/IPv6 support where supported.
- Package the service as a Docker container and Compose service.

## Tech stack

- Flutter / Dart UI.
- FastAPI + Uvicorn bridge.
- TR4CKER public API integration.
- Docker and Compose packaging for the service.

## Local development

### Flutter app

```bash
cd AutoTorrent
flutter pub get
flutter run
```

### Bridge service

```bash
cd "TR4CKER API thingy"
python -m pip install -r requirements.txt
python main.py
```

The service expects a `TR4CKER_API_KEY` in the environment or an `.env` file.
The separate Free books search also requires `GOOGLE_BOOKS_API_KEY` in the bridge `.env`; Google Books applies region-specific access based on the bridge server's IP.

## Docker

```bash
cd "TR4CKER API thingy"
docker compose up --build -d
```

The container is configured to expose port `8384` and uses the environment file `.env`.

## Repository goals

SkyForge is designed to turn torrent lookups and file launches into a simple mobile workflow for book and audiobook collectors while keeping the bridge service small, portable, and container-friendly.
