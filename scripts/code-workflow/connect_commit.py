#!/usr/bin/env python3
"""Qualified Connect commit/verify/rollback engine.

The production transaction invokes this helper only after exact Connect
preparation and explicit authorization gates. It atomically replaces one
reviewed source file, verifies the retained external dependency before and after
replacement, and can restore the exact rollback snapshot.

The external dependency is evidence only and is never written. When an expected
manifest SHA-256 is supplied, manifest drift is rejected before any source
replacement.
"""

from __future__ import annotations

import argparse
from hashlib import sha256
import json
from pathlib import Path
from typing import Callable

from analyze import PROTOCOL, resolve_source
from commit import atomic_replace_if_hash
from connect_cycle import PROVEN_ACYCLIC_CROSS_FILE
from connect_prepare import ARTIFACT_PROOF
from connect_qualify import QUALIFICATION_PROOF
from connect_type import TYPE_PROOF

PostWriteHook = Callable[[], None]


def emit(payload: dict, exit_code: int) -> int:
    print(json.dumps({"protocol": PROTOCOL, **payload}, ensure_ascii=False))
    return exit_code


def digest(data: bytes) -> str:
    return sha256(data).hexdigest()


def _runtime_qml(root: Path, relative: str) -> Path:
    request = Path(str(relative))
    if request.is_absolute():
        raise ValueError("Connect manifest source path must be runtime-relative")
    candidate = (root / request).resolve()
    try:
        candidate.relative_to(root)
    except ValueError as exc:
        raise ValueError("Connect manifest source path escapes runtime root") from exc
    if candidate.suffix != ".qml" or not candidate.is_file():
        raise ValueError(
            "Connect manifest source path must name an existing .qml file")
    return candidate


def load_connect_manifest(
    manifest_path: Path,
    expected_manifest_sha256: str = "",
) -> tuple[dict, bytes, bytes, str]:
    path = manifest_path.expanduser().resolve()
    manifest_bytes = path.read_bytes()
    manifest_sha256 = digest(manifest_bytes)
    expected = str(expected_manifest_sha256 or "")
    if expected and manifest_sha256 != expected:
        raise ValueError("prepared Connect manifest hash mismatch")
    payload = json.loads(manifest_bytes.decode("utf-8"))

    if payload.get("version") != 1:
        raise ValueError("unsupported Connect manifest version")
    if payload.get("commandKind") != "connect-binding":
        raise ValueError("prepared manifest is not Connect")
    if payload.get("artifactProof") != ARTIFACT_PROOF:
        raise ValueError("Connect artifact proof token drifted")
    if payload.get("qualificationProof") != QUALIFICATION_PROOF:
        raise ValueError("Connect qualification proof token drifted")
    if payload.get("typeCompatibilityProof") != TYPE_PROOF:
        raise ValueError("Connect type proof token drifted")
    if payload.get("cycleSafetyProof") != PROVEN_ACYCLIC_CROSS_FILE:
        raise ValueError("Connect cycle proof token drifted")
    if payload.get("writeAuthorized") is not False:
        raise ValueError("Connect manifest unexpectedly authorizes writes")
    if payload.get("applyEnabled") is not False:
        raise ValueError("Connect manifest unexpectedly enables Apply")
    if payload.get("artifactsStaged") is not True:
        raise ValueError("Connect manifest artifacts are not staged")
    if payload.get("productionIntegrated") is not False:
        raise ValueError("Connect manifest production authorization drifted")

    required = (
        "sourcePath",
        "baseSha256",
        "candidateSha256",
        "parentSemanticAnchor",
        "insertedSemanticAnchor",
        "bindingName",
        "expression",
        "externalSourcePath",
        "externalSourceSha256",
        "snapshotPath",
        "candidatePath",
    )
    if any(not str(payload.get(key, "")) for key in required):
        raise ValueError("prepared Connect manifest is incomplete")

    snapshot_path = Path(payload["snapshotPath"]).expanduser().resolve()
    candidate_path = Path(payload["candidatePath"]).expanduser().resolve()
    if snapshot_path.parent != path.parent or candidate_path.parent != path.parent:
        raise ValueError("prepared Connect artifact escapes manifest directory")
    if snapshot_path.name != "snapshot.qml":
        raise ValueError("prepared Connect snapshot filename drifted")
    if candidate_path.name != "candidate.qml":
        raise ValueError("prepared Connect candidate filename drifted")

    snapshot = snapshot_path.read_bytes()
    candidate = candidate_path.read_bytes()
    snapshot.decode("utf-8")
    candidate.decode("utf-8")
    if digest(snapshot) != payload["baseSha256"]:
        raise ValueError("prepared Connect snapshot hash mismatch")
    if digest(candidate) != payload["candidateSha256"]:
        raise ValueError("prepared Connect candidate hash mismatch")

    return payload, snapshot, candidate, manifest_sha256


def _dependency_state(root: Path, manifest: dict) -> dict:
    external_path = _runtime_qml(root, manifest["externalSourcePath"])
    current_sha = digest(external_path.read_bytes())
    expected_sha = str(manifest["externalSourceSha256"])
    return {
        "externalSourcePath": manifest["externalSourcePath"],
        "externalSourceSha256": expected_sha,
        "currentExternalSourceSha256": current_sha,
        "dependencyState": (
            "fresh" if current_sha == expected_sha else "stale"
        ),
    }


