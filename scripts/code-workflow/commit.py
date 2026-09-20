#!/usr/bin/env python3
"""Atomic commit/verify/rollback engine for prepared Code Workflow artifacts.

The production transaction service invokes this helper only after exact artifact
preparation. User-triggered Apply remains separately gated in Settings.
"""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import stat
import tempfile

from analyze import PROTOCOL, resolve_source
from transaction import digest


def emit(payload: dict, exit_code: int) -> int:
    print(json.dumps({"protocol": PROTOCOL, **payload}, ensure_ascii=False))
    return exit_code


def load_prepared_manifest(manifest_path: Path) -> tuple[dict, bytes, bytes]:
    path = manifest_path.expanduser().resolve()
    payload = json.loads(path.read_text(encoding="utf-8"))
    if payload.get("version") != 1:
        raise ValueError("unsupported prepared manifest version")

    required = (
        "sourcePath",
        "baseSha256",
        "candidateSha256",
        "semanticAnchor",
        "snapshotPath",
        "candidatePath",
    )
    if any(not str(payload.get(key, "")) for key in required):
        raise ValueError("prepared manifest is incomplete")

    snapshot_path = Path(payload["snapshotPath"]).expanduser().resolve()
    candidate_path = Path(payload["candidatePath"]).expanduser().resolve()
    if snapshot_path.parent != path.parent or candidate_path.parent != path.parent:
        raise ValueError("prepared artifact escapes manifest directory")
    if snapshot_path.name != "snapshot.qml":
        raise ValueError("prepared snapshot filename drifted")
    if candidate_path.name != "candidate.qml":
        raise ValueError("prepared candidate filename drifted")

    snapshot = snapshot_path.read_bytes()
    candidate = candidate_path.read_bytes()
    if digest(snapshot) != payload["baseSha256"]:
        raise ValueError("prepared snapshot hash mismatch")
    if digest(candidate) != payload["candidateSha256"]:
        raise ValueError("prepared candidate hash mismatch")
    snapshot.decode("utf-8")
    candidate.decode("utf-8")
    return payload, snapshot, candidate


def nudge_parent_directory(parent: Path) -> None:
    """Emit a post-replace directory event for Quickshell's config watcher.

    Quickshell 0.3.1 watches both each QML file and its parent directory. An
    atomic rename can invalidate the file watch; its recovery path records the
    deleted watched file on fileChanged(), then resolves it on a later
    directoryChanged(). Linux inotify may deliver the rename's directory event
    first, so create+unlink a hidden sibling after os.replace() to guarantee a
    later directory event without issuing a manual shell reload.
    """
    fd, temporary = tempfile.mkstemp(
        prefix=".hadalis-code-workflow-watch-",
        dir=str(parent),
    )
    trigger = Path(temporary)
    try:
        os.close(fd)
        trigger.unlink()
    finally:
        if trigger.exists():
            trigger.unlink()

    try:
        directory_fd = os.open(
            parent,
            os.O_RDONLY | getattr(os, "O_DIRECTORY", 0),
        )
    except OSError:
        directory_fd = -1
    if directory_fd >= 0:
        try:
            os.fsync(directory_fd)
        finally:
            os.close(directory_fd)


def atomic_replace_if_hash(
    source_path: Path,
    replacement: bytes,
    expected_current_sha256: str,
    expected_result_sha256: str,
) -> dict:
    current = source_path.read_bytes()
    if digest(current) != expected_current_sha256:
        return {
            "status": "conflict",
            "reason": "source-sha-mismatch",
            "expectedSha256": expected_current_sha256,
            "currentSha256": digest(current),
        }

    source_stat = source_path.stat()
    mode = stat.S_IMODE(source_stat.st_mode)
    fd, temporary = tempfile.mkstemp(
        prefix=".hadalis-code-workflow-",
        dir=str(source_path.parent),
    )
    temp_path = Path(temporary)
    try:
        with os.fdopen(fd, "wb") as handle:
            handle.write(replacement)
            handle.flush()
            os.fsync(handle.fileno())
        os.chmod(temp_path, mode)

        # Final compare immediately before replacement. This is the last point
        # at which an external source edit can be detected without cooperation
        # from the other writer.
        final_current = source_path.read_bytes()
        final_sha = digest(final_current)
        if final_sha != expected_current_sha256:
            return {
                "status": "conflict",
                "reason": "source-changed-before-replace",
                "expectedSha256": expected_current_sha256,
                "currentSha256": final_sha,
            }

        os.replace(temp_path, source_path)

        try:
            directory_fd = os.open(
                source_path.parent,
                os.O_RDONLY | getattr(os, "O_DIRECTORY", 0),
            )
        except OSError:
            directory_fd = -1
        if directory_fd >= 0:
            try:
                os.fsync(directory_fd)
            finally:
                os.close(directory_fd)

        result_sha = digest(source_path.read_bytes())
        if result_sha != expected_result_sha256:
            return {
                "status": "error",
                "reason": "post-replace-sha-mismatch",
                "expectedSha256": expected_result_sha256,
                "currentSha256": result_sha,
            }

        # Keep reload watcher-driven. This closes the QFileSystemWatcher
        # rename-order race observed by the isolated Gate 2H runtime.
        nudge_parent_directory(source_path.parent)

        return {
            "status": "written",
            "sourceSha256": result_sha,
            "mode": mode,
            "watcherNudge": True,
        }
    finally:
        if temp_path.exists():
            temp_path.unlink()


