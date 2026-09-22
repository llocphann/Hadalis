#!/usr/bin/env python3
"""Create one filesystem-canonical Zettelkasten note for a Hadalis quick note."""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
from datetime import datetime
from pathlib import Path, PurePosixPath
from typing import Any


class ZettelError(Exception):
    def __init__(self, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code
        self.message = message


def _resolve_vault(vault_path: str) -> Path:
    raw = str(vault_path or "").strip()
    if not raw:
        raise ZettelError("invalid_vault_path", "vault path is empty")
    try:
        vault = Path(raw).expanduser().resolve(strict=True)
    except (OSError, RuntimeError) as exc:
        raise ZettelError("invalid_vault_path", f"cannot resolve vault path: {exc}") from exc
    if not vault.is_dir() or vault == Path(vault.anchor):
        raise ZettelError("invalid_vault_path", "vault path is not a usable directory")
    return vault


def _normalize_folder(folder: str) -> str:
    raw = str(folder or "").strip().strip("/")
    if not raw:
        raise ZettelError("invalid_folder", "Zettelkasten folder is empty")
    if "\\" in raw:
        raise ZettelError("invalid_folder", "folder must use vault-relative '/' separators")
    pure = PurePosixPath(raw)
    if pure.is_absolute() or any(part in ("", ".", "..") for part in pure.parts):
        raise ZettelError("invalid_folder", "folder contains an unsafe path component")
    return pure.as_posix()


def _resolve_folder(vault: Path, folder: str) -> tuple[str, Path]:
    normalized = _normalize_folder(folder)
    target = vault.joinpath(*PurePosixPath(normalized).parts)
    try:
        unresolved_parent = target.resolve(strict=False)
        if os.path.commonpath((str(vault), str(unresolved_parent))) != str(vault):
            raise ZettelError("folder_outside_vault", "Zettelkasten folder escapes the vault")
        target.mkdir(parents=True, exist_ok=True)
        resolved = target.resolve(strict=True)
        if os.path.commonpath((str(vault), str(resolved))) != str(vault):
            raise ZettelError("folder_outside_vault", "Zettelkasten folder escapes the vault")
    except ZettelError:
        raise
    except (OSError, RuntimeError, ValueError) as exc:
        raise ZettelError("folder_create_failed", f"cannot prepare Zettelkasten folder: {exc}") from exc
    if not resolved.is_dir():
        raise ZettelError("invalid_folder", "Zettelkasten target is not a directory")
    return normalized, resolved


def _clean_title(title: str, body: str) -> str:
    value = str(title or "").strip()
    if not value:
        for line in str(body or "").splitlines():
            candidate = line.strip().lstrip("#").strip()
            if candidate:
                value = candidate
                break
    if not value:
        value = "Quick note"
    value = re.sub(r"[\x00-\x1f\x7f]+", " ", value)
    value = re.sub(r"\s+", " ", value).strip()
    return value[:160]


def _filename_title(title: str) -> str:
    value = re.sub(r'[<>:"/\\|?*]+', " ", title)
    value = re.sub(r"\s+", " ", value).strip(" .")
    return (value or "Quick note")[:80]


def _render_markdown(note_id: str, title: str, body: str, note_type: str, created: datetime) -> str:
    clean_type = re.sub(r"[\r\n\x00]+", " ", str(note_type or "Fleeting")).strip() or "Fleeting"
    clean_body = str(body or "").replace("\x00", "").rstrip()
    created_iso = created.isoformat(timespec="seconds")
    yaml_title = json.dumps(title, ensure_ascii=False)
    yaml_type = json.dumps(clean_type, ensure_ascii=False)
    parts = [
        "---",
        f"id: {json.dumps(note_id)}",
        f"type: {yaml_type}",
        f"created: {json.dumps(created_iso)}",
        "aliases:",
        f"  - {yaml_title}",
        "tags:",
        "  - zettelkasten",
        "---",
        f"# {title}",
        "",
    ]
    if clean_body:
        parts.extend([clean_body, ""])
    return "\n".join(parts)


def capture(
    vault_path: str,
    folder: str,
    title: str,
    body: str,
    note_type: str = "Fleeting",
    now: datetime | None = None,
) -> dict[str, Any]:
    vault = _resolve_vault(vault_path)
    normalized_folder, target_dir = _resolve_folder(vault, folder)
    created = now or datetime.now().astimezone()
    note_id = created.strftime("%Y%m%d%H%M%S")
    clean_title = _clean_title(title, body)
    stem = f"{note_id} - {_filename_title(clean_title)}"
    markdown = _render_markdown(note_id, clean_title, body, note_type, created)
    payload = markdown.encode("utf-8")

    created_path: Path | None = None
    for attempt in range(1, 101):
        suffix = "" if attempt == 1 else f"-{attempt}"
        candidate = target_dir / f"{stem}{suffix}.md"
        try:
            fd = os.open(
                candidate,
                os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, "O_CLOEXEC", 0),
                0o600,
            )
        except FileExistsError:
            continue
        except OSError as exc:
            raise ZettelError("note_create_failed", f"cannot create Zettelkasten note: {exc}") from exc

        try:
            with os.fdopen(fd, "wb") as stream:
                stream.write(payload)
                stream.flush()
                os.fsync(stream.fileno())
            dir_fd = os.open(target_dir, os.O_RDONLY | getattr(os, "O_DIRECTORY", 0))
            try:
                os.fsync(dir_fd)
            finally:
                os.close(dir_fd)
        except OSError as exc:
            try:
                candidate.unlink(missing_ok=True)
            except OSError:
                pass
            raise ZettelError("note_write_failed", f"cannot persist Zettelkasten note: {exc}") from exc
        created_path = candidate
        break

    if created_path is None:
        raise ZettelError("note_collision", "could not allocate a unique Zettelkasten filename")

    relative = PurePosixPath(normalized_folder, created_path.name).as_posix()
    return {
        "ok": True,
        "id": note_id,
        "title": clean_title,
        "type": str(note_type or "Fleeting"),
        "notePath": relative,
        "noteFullPath": str(created_path),
    }


def _emit(payload: dict[str, Any]) -> None:
    json.dump(payload, sys.stdout, ensure_ascii=False, separators=(",", ":"))
    sys.stdout.write("\n")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--vault", required=True)
    parser.add_argument("--folder", default="00_Capture/03_Zettelkasten")
    parser.add_argument("--title", default="")
    parser.add_argument("--body", default="")
    parser.add_argument("--type", default="Fleeting")
    args = parser.parse_args(argv)
    try:
        _emit(capture(args.vault, args.folder, args.title, args.body, args.type))
        return 0
    except ZettelError as exc:
        _emit({"ok": False, "error": {"code": exc.code, "message": exc.message}})
        return 2
    except Exception as exc:
        _emit({"ok": False, "error": {"code": "internal_error", "message": str(exc)}})
        return 3


if __name__ == "__main__":
    raise SystemExit(main())
