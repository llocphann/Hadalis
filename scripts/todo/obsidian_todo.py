#!/usr/bin/env python3
"""Safe Markdown scanner for the Hadalis Todo Obsidian backend.

Commit A intentionally implements read-only scan/path validation only.
Mutation and Obsidian CLI integration are added in later commits.
"""

from __future__ import annotations

import argparse
import codecs
import hashlib
import json
import os
import re
import sys
from pathlib import Path, PurePosixPath
from typing import Any

START_MARKER = "<!-- hadalis:todo:start -->"
END_MARKER = "<!-- hadalis:todo:end -->"

_TASK_RE = re.compile(
    r"^([\\s\\t>]*)([-*+]|[0-9]+[.)]) +\\[(.)\\] *(.*)$",
    re.UNICODE,
)
_FENCE_OPEN_RE = re.compile(r"^ {0,3}(`{3,}|~{3,})(.*)$")


class TodoError(Exception):
    def __init__(self, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code
        self.message = message


def _sha256_text(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def _strip_blockquote_prefix(line: str) -> str:
    rest = line
    while True:
        match = re.match(r"^ {0,3}> ?", rest)
        if match is None:
            return rest
        rest = rest[match.end() :]


def _outside_fence_flags(lines: list[str]) -> list[bool]:
    """Return True for lines that are not fenced-code content/fence lines.

    This intentionally implements only the fence semantics needed for safe
    recognition: backtick/tilde fences, including common blockquote prefixes.
    An unclosed fence keeps the remainder fenced, which is fail-closed for
    marker discovery.
    """

    flags: list[bool] = []
    fence_char = ""
    fence_len = 0

    for physical in lines:
        line = physical.rstrip("\r\n")
        candidate = _strip_blockquote_prefix(line)

        if fence_char:
            flags.append(False)
            close_re = re.compile(
                r"^ {0,3}" + re.escape(fence_char) + "{" + str(fence_len) + r",}[ \\t]*$"
            )
            if close_re.match(candidate):
                fence_char = ""
                fence_len = 0
            continue

        match = _FENCE_OPEN_RE.match(candidate)
        if match is not None:
            fence = match.group(1)
            # Backtick info strings cannot contain a backtick. If they do,
            # CommonMark does not treat the sequence as an opening fence.
            suffix = match.group(2)
            if fence[0] == "`" and "`" in suffix:
                flags.append(True)
                continue
            fence_char = fence[0]
            fence_len = len(fence)
            flags.append(False)
            continue

        flags.append(True)

    return flags


def _normalize_note_path(note_path: str) -> str:
    raw = str(note_path or "").strip()
    if not raw:
        raise TodoError("invalid_note_path", "note path is empty")
    if "\\" in raw:
        raise TodoError("invalid_note_path", "note path must use vault-relative '/' separators")

    pure = PurePosixPath(raw)
    if pure.is_absolute():
        raise TodoError("invalid_note_path", "note path must be relative to the vault")
    if any(part in ("", ".", "..") for part in pure.parts):
        raise TodoError("invalid_note_path", "note path contains an unsafe path component")
    return pure.as_posix()


def resolve_note(vault_path: str, note_path: str) -> tuple[Path, str, Path]:
    raw_vault = str(vault_path or "").strip()
    if not raw_vault:
        raise TodoError("invalid_vault_path", "vault path is empty")

    try:
        vault = Path(raw_vault).expanduser().resolve(strict=True)
    except (OSError, RuntimeError) as exc:
        raise TodoError("invalid_vault_path", f"cannot resolve vault path: {exc}") from exc

    if not vault.is_dir():
        raise TodoError("invalid_vault_path", "vault path is not a directory")
    if vault == Path(vault.anchor):
        raise TodoError("invalid_vault_path", "filesystem root cannot be used as a vault")

    normalized_note = _normalize_note_path(note_path)
    candidate = vault.joinpath(*PurePosixPath(normalized_note).parts)

    try:
        resolved_note = candidate.resolve(strict=True)
    except (OSError, RuntimeError) as exc:
        raise TodoError("note_not_found", f"cannot resolve note: {exc}") from exc

    try:
        if os.path.commonpath((str(vault), str(resolved_note))) != str(vault):
            raise TodoError("note_outside_vault", "resolved note escapes the configured vault")
    except ValueError as exc:
        raise TodoError("note_outside_vault", "resolved note is outside the configured vault") from exc

    if not resolved_note.is_file():
        raise TodoError("invalid_note_path", "configured note is not a regular file")

    return vault, normalized_note, resolved_note


def _newline_kind(raw: bytes) -> str:
    crlf = raw.count(b"\r\n")
    without_crlf = raw.replace(b"\r\n", b"")
    lf = without_crlf.count(b"\n")
    cr = without_crlf.count(b"\r")
    kinds = sum(1 for count in (crlf, lf, cr) if count)
    if kinds > 1:
        return "mixed"
    if crlf:
        return "crlf"
    if lf:
        return "lf"
    if cr:
        return "cr"
    return "none"


def _status_type(status_char: str) -> str:
    if status_char in ("x", "X"):
        return "DONE"
    if status_char == "/":
        return "IN_PROGRESS"
    if status_char == "-":
        return "CANCELLED"
    return "TODO"


def scan_note(
    vault_path: str,
    note_path: str,
    start_marker: str = START_MARKER,
    end_marker: str = END_MARKER,
) -> dict[str, Any]:
    vault, normalized_note, resolved_note = resolve_note(vault_path, note_path)

    try:
        raw = resolved_note.read_bytes()
    except OSError as exc:
        raise TodoError("note_read_failed", f"cannot read note: {exc}") from exc

    has_bom = raw.startswith(codecs.BOM_UTF8)
    payload = raw[len(codecs.BOM_UTF8) :] if has_bom else raw
    try:
        text = payload.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise TodoError("invalid_utf8", f"note is not valid UTF-8: {exc}") from exc

    lines = text.splitlines(keepends=True)
    outside = _outside_fence_flags(lines)

    start_indexes: list[int] = []
    end_indexes: list[int] = []
    for index, physical in enumerate(lines):
        if not outside[index]:
            continue
        line = physical.rstrip("\r\n")
        if line == start_marker:
            start_indexes.append(index)
        elif line == end_marker:
            end_indexes.append(index)

    if len(start_indexes) != 1 or len(end_indexes) != 1:
        raise TodoError(
            "invalid_managed_section",
            "expected exactly one start marker and one end marker outside fenced code",
        )

    start_index = start_indexes[0]
    end_index = end_indexes[0]
    if start_index >= end_index:
        raise TodoError("invalid_managed_section", "managed-section markers are out of order")

    tasks: list[dict[str, Any]] = []
    for index in range(start_index + 1, end_index):
        if not outside[index]:
            continue
        raw_line = lines[index].rstrip("\r\n")
        match = _TASK_RE.match(raw_line)
        if match is None:
            continue

        indent, list_marker, status_char, content = match.groups()
        raw_hash = _sha256_text(raw_line)
        source_line = index + 1
        task_id = _sha256_text(
            normalized_note + "\0" + str(source_line) + "\0" + raw_hash
        )[:24]
        status_type = _status_type(status_char)

        tasks.append(
            {
                "content": content,
                "done": status_type == "DONE",
                "id": task_id,
                "statusChar": status_char,
                "statusType": status_type,
                "sourcePath": normalized_note,
                "sourceLine": source_line,
                "rawLine": raw_line,
                "rawHash": raw_hash,
                "indent": indent,
                "listMarker": list_marker,
            }
        )

    managed_text = "".join(lines[start_index + 1 : end_index])
    return {
        "ok": True,
        "vaultPath": str(vault),
        "notePath": normalized_note,
        "noteFullPath": str(resolved_note),
        "document": {
            "bom": has_bom,
            "newline": _newline_kind(raw),
            "finalNewline": raw.endswith((b"\n", b"\r")),
            "sha256": hashlib.sha256(raw).hexdigest(),
        },
        "managed": {
            "startLine": start_index + 1,
            "endLine": end_index + 1,
            "sha256": _sha256_text(managed_text),
        },
        "tasks": tasks,
    }


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    scan = subparsers.add_parser("scan", help="scan a managed Todo section")
    scan.add_argument("--vault", required=True, help="physical Obsidian vault path")
    scan.add_argument("--note", required=True, help="Markdown path relative to vault")
    scan.add_argument("--start-marker", default=START_MARKER)
    scan.add_argument("--end-marker", default=END_MARKER)
    return parser


def _emit(payload: dict[str, Any]) -> None:
    json.dump(payload, sys.stdout, ensure_ascii=False, separators=(",", ":"))
    sys.stdout.write("\n")


def main(argv: list[str] | None = None) -> int:
    args = _build_parser().parse_args(argv)
    try:
        if args.command == "scan":
            _emit(scan_note(args.vault, args.note, args.start_marker, args.end_marker))
            return 0
        raise TodoError("unsupported_command", f"unsupported command: {args.command}")
    except TodoError as exc:
        _emit({"ok": False, "error": {"code": exc.code, "message": exc.message}})
        return 2
    except Exception as exc:  # Fail closed without exposing a Python traceback to QML.
        _emit({"ok": False, "error": {"code": "internal_error", "message": str(exc)}})
        return 3


if __name__ == "__main__":
    raise SystemExit(main())