def commit_prepared(root: Path, manifest_path: Path) -> dict:
    manifest, _snapshot, candidate = load_prepared_manifest(manifest_path)
    source_path = resolve_source(root.resolve(), manifest["sourcePath"])
    if not os.access(source_path, os.W_OK):
        return {"status": "blocked", "reason": "source-read-only"}

    result = atomic_replace_if_hash(
        source_path,
        candidate,
        manifest["baseSha256"],
        manifest["candidateSha256"],
    )
    if result.get("status") == "written":
        result = {
            **result,
            "status": "written",
            "sourcePath": manifest["sourcePath"],
            "baseSha256": manifest["baseSha256"],
            "candidateSha256": manifest["candidateSha256"],
            "semanticAnchor": manifest["semanticAnchor"],
            "manifestPath": str(manifest_path.expanduser().resolve()),
        }
    return result


def rollback_prepared(root: Path, manifest_path: Path) -> dict:
    manifest, snapshot, _candidate = load_prepared_manifest(manifest_path)
    source_path = resolve_source(root.resolve(), manifest["sourcePath"])
    if not os.access(source_path, os.W_OK):
        return {"status": "blocked", "reason": "source-read-only"}

    result = atomic_replace_if_hash(
        source_path,
        snapshot,
        manifest["candidateSha256"],
        manifest["baseSha256"],
    )
    if result.get("status") == "written":
        result = {
            **result,
            "status": "rolled-back",
            "sourcePath": manifest["sourcePath"],
            "baseSha256": manifest["baseSha256"],
            "candidateSha256": manifest["candidateSha256"],
            "semanticAnchor": manifest["semanticAnchor"],
            "manifestPath": str(manifest_path.expanduser().resolve()),
        }
    return result


def verify_prepared(root: Path, manifest_path: Path) -> dict:
    manifest, _snapshot, _candidate = load_prepared_manifest(manifest_path)
    source_path = resolve_source(root.resolve(), manifest["sourcePath"])
    current_sha = digest(source_path.read_bytes())
    if current_sha == manifest["candidateSha256"]:
        state = "candidate-present"
    elif current_sha == manifest["baseSha256"]:
        state = "base-present"
    else:
        state = "diverged"
    return {
        "status": "verified",
        "state": state,
        "sourcePath": manifest["sourcePath"],
        "currentSha256": current_sha,
        "baseSha256": manifest["baseSha256"],
        "candidateSha256": manifest["candidateSha256"],
        "semanticAnchor": manifest["semanticAnchor"],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("operation", choices=("commit", "verify", "rollback"))
    parser.add_argument(
        "--root",
        default=str(Path(__file__).resolve().parents[2]),
    )
    parser.add_argument("--manifest", required=True)
    args = parser.parse_args()

    root = Path(args.root).expanduser().resolve()
    if not root.is_dir():
        return emit({
            "status": "invalid-request",
            "reason": "runtime-root-missing",
        }, 4)

    manifest_path = Path(args.manifest)
    try:
        if args.operation == "commit":
            result = commit_prepared(root, manifest_path)
        elif args.operation == "rollback":
            result = rollback_prepared(root, manifest_path)
        else:
            result = verify_prepared(root, manifest_path)
    except (OSError, ValueError, UnicodeError, json.JSONDecodeError) as exc:
        return emit({
            "status": "invalid-request",
            "reason": str(exc),
        }, 4)

    status = str(result.get("status", "error"))
    if status in ("written", "rolled-back", "verified"):
        return emit(result, 0)
    if status == "conflict":
        return emit(result, 6)
    if status == "blocked":
        return emit(result, 7)
    return emit(result, 8)


if __name__ == "__main__":
    raise SystemExit(main())
