from __future__ import annotations

from typing import Any


def _integer(value: Any) -> int:
    try:
        return max(0, int(value or 0))
    except (TypeError, ValueError):
        return 0


def normalize_aria2_status(payload: dict[str, Any]) -> dict[str, Any]:
    aria_status = str(payload.get("status", "unknown"))
    total_bytes = _integer(payload.get("totalLength"))
    downloaded_bytes = _integer(payload.get("completedLength"))
    download_speed = _integer(payload.get("downloadSpeed"))
    error_code = str(payload.get("errorCode", "0"))

    if aria_status == "complete":
        status, phase, message, progress, eta = (
            "completed",
            "completed",
            "Download completed.",
            1.0,
            0,
        )
    elif aria_status in {"error", "removed"} or error_code not in {"", "0"}:
        status, phase, message, progress, eta = (
            "failed",
            "failed",
            "aria2 could not complete this download.",
            None,
            None,
        )
    else:
        status = "running"
        if aria_status == "waiting":
            phase, message = "queued", "Waiting for aria2 to start."
        elif aria_status == "paused":
            phase, message = "paused", "Download paused."
        else:
            phase, message = "downloading", "Downloading with aria2."
        progress = min(downloaded_bytes / total_bytes, 1.0) if total_bytes else None
        eta = (
            max(0, int((total_bytes - downloaded_bytes) / download_speed))
            if total_bytes and download_speed > 0
            else None
        )

    return {
        "status": status,
        "phase": phase,
        "message": message,
        "progress": progress,
        "downloaded_bytes": downloaded_bytes,
        "total_bytes": total_bytes or None,
        "download_speed": download_speed,
        "eta_seconds": eta,
    }
