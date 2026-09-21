#!/usr/bin/env python3
"""Safe Markdown bridge for the Hadalis Todo Obsidian backend.

The filesystem mutation commands are deliberately structural and conservative.
Tasks-aware Obsidian CLI mutation is implemented separately.
"""

from __future__ import annotations

import argparse
import codecs
import hashlib
import json
import os
import re
import stat
import sys
import tempfile
from pathlib import Path, PurePosixPath
from typing import Any

START_MARKER = "<!-- hadalis:todo:start -->"
END_MARKER = "<!-- hadalis:todo:end -->"

_TASK_RE = re.compile(
    r"^([\s\t>]*)([-*+]|[0-9]+[.)]) +\[(.)\] *(.*)$",
    re.UNICODE,
)
_FENCE_OPEN_RE = re.compile(r"^ {0,3}(`{3,}|~{3,})(.*)$")

# Metadata whose completion behavior belongs to Obsidian Tasks, not Hadalis.
_RICH_TASK_TOKENS = (
    "🔁", "📅", "⏳", "🛫", "➕", "✅", "❌", "🏁",
    "🔺", "⏫", "🔼", "🔽", "⏬", "🆔", "⛔",
)
_RICH_DATAVIEW_RE = re.compile(
    r"\[(?:due|scheduled|start|created|completion|cancelled|repeat|priority|onCompletion)::",
    re.IGNORECASE,
)


