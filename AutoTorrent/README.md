# AutoTorrent

Flutter mobile client for the local **TR4CKER API bridge** in the sibling
`TR4CKER API thingy` folder.

## Run

From this folder:

```bash
flutter pub get
flutter run
```

The app starts with `http://localhost:8384`. On a phone, open the settings
button and replace this with the computer's LAN address, for example
`http://192.168.1.10:8384`. Start the bridge on the computer with Uvicorn
bound to the LAN interface:

```bash
uvicorn main:app --host 0.0.0.0 --port 8384
```

The app searches `GET /api/torrents` and sends `POST /api/torrents/{slug}/launch`
with the selected `library` (`audiobooks` or `books`).
