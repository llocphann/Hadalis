#!/usr/bin/env python3
"""Atomic engine for exact prepared 2K-W-B signal/action artifacts."""

from __future__ import annotations

import argparse
from hashlib import sha256
import json
import os
from pathlib import Path

from analyze import PROTOCOL, resolve_source
from commit import atomic_replace_if_hash
from signal_action_prepare import ARTIFACT_PROOF, POSTCONDITION
import signal_action

EXPECTED = {
    "targetId": "bar/media",
    "signalActionTargetId": "media.signal.doubleClickToggle",
    "sourcePath": "modules/bar/Media.qml",
    "eventNodeId": "media.input",
    "actionNodeId": "media.toggle",
    "signalName": "doubleClicked",
    "handlerName": "onDoubleClicked",
    "actionFunctionName": "toggleExpanded",
    "actionExpression": "root.toggleExpanded()",
    "insertedSemanticKind": "handler-candidate",
    "insertedValueKind": "call_expression",
}


def emit(payload: dict, exit_code: int) -> int:
    print(json.dumps({"protocol": PROTOCOL, **payload}, ensure_ascii=False))
    return exit_code


def load_signal_action_manifest(
    manifest_path: Path,
    expected_manifest_sha256: str = "",
):
    path = manifest_path.expanduser().resolve()
    manifest_bytes = path.read_bytes()
    manifest_sha = sha256(manifest_bytes).hexdigest()
    if expected_manifest_sha256 and manifest_sha != expected_manifest_sha256:
        raise ValueError("prepared signal/action manifest hash mismatch")

    payload = json.loads(manifest_bytes.decode("utf-8"))
    if payload.get("version") != 1:
        raise ValueError("unsupported signal/action manifest version")
    if payload.get("commandKind") != "signal-action":
        raise ValueError("prepared manifest is not signal/action")
    if payload.get("artifactProof") != ARTIFACT_PROOF:
        raise ValueError("signal/action artifact proof token drifted")
    if payload.get("postcondition") != POSTCONDITION:
        raise ValueError("signal/action postcondition drifted")
    for key, value in EXPECTED.items():
        if payload.get(key) != value:
            raise ValueError("signal/action reviewed identity drifted: " + key)
    if payload.get("writeAuthorized") is not False:
        raise ValueError("signal/action manifest unexpectedly authorizes writes")
    if payload.get("applyEnabled") is not False:
        raise ValueError("signal/action manifest unexpectedly enables Apply")
    if payload.get("artifactsStaged") is not True:
        raise ValueError("signal/action artifacts are not staged")
    if payload.get("productionIntegrated") is not False:
        raise ValueError("signal/action production integration drifted")

    for key in (
        "transactionId",
        "baseSha256",
        "candidateSha256",
        "parentSemanticAnchor",
        "existingActionSemanticAnchor",
        "insertedHandlerSemanticAnchor",
        "snapshotPath",
        "candidatePath",
    ):
        if not str(payload.get(key, "")):
            raise ValueError("prepared signal/action manifest is incomplete")

    snapshot_path = Path(payload["snapshotPath"]).expanduser().resolve()
    candidate_path = Path(payload["candidatePath"]).expanduser().resolve()
    if snapshot_path.parent != path.parent or candidate_path.parent != path.parent:
        raise ValueError("signal/action artifact escapes manifest directory")
    if snapshot_path.name != "snapshot.qml" or candidate_path.name != "candidate.qml":
        raise ValueError("signal/action artifact filename drifted")

    snapshot = snapshot_path.read_bytes()
    candidate = candidate_path.read_bytes()
    snapshot.decode("utf-8")
    candidate.decode("utf-8")
    if signal_action.digest(snapshot) != payload["baseSha256"]:
        raise ValueError("prepared signal/action snapshot hash mismatch")
    if signal_action.digest(candidate) != payload["candidateSha256"]:
        raise ValueError("prepared signal/action candidate hash mismatch")
    return payload, snapshot, candidate, manifest_sha


def _common(manifest: dict, manifest_path: Path, manifest_sha: str) -> dict:
    return {
        "commandKind": "signal-action",
        "artifactProof": ARTIFACT_PROOF,
        "targetId": manifest["targetId"],
        "signalActionTargetId": manifest["signalActionTargetId"],
        "sourcePath": manifest["sourcePath"],
        "baseSha256": manifest["baseSha256"],
        "candidateSha256": manifest["candidateSha256"],
        "parentSemanticAnchor": manifest["parentSemanticAnchor"],
        "existingActionSemanticAnchor": manifest["existingActionSemanticAnchor"],
        "insertedHandlerSemanticAnchor": manifest["insertedHandlerSemanticAnchor"],
        "handlerName": manifest["handlerName"],
        "actionExpression": manifest["actionExpression"],
        "postcondition": manifest["postcondition"],
        "manifestPath": str(manifest_path.expanduser().resolve()),
        "manifestSha256": manifest_sha,
    }


def commit_signal_action(root: Path, manifest_path: Path, expected_manifest_sha256: str = "") -> dict:
    root = root.expanduser().resolve()
    manifest, _snapshot, candidate, manifest_sha = load_signal_action_manifest(
        manifest_path, expected_manifest_sha256
    )
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


def verify_signal_action(root: Path, manifest_path: Path, expected_manifest_sha256: str = "") -> dict:
    root = root.expanduser().resolve()
    manifest, _snapshot, _candidate, manifest_sha = load_signal_action_manifest(
        manifest_path, expected_manifest_sha256
    )
    source_path = resolve_source(root, manifest["sourcePath"])
    current_sha = signal_action.digest(source_path.read_bytes())
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


def rollback_signal_action(root: Path, manifest_path: Path, expected_manifest_sha256: str = "") -> dict:
    root = root.expanduser().resolve()
    manifest, snapshot, _candidate, manifest_sha = load_signal_action_manifest(
        manifest_path, expected_manifest_sha256
    )
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
        return {**result, **_common(manifest, manifest_path, manifest_sha)}
    return {
        **result,
        **_common(manifest, manifest_path, manifest_sha),
        "status": "rolled-back",
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("operation", choices=("commit", "verify", "rollback"))
    parser.add_argument("--root", default=str(Path(__file__).resolve().parents[2]))
    parser.add_argument("--manifest", required=True)
    parser.add_argument("--manifest-sha256", default="")
    args = parser.parse_args()

    root = Path(args.root).expanduser().resolve()
    if not root.is_dir():
        return emit({"status": "invalid-request", "reason": "runtime-root-missing"}, 4)
    try:
        if args.operation == "commit":
            result = commit_signal_action(root, Path(args.manifest), args.manifest_sha256)
        elif args.operation == "rollback":
            result = rollback_signal_action(root, Path(args.manifest), args.manifest_sha256)
        else:
            result = verify_signal_action(root, Path(args.manifest), args.manifest_sha256)
    except (OSError, ValueError, UnicodeError, json.JSONDecodeError) as exc:
        return emit({"status": "invalid-request", "reason": str(exc)}, 4)

    status = str(result.get("status", "error"))
    return emit(
        result,
        0 if status in ("written", "rolled-back", "verified")
        else 6 if status == "conflict"
        else 7 if status == "blocked"
        else 8,
    )


if __name__ == "__main__":
    raise SystemExit(main())