class TodoError(Exception):
    def __init__(self, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code
        self.message = message


def _sha256_text(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def _sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def _strip_blockquote_prefix(line: str) -> str:
    rest = line
    while True:
        match = re.match(r"^ {0,3}> ?", rest)
        if match is None:
            return rest
        rest = rest[match.end() :]


def _outside_fence_flags(lines: list[str]) -> list[bool]:
    flags: list[bool] = []
    fence_char = ""
    fence_len = 0

    for physical in lines:
        line = physical.rstrip("\r\n")
        candidate = _strip_blockquote_prefix(line)

        if fence_char:
            flags.append(False)
            close_re = re.compile(
                r"^ {0,3}" + re.escape(fence_char) + "{" + str(fence_len) + r",}[ \t]*$"
            )
            if close_re.match(candidate):
                fence_char = ""
                fence_len = 0
            continue

        match = _FENCE_OPEN_RE.match(candidate)
        if match is not None:
            fence = match.group(1)
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


def _load_document(
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

    return {
        "vault": vault,
        "notePath": normalized_note,
        "resolved": resolved_note,
        "raw": raw,
        "bom": has_bom,
        "text": text,
        "lines": lines,
        "outside": outside,
        "startIndex": start_index,
        "endIndex": end_index,
    }


def _task_from_line(doc: dict[str, Any], index: int) -> dict[str, Any] | None:
    if not doc["outside"][index]:
        return None
    raw_line = doc["lines"][index].rstrip("\r\n")
    match = _TASK_RE.match(raw_line)
    if match is None:
        return None

    indent, list_marker, status_char, content = match.groups()
    raw_hash = _sha256_text(raw_line)
    source_line = index + 1
    task_id = _sha256_text(
        doc["notePath"] + "\0" + str(source_line) + "\0" + raw_hash
    )[:24]
    status_type = _status_type(status_char)
    return {
        "content": content,
        "done": status_type == "DONE",
        "id": task_id,
        "statusChar": status_char,
        "statusType": status_type,
        "sourcePath": doc["notePath"],
        "sourceLine": source_line,
        "rawLine": raw_line,
        "rawHash": raw_hash,
        "indent": indent,
        "listMarker": list_marker,
        "_index": index,
        "_match": match,
    }


def _tasks(doc: dict[str, Any]) -> list[dict[str, Any]]:
    result: list[dict[str, Any]] = []
    for index in range(doc["startIndex"] + 1, doc["endIndex"]):
        task = _task_from_line(doc, index)
        if task is not None:
            result.append(task)
    return result


def _public_task(task: dict[str, Any]) -> dict[str, Any]:
    return {key: value for key, value in task.items() if not key.startswith("_")}


def _managed_text(doc: dict[str, Any]) -> str:
    return "".join(doc["lines"][doc["startIndex"] + 1 : doc["endIndex"]])


def _scan_payload(doc: dict[str, Any]) -> dict[str, Any]:
    return {
        "ok": True,
        "vaultPath": str(doc["vault"]),
        "notePath": doc["notePath"],
        "noteFullPath": str(doc["resolved"]),
        "document": {
            "bom": doc["bom"],
            "newline": _newline_kind(doc["raw"]),
            "finalNewline": doc["raw"].endswith((b"\n", b"\r")),
            "sha256": _sha256_bytes(doc["raw"]),
        },
        "managed": {
            "startLine": doc["startIndex"] + 1,
            "endLine": doc["endIndex"] + 1,
            "sha256": _sha256_text(_managed_text(doc)),
        },
        "tasks": [_public_task(task) for task in _tasks(doc)],
    }


def scan_note(
    vault_path: str,
    note_path: str,
    start_marker: str = START_MARKER,
    end_marker: str = END_MARKER,
) -> dict[str, Any]:
    return _scan_payload(_load_document(vault_path, note_path, start_marker, end_marker))


def _require_hashes(
    doc: dict[str, Any],
    expected_document_sha: str,
    expected_managed_sha: str | None = None,
) -> None:
    if not expected_document_sha:
        raise TodoError("missing_precondition", "expected document hash is required")
    if _sha256_bytes(doc["raw"]) != expected_document_sha:
        raise TodoError("conflict", "document changed since the last scan")
    if expected_managed_sha is not None and _sha256_text(_managed_text(doc)) != expected_managed_sha:
        raise TodoError("conflict", "managed Todo section changed since the last scan")


def _find_task(doc: dict[str, Any], task_id: str) -> dict[str, Any]:
    matches = [task for task in _tasks(doc) if task["id"] == task_id]
    if len(matches) != 1:
        raise TodoError("conflict", "task reference is stale or ambiguous")
    return matches[0]


def _line_ending(physical: str) -> str:
    if physical.endswith("\r\n"):
        return "\r\n"
    if physical.endswith("\n"):
        return "\n"
    if physical.endswith("\r"):
        return "\r"
    return ""


def _preferred_newline(doc: dict[str, Any]) -> str:
    end_suffix = _line_ending(doc["lines"][doc["endIndex"]])
    if end_suffix:
        return end_suffix
    kind = _newline_kind(doc["raw"])
    if kind == "crlf":
        return "\r\n"
    if kind == "cr":
        return "\r"
    return "\n"


def _is_obviously_rich(task: dict[str, Any]) -> bool:
    raw = task["rawLine"]
    return any(token in raw for token in _RICH_TASK_TOKENS) or _RICH_DATAVIEW_RE.search(raw) is not None


def _encode_document(doc: dict[str, Any], lines: list[str]) -> bytes:
    payload = "".join(lines).encode("utf-8")
    return (codecs.BOM_UTF8 + payload) if doc["bom"] else payload


def _atomic_replace_if_unchanged(doc: dict[str, Any], new_raw: bytes) -> None:
    path: Path = doc["resolved"]
    try:
        current = path.read_bytes()
    except OSError as exc:
        raise TodoError("note_read_failed", f"cannot revalidate note before write: {exc}") from exc
    if current != doc["raw"]:
        raise TodoError("conflict", "document changed while preparing the mutation")

    try:
        original_mode = stat.S_IMODE(path.stat().st_mode)
    except OSError as exc:
        raise TodoError("note_write_failed", f"cannot stat note before write: {exc}") from exc

    fd = -1
    temp_name = ""
    try:
        fd, temp_name = tempfile.mkstemp(prefix=f".{path.name}.hadalis.", dir=str(path.parent))
        os.fchmod(fd, original_mode)
        with os.fdopen(fd, "wb") as stream:
            fd = -1
            stream.write(new_raw)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temp_name, path)
        temp_name = ""

        dir_fd = os.open(path.parent, os.O_RDONLY | getattr(os, "O_DIRECTORY", 0))
        try:
            os.fsync(dir_fd)
        finally:
            os.close(dir_fd)
    except TodoError:
        raise
    except OSError as exc:
        raise TodoError("note_write_failed", f"atomic note write failed: {exc}") from exc
    finally:
        if fd >= 0:
            os.close(fd)
        if temp_name:
            try:
                os.unlink(temp_name)
            except OSError:
                pass


def _mutation_result(vault_path: str, note_path: str, action: str) -> dict[str, Any]:
    payload = scan_note(vault_path, note_path)
    payload["mutation"] = action
    return payload


def add_basic_task(
    vault_path: str,
    note_path: str,
    text: str,
    expected_document_sha: str,
    expected_managed_sha: str,
) -> dict[str, Any]:
    clean = str(text or "").strip()
    if not clean:
        raise TodoError("invalid_task_text", "task text is empty")
    if "\n" in clean or "\r" in clean or "\0" in clean:
        raise TodoError("invalid_task_text", "task text must be a single line")

    doc = _load_document(vault_path, note_path)
    _require_hashes(doc, expected_document_sha, expected_managed_sha)
    lines = list(doc["lines"])
    lines.insert(doc["endIndex"], "- [ ] " + clean + _preferred_newline(doc))
    _atomic_replace_if_unchanged(doc, _encode_document(doc, lines))
    return _mutation_result(vault_path, note_path, "add")


def toggle_basic_task(
    vault_path: str,
    note_path: str,
    task_id: str,
    expected_document_sha: str,
) -> dict[str, Any]:
    doc = _load_document(vault_path, note_path)
    _require_hashes(doc, expected_document_sha)
    task = _find_task(doc, task_id)

    if task["statusChar"] not in (" ", "x", "X"):
        raise TodoError("rich_task_required", "custom/non-binary task status requires Tasks-aware mutation")
    if _is_obviously_rich(task):
        raise TodoError("rich_task_required", "task metadata requires Tasks-aware mutation")

    index = task["_index"]
    physical = doc["lines"][index]
    raw_line = task["rawLine"]
    ending = physical[len(raw_line) :]
    match = task["_match"]
    next_status = " " if task["statusChar"] in ("x", "X") else "x"
    start, end = match.span(3)
    replacement = raw_line[:start] + next_status + raw_line[end:] + ending

    lines = list(doc["lines"])
    lines[index] = replacement
    _atomic_replace_if_unchanged(doc, _encode_document(doc, lines))
    return _mutation_result(vault_path, note_path, "toggle-basic")


def delete_task(
    vault_path: str,
    note_path: str,
    task_id: str,
    expected_document_sha: str,
) -> dict[str, Any]:
    doc = _load_document(vault_path, note_path)
    _require_hashes(doc, expected_document_sha)
    task = _find_task(doc, task_id)
    lines = list(doc["lines"])
    del lines[task["_index"]]
    _atomic_replace_if_unchanged(doc, _encode_document(doc, lines))
    return _mutation_result(vault_path, note_path, "delete")


def _add_source_args(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--vault", required=True, help="physical Obsidian vault path")
    parser.add_argument("--note", required=True, help="Markdown path relative to vault")


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    scan = subparsers.add_parser("scan", help="scan a managed Todo section")
    _add_source_args(scan)
    scan.add_argument("--start-marker", default=START_MARKER)
    scan.add_argument("--end-marker", default=END_MARKER)

    add = subparsers.add_parser("add-basic", help="append a plain task to the managed section")
    _add_source_args(add)
    add.add_argument("--text", required=True)
    add.add_argument("--expected-document-sha", required=True)
    add.add_argument("--expected-managed-sha", required=True)

    toggle = subparsers.add_parser("toggle-basic", help="toggle a proven plain space/x task")
    _add_source_args(toggle)
    toggle.add_argument("--id", required=True)
    toggle.add_argument("--expected-document-sha", required=True)

    delete = subparsers.add_parser("delete", help="delete exactly one referenced task line")
    _add_source_args(delete)
    delete.add_argument("--id", required=True)
    delete.add_argument("--expected-document-sha", required=True)

    return parser


def _emit(payload: dict[str, Any]) -> None:
    json.dump(payload, sys.stdout, ensure_ascii=False, separators=(",", ":"))
    sys.stdout.write("\n")


def main(argv: list[str] | None = None) -> int:
    args = _build_parser().parse_args(argv)
    try:
        if args.command == "scan":
            payload = scan_note(args.vault, args.note, args.start_marker, args.end_marker)
        elif args.command == "add-basic":
            payload = add_basic_task(
                args.vault, args.note, args.text,
                args.expected_document_sha, args.expected_managed_sha,
            )
        elif args.command == "toggle-basic":
            payload = toggle_basic_task(
                args.vault, args.note, args.id, args.expected_document_sha,
            )
        elif args.command == "delete":
            payload = delete_task(
                args.vault, args.note, args.id, args.expected_document_sha,
            )
        else:
            raise TodoError("unsupported_command", f"unsupported command: {args.command}")
        _emit(payload)
        return 0
    except TodoError as exc:
        _emit({"ok": False, "error": {"code": exc.code, "message": exc.message}})
        return 2
    except Exception as exc:
        _emit({"ok": False, "error": {"code": "internal_error", "message": str(exc)}})
        return 3


if __name__ == "__main__":
    raise SystemExit(main())
