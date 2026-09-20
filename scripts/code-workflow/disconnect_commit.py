#!/usr/bin/env python3
"""Atomic engine for exact prepared Disconnect artifacts.

This 2K-T-A engine reuses the qualified atomic replacement primitive from
commit.py but validates a Disconnect-specific manifest. It never writes any
dependency or second source. The manifest remains non-authorizing; production
UI/lifecycle integration is a later 2K-T stage.
"""

from __future__ import annotations

import argparse
from hashlib import sha256
import json
import os
from pathlib import Path

from analyze import PROTOCOL, resolve_source
from commit import atomic_replace_if_hash
from disconnect_prepare import ARTIFACT_PROOF, POSTCONDITION
from transaction import digest


def emit(payload: dict, exit_code: int) -> int:
    print(json.dumps({"protocol": PROTOCOL, **payload}, ensure_ascii=False))
    return exit_code


def load_disconnect_manifest(
    manifest_path: Path,
    expected_manifest_sha256: str = "",
) -> tuple[dict, bytes, bytes, str]:
    path = manifest_path.expanduser().resolve()
    manifest_bytes = path.read_bytes()
    manifest_sha = sha256(manifest_bytes).hexdigest()
    expected = str(expected_manifest_sha256 or "")
    if expected and manifest_sha != expected:
        raise ValueError("prepared Disconnect manifest hash mismatch")

    payload = json.loads(manifest_bytes.decode("utf-8"))
    if payload.get("version") != 1:
        raise ValueError("unsupported Disconnect manifest version")
    if payload.get("commandKind") != "disconnect-binding":
        raise ValueError("prepared manifest is not Disconnect")
    if payload.get("artifactProof") != ARTIFACT_PROOF:
        raise ValueError("Disconnect artifact proof token drifted")
    if payload.get("reviewedEdgeId") != "clock.data.time":
        raise ValueError("Disconnect target is outside reviewed 2K-T subset")
    if payload.get("graphTargetId") != "bar/clock":
        raise ValueError("Disconnect graph target drifted")
    if payload.get("sourcePath") != "modules/bar/ClockWidget.qml":
        raise ValueError("Disconnect source path drifted")
    if payload.get("propertyName") != "text":
        raise ValueError("Disconnect property identity drifted")
    if payload.get("expectedCurrent") != "DateTime.timeDisplay":
        raise ValueError("Disconnect source expression drifted")
    if payload.get("resultingState") != "unbound/default":
        raise ValueError("Disconnect resulting state drifted")
    if payload.get("postcondition") != POSTCONDITION:
        raise ValueError("Disconnect postcondition drifted")
    if payload.get("writeAuthorized") is not False:
        raise ValueError("Disconnect manifest unexpectedly authorizes writes")
    if payload.get("applyEnabled") is not False:
        raise ValueError("Disconnect manifest unexpectedly enables Apply")
    if payload.get("artifactsStaged") is not True:
        raise ValueError("Disconnect artifacts are not staged")
    if payload.get("productionIntegrated") is not False:
        raise ValueError("Disconnect production integration drifted")

    required = (
        "transactionId",
        "baseSha256",
        "candidateSha256",
        "semanticAnchor",
        "snapshotPath",
        "candidatePath",
    )
    if any(not str(payload.get(key, "")) for key in required):
        raise ValueError("prepared Disconnect manifest is incomplete")

    snapshot_path = Path(payload["snapshotPath"]).expanduser().resolve()
    candidate_path = Path(payload["candidatePath"]).expanduser().resolve()
    if snapshot_path.parent != path.parent or candidate_path.parent != path.parent:
        raise ValueError("prepared Disconnect artifact escapes manifest directory")
    if snapshot_path.name != "snapshot.qml":
        raise ValueError("prepared Disconnect snapshot filename drifted")
    if candidate_path.name != "candidate.qml":
        raise ValueError("prepared Disconnect candidate filename drifted")

    snapshot = snapshot_path.read_bytes()
    candidate = candidate_path.read_bytes()
    snapshot.decode("utf-8")
    candidate.decode("utf-8")
    if digest(snapshot) != payload["baseSha256"]:
        raise ValueError("prepared Disconnect snapshot hash mismatch")
    if digest(candidate) != payload["candidateSha256"]:
        raise ValueError("prepared Disconnect candidate hash mismatch")

    return payload, snapshot, candidate, manifest_sha