def commit_connect_prepared(
    root: Path,
    manifest_path: Path,
    post_write_hook: PostWriteHook | None = None,
    expected_manifest_sha256: str = "",
) -> dict:
    root = root.expanduser().resolve()
    manifest, _snapshot, candidate, manifest_sha256 = load_connect_manifest(
        manifest_path,
        expected_manifest_sha256,
    )
    source_path = resolve_source(root, manifest["sourcePath"])

    dependency_before = _dependency_state(root, manifest)
    if dependency_before["dependencyState"] != "fresh":
        return {
            "status": "conflict",
            "reason": "external-source-sha-mismatch-before-write",
            "sourceWritten": False,
            **dependency_before,
        }

    result = atomic_replace_if_hash(
        source_path,
        candidate,
        manifest["baseSha256"],
        manifest["candidateSha256"],
    )
    if result.get("status") != "written":
        return {
            **result,
            "sourceWritten": False,
            **dependency_before,
        }

    if post_write_hook is not None:
        post_write_hook()

    dependency_after = _dependency_state(root, manifest)
    common = {
        "sourcePath": manifest["sourcePath"],
        "baseSha256": manifest["baseSha256"],
        "candidateSha256": manifest["candidateSha256"],
        "parentSemanticAnchor": manifest["parentSemanticAnchor"],
        "insertedSemanticAnchor": manifest["insertedSemanticAnchor"],
        "bindingName": manifest["bindingName"],
        "expression": manifest["expression"],
        "manifestPath": str(manifest_path.expanduser().resolve()),
        "manifestSha256": manifest_sha256,
    }
    if dependency_after["dependencyState"] != "fresh":
        return {
            **result,
            **common,
            **dependency_after,
            "status": "dependency-drift-after-write",
            "reason": "external-source-changed-after-source-write",
            "sourceWritten": True,
            "rollbackRequired": True,
        }

    return {
        **result,
        **common,
        **dependency_after,
        "status": "written",
        "sourceWritten": True,
        "rollbackRequired": False,
    }


def verify_connect_prepared(
    root: Path,
    manifest_path: Path,
    expected_manifest_sha256: str = "",
) -> dict:
    root = root.expanduser().resolve()
    manifest, _snapshot, _candidate, manifest_sha256 = load_connect_manifest(
        manifest_path,
        expected_manifest_sha256,
    )
    source_path = resolve_source(root, manifest["sourcePath"])
    current_sha = digest(source_path.read_bytes())
    if current_sha == manifest["candidateSha256"]:
        source_state = "candidate-present"
    elif current_sha == manifest["baseSha256"]:
        source_state = "base-present"
    else:
        source_state = "diverged"

    dependency = _dependency_state(root, manifest)
    return {
        "status": "verified",
        "sourceState": source_state,
        "sourcePath": manifest["sourcePath"],
        "currentSha256": current_sha,
        "baseSha256": manifest["baseSha256"],
        "candidateSha256": manifest["candidateSha256"],
        "parentSemanticAnchor": manifest["parentSemanticAnchor"],
        "insertedSemanticAnchor": manifest["insertedSemanticAnchor"],
        "manifestPath": str(manifest_path.expanduser().resolve()),
        "manifestSha256": manifest_sha256,
        **dependency,
    }


def rollback_connect_prepared(
    root: Path,
    manifest_path: Path,
    expected_manifest_sha256: str = "",
) -> dict:
    root = root.expanduser().resolve()
    manifest, snapshot, _candidate, manifest_sha256 = load_connect_manifest(
        manifest_path,
        expected_manifest_sha256,
    )
    source_path = resolve_source(root, manifest["sourcePath"])

    result = atomic_replace_if_hash(
        source_path,
        snapshot,
        manifest["candidateSha256"],
        manifest["baseSha256"],
    )
    dependency = _dependency_state(root, manifest)
    if result.get("status") == "written":
        return {
            **result,
            "status": "rolled-back",
            "sourcePath": manifest["sourcePath"],
            "baseSha256": manifest["baseSha256"],
            "candidateSha256": manifest["candidateSha256"],
            "parentSemanticAnchor": manifest["parentSemanticAnchor"],
            "insertedSemanticAnchor": manifest["insertedSemanticAnchor"],
            "manifestPath": str(manifest_path.expanduser().resolve()),
            "manifestSha256": manifest_sha256,
            **dependency,
        }
    return {
        **result,
        **dependency,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("operation", choices=("commit", "verify", "rollback"))
    parser.add_argument(
        "--root",
        default=str(Path(__file__).resolve().parents[2]),
    )
    parser.add_argument("--manifest", required=True)
    parser.add_argument("--manifest-sha256", default="")
    args = parser.parse_args()

    root = Path(args.root).expanduser().resolve()
    if not root.is_dir():
        return emit({
            "status": "invalid-request",
            "reason": "runtime-root-missing",
        }, 4)

    try:
        if args.operation == "commit":
            result = commit_connect_prepared(
                root,
                Path(args.manifest),
                expected_manifest_sha256=args.manifest_sha256,
            )
        elif args.operation == "rollback":
            result = rollback_connect_prepared(
                root,
                Path(args.manifest),
                expected_manifest_sha256=args.manifest_sha256,
            )
        else:
            result = verify_connect_prepared(
                root,
                Path(args.manifest),
                expected_manifest_sha256=args.manifest_sha256,
            )
    except (OSError, ValueError, UnicodeError, json.JSONDecodeError) as exc:
        return emit({
            "status": "invalid-request",
            "reason": str(exc),
        }, 4)

    status = str(result.get("status", "error"))
    if status in ("written", "rolled-back", "verified"):
        return emit(result, 0)
    if status in ("conflict", "dependency-drift-after-write"):
        return emit(result, 6)
    if status == "blocked":
        return emit(result, 7)
    return emit(result, 8)


if __name__ == "__main__":
    raise SystemExit(main())
