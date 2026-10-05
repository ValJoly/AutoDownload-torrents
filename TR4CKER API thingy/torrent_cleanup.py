from __future__ import annotations

from pathlib import Path
from typing import Iterable


def _resolve_under_roots(path: Path, library_roots: Iterable[Path]) -> Path | None:
    if not path.is_absolute() or "\0" in str(path):
        return None
    try:
        resolved = path.resolve()
    except (OSError, RuntimeError, ValueError):
        return None
    for root in library_roots:
        try:
            resolved_root = root.resolve()
        except (OSError, RuntimeError, ValueError):
            continue
        try:
            relative = resolved.relative_to(resolved_root)
        except ValueError:
            continue
        if relative.parts:
            return resolved
    return None


def aria2_sidecar_paths(
    output_paths: Iterable[str], library_roots: Iterable[Path]
) -> list[str]:
    roots = tuple(library_roots)
    sidecars = []
    for output in output_paths:
        output_path = Path(output)
        if _resolve_under_roots(output_path, roots) is None:
            continue
        sidecar = Path(f"{output_path}.aria2")
        if _resolve_under_roots(sidecar, roots) is not None:
            sidecars.append(str(sidecar))
    return sidecars


def delete_aria2_sidecars(
    sidecar_paths: Iterable[str], library_roots: Iterable[Path]
) -> None:
    roots = tuple(library_roots)
    for raw_path in sidecar_paths:
        path = Path(raw_path)
        if path.suffix.lower() != ".aria2":
            continue
        safe_path = _resolve_under_roots(path, roots)
        if safe_path is not None and safe_path.is_file():
            safe_path.unlink()