def _common(manifest: dict, manifest_path: Path, manifest_sha: str) -> dict:
    return {
        "commandKind": "disconnect-binding",
        "artifactProof": ARTIFACT_PROOF,
        "graphTargetId": manifest["graphTargetId"],
        "reviewedEdgeId": manifest["reviewedEdgeId"],
        "sourcePath": manifest["sourcePath"],
        "baseSha256": manifest["baseSha256"],
        "candidateSha256": manifest["candidateSha256"],
        "semanticAnchor": manifest["semanticAnchor"],
        "propertyName": manifest["propertyName"],
        "expectedCurrent": manifest["expectedCurrent"],
        "resultingState": manifest["resultingState"],
        "postcondition": manifest["postcondition"],
        "manifestPath": str(manifest_path.expanduser().resolve()),
        "manifestSha256": manifest_sha,
    }


def commit_disconnect(
    root: Path,
    manifest_path: Path,
    expected_manifest_sha256: str = "",
) -> dict:
    root = root.expanduser().resolve()
    manifest, _snapshot, candidate, manifest_sha = load_disconnect_manifest(
        manifest_path, expected_manifest_sha256)
    source_path = resolve_source(root, manifest["sourcePath"])
    if not os.access(source_path, os.W_OK):
        return {"status": "blocked", "reason": "source-read-only"}

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
            **_common(manifest, manifest_path, manifest_sha),
        }
    return {
        **result,
        **_common(manifest, manifest_path, manifest_sha),
        "status": "written",
        "sourceWritten": True,
        "rollbackRequired": False,
    }


def verify_disconnect(
    root: Path,
    manifest_path: Path,
    expected_manifest_sha256: str = "",
) -> dict:
    root = root.expanduser().resolve()
    manifest, _snapshot, _candidate, manifest_sha = load_disconnect_manifest(
        manifest_path, expected_manifest_sha256)
    source_path = resolve_source(root, manifest["sourcePath"])
    current_sha = digest(source_path.read_bytes())
    if current_sha == manifest["candidateSha256"]:
        source_state = "candidate-present"
    elif current_sha == manifest["baseSha256"]:
        source_state = "base-present"
    else:
        source_state = "diverged"
    return {
        "status": "verified",
        "sourceState": source_state,
        "currentSha256": current_sha,
        **_common(manifest, manifest_path, manifest_sha),
    }


def rollback_disconnect(
    root: Path,
    manifest_path: Path,
    expected_manifest_sha256: str = "",
) -> dict:
    root = root.expanduser().resolve()
    manifest, snapshot, _candidate, manifest_sha = load_disconnect_manifest(
        manifest_path, expected_manifest_sha256)
    source_path = resolve_source(root, manifest["sourcePath"])
    if not os.access(source_path, os.W_OK):
        return {"status": "blocked", "reason": "source-read-only"}

    result = atomic_replace_if_hash(
        source_path,
        snapshot,
        manifest["candidateSha256"],
        manifest["baseSha256"],
    )
    if result.get("status") != "written":
        return {
            **result,
            **_common(manifest, manifest_path, manifest_sha),
        }
    return {
        **result,
        **_common(manifest, manifest_path, manifest_sha),
        "status": "rolled-back",
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
            result = commit_disconnect(
                root,
                Path(args.manifest),
                args.manifest_sha256,
            )
        elif args.operation == "rollback":
            result = rollback_disconnect(
                root,
                Path(args.manifest),
                args.manifest_sha256,
            )
        else:
            result = verify_disconnect(
                root,
                Path(args.manifest),
                args.manifest_sha256,
            )
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
