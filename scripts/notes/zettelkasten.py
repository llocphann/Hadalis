#!/usr/bin/env python3
"""Create filesystem-canonical Zettelkasten notes for Hadalis quick capture.

The format mirrors the user's Obsidian Zettelkasten template but does not invoke
Templater or Obsidian. Filesystem Markdown is canonical.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
from datetime import datetime, timedelta
from pathlib import Path, PurePosixPath
from typing import Any

ALLOWED_TYPES = ("Permanent", "Literature", "Fleeting")
DEFAULT_FOLDER = "00_Capture/03_Zettelkasten"
DEFAULT_TYPE = "Fleeting"


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
        unresolved = target.resolve(strict=False)
        if os.path.commonpath((str(vault), str(unresolved))) != str(vault):
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


def _normalize_type(note_type: str) -> str:
    value = str(note_type or DEFAULT_TYPE).strip() or DEFAULT_TYPE
    if value not in ALLOWED_TYPES:
        raise ZettelError(
            "invalid_note_type",
            "Zettelkasten type must be Permanent, Literature or Fleeting",
        )
    return value


def _clean_body(body: str) -> str:
    return str(body or "").replace("\x00", "").replace("\r\n", "\n").replace("\r", "\n").strip()


def _render_markdown(
    note_id: str,
    title: str,
    body: str,
    note_type: str,
    created: datetime,
) -> str:
    """Render the static structure of 90_System/91_Templates/Zettelkasten_Template.md."""

    clean_body = _clean_body(body)
    core_idea = title
    content = clean_body if clean_body else title

    parts = [
        "---",
        f"id: {note_id}",
        f"date: {created.strftime('%Y-%m-%d')}",
        f"type: {note_type}",
        "tags:",
        "  - zettelkasten",
        "aliases: []",
        "---",
        "",
        f"# {title}",
        "",
        "## Core Idea",
        core_idea,
        "",
        "## Content",
        content,
        "",
        "## Context & Connections",
        "*Link to existing notes using [[]] with explicit context on how they relate:*",
        "- **Parent / Overview:** [[ ]]",
        "- **Supporting / Extension:** [[ ]]",
        "- **Contradiction / Alternative:** [[ ]]",
        "",
        "## Sources & References",
        "- **Author / Source:** ",
        "- **Link / Reference:**",
        "",
    ]
    return "\n".join(parts)


def _id_in_use(target_dir: Path, note_id: str) -> bool:
    try:
        return next(target_dir.glob(f"{note_id} - *.md"), None) is not None
    except OSError as exc:
        raise ZettelError("folder_read_failed", f"cannot inspect Zettelkasten folder: {exc}") from exc


def capture(
    vault_path: str,
    folder: str,
    title: str,
    body: str,
    note_type: str = DEFAULT_TYPE,
    now: datetime | None = None,
) -> dict[str, Any]:
    vault = _resolve_vault(vault_path)
    normalized_folder, target_dir = _resolve_folder(vault, folder)
    requested_time = now or datetime.now().astimezone()
    clean_title = _clean_title(title, body)
    clean_type = _normalize_type(note_type)
    filename_title = _filename_title(clean_title)

    created_path: Path | None = None
    allocated_time: datetime | None = None
    allocated_id = ""

    # Zettelkasten IDs are second-resolution timestamps. Never reuse an ID just
    # because a different title would make the filename distinct; advance to
    # the next free second instead.
    for attempt in range(0, 100):
        candidate_time = requested_time + timedelta(seconds=attempt)
        note_id = candidate_time.strftime("%Y%m%d%H%M%S")
        if _id_in_use(target_dir, note_id):
            continue

        candidate = target_dir / f"{note_id} - {filename_title}.md"
        markdown = _render_markdown(
            note_id, clean_title, body, clean_type, candidate_time
        )
        payload = markdown.encode("utf-8")
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
        allocated_time = candidate_time
        allocated_id = note_id
        break

    if created_path is None or allocated_time is None:
        raise ZettelError("note_collision", "could not allocate a unique Zettelkasten ID")

    relative = PurePosixPath(normalized_folder, created_path.name).as_posix()
    return {
        "ok": True,
        "id": allocated_id,
        "date": allocated_time.strftime("%Y-%m-%d"),
        "title": clean_title,
        "type": clean_type,
        "notePath": relative,
        "noteFullPath": str(created_path),
        "templateCompatible": True,
    }


def _emit(payload: dict[str, Any]) -> None:
    json.dump(payload, sys.stdout, ensure_ascii=False, separators=(",", ":"))
    sys.stdout.write("\n")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--vault", required=True)
    parser.add_argument("--folder", default=DEFAULT_FOLDER)
    parser.add_argument("--title", default="")
    parser.add_argument("--body", default="")
    parser.add_argument("--type", default=DEFAULT_TYPE)
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
