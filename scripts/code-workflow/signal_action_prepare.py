#!/usr/bin/env python3
"""Prepare exact private artifacts for the reviewed 2K-W-B signal/action proof."""

from __future__ import annotations

import argparse
from hashlib import sha256
import json
import os
from pathlib import Path

from analyze import PROTOCOL, resolve_source
from apply import atomic_state_write
import signal_action

ARTIFACT_PROOF = "prepared-reviewed-signal-action-artifacts-v1"
POSTCONDITION = "inserted-handler-rebound-exact-action"


def emit(payload: dict, exit_code: int) -> int:
    print(json.dumps({"protocol": PROTOCOL, **payload}, ensure_ascii=False))
    return exit_code


def _outside_runtime(root: Path, state_dir: Path) -> Path:
    resolved = state_dir.expanduser().resolve()
    try:
        resolved.relative_to(root)
    except ValueError:
        return resolved
    raise ValueError("signal/action state directory must be outside runtime source tree")


def _write_artifacts(
    state_dir: Path,
    preview: dict,
    source: bytes,
    candidate: bytes,
) -> dict:
    identity = "\0".join([
        ARTIFACT_PROOF,
        preview["targetId"],
        preview["signalActionTargetId"],
        preview["sourcePath"],
        preview["baseSha256"],
        preview["candidateSha256"],
        preview["parentSemanticAnchor"],
        preview["existingActionSemanticAnchor"],
        preview["insertedHandlerSemanticAnchor"],
        preview["handlerName"],
        preview["actionExpression"],
    ])
    transaction_id = sha256(identity.encode("utf-8")).hexdigest()[:24]
    artifact_root = state_dir / transaction_id
    snapshot_path = artifact_root / "snapshot.qml"
    candidate_path = artifact_root / "candidate.qml"
    manifest_path = artifact_root / "manifest.json"

    metadata = {
        "version": 1,
        "commandKind": "signal-action",
        "artifactProof": ARTIFACT_PROOF,
        "transactionId": transaction_id,
        "targetId": preview["targetId"],
        "signalActionTargetId": preview["signalActionTargetId"],
        "sourcePath": preview["sourcePath"],
        "baseSha256": preview["baseSha256"],
        "candidateSha256": preview["candidateSha256"],
        "parentSemanticAnchor": preview["parentSemanticAnchor"],
        "existingActionSemanticAnchor": preview["existingActionSemanticAnchor"],
        "insertedHandlerSemanticAnchor": preview["insertedHandlerSemanticAnchor"],
        "eventNodeId": preview["eventNodeId"],
        "actionNodeId": preview["actionNodeId"],
        "signalName": preview["signalName"],
        "handlerName": preview["handlerName"],
        "actionFunctionName": preview["actionFunctionName"],
        "actionExpression": preview["actionExpression"],
        "insertedSemanticKind": preview["insertedSemanticKind"],
        "insertedValueKind": preview["insertedValueKind"],
        "postcondition": POSTCONDITION,
        "snapshotPath": str(snapshot_path),
        "candidatePath": str(candidate_path),
        "writeAuthorized": False,
        "applyEnabled": False,
        "artifactsStaged": True,
        "productionIntegrated": False,
    }
    manifest_bytes = (
        json.dumps(metadata, indent=2, sort_keys=True) + "\n"
    ).encode("utf-8")

    atomic_state_write(snapshot_path, source)
    atomic_state_write(candidate_path, candidate)
    atomic_state_write(manifest_path, manifest_bytes)

    if snapshot_path.read_bytes() != source:
        raise RuntimeError("signal/action snapshot bytes drifted")
    if candidate_path.read_bytes() != candidate:
        raise RuntimeError("signal/action candidate bytes drifted")
    if manifest_path.read_bytes() != manifest_bytes:
        raise RuntimeError("signal/action manifest bytes drifted")
    if signal_action.digest(snapshot_path.read_bytes()) != preview["baseSha256"]:
        raise RuntimeError("signal/action snapshot hash drifted")
    if signal_action.digest(candidate_path.read_bytes()) != preview["candidateSha256"]:
        raise RuntimeError("signal/action candidate hash drifted")

    return {
        **metadata,
        "manifestPath": str(manifest_path),
        "manifestSha256": sha256(manifest_bytes).hexdigest(),
    }


def prepare_reviewed_signal_action_artifacts(
    root: Path,
    target_id: str,
    signal_action_target_id: str,
    base_sha256: str,
    expected_candidate_sha256: str,
    parent_semantic_anchor: str,
    existing_action_semantic_anchor: str,
    inserted_handler_semantic_anchor: str,
    state_dir: Path,
    grammar_path: str = "",
    tree_sitter_library: str = "",
) -> dict:
    root = root.expanduser().resolve()
    if target_id != "bar/media" or signal_action_target_id != signal_action.REVIEWED_TARGET_ID:
        raise ValueError("signal/action target is outside reviewed 2K-W subset")

    descriptor = signal_action.load_reviewed_signal_action_target(
        root, target_id, signal_action_target_id
    )
    source_path = resolve_source(root, descriptor["sourcePath"])
    if not os.access(source_path, os.W_OK):
        return {"status": "blocked", "reason": "source-read-only"}

    source = source_path.read_bytes()
    source.decode("utf-8")
    current_sha = signal_action.digest(source)
    if current_sha != base_sha256:
        return {
            "status": "conflict",
            "reason": "base-sha-mismatch",
            "expectedSha256": base_sha256,
            "currentSha256": current_sha,
        }

    preview, candidate = signal_action.build_reviewed_signal_action_preview(
        root,
        target_id,
        signal_action_target_id,
        grammar_path,
        tree_sitter_library,
    )
    if preview.get("status") != "preview" or candidate is None:
        return {
            "status": "blocked",
            "reason": "reviewed-signal-action-preview-not-ready",
            "preview": preview,
        }

    expected_identity = {
        "baseSha256": base_sha256,
        "candidateSha256": expected_candidate_sha256,
        "parentSemanticAnchor": parent_semantic_anchor,
        "existingActionSemanticAnchor": existing_action_semantic_anchor,
        "insertedHandlerSemanticAnchor": inserted_handler_semantic_anchor,
    }
    for key, expected in expected_identity.items():
        if str(preview.get(key, "")) != str(expected):
            return {
                "status": "conflict",
                "reason": "preview-handoff-drift",
                "field": key,
                "expected": expected,
                "current": preview.get(key, ""),
            }

    if (
        preview.get("handlerName") != descriptor["handlerName"]
        or preview.get("actionExpression") != descriptor["actionExpression"]
        or preview.get("insertedSemanticKind") != descriptor["insertedSemanticKind"]
        or preview.get("insertedValueKind") != descriptor["insertedValueKind"]
        or preview.get("parentSemanticRebind", {}).get("status") != "resolved"
        or preview.get("existingActionSemanticRebind", {}).get("status") != "resolved"
        or preview.get("applyEnabled") is not False
        or preview.get("artifactsStaged") is not False
        or preview.get("writeAuthorized") is not False
    ):
        return {
            "status": "blocked",
            "reason": "reviewed-signal-action-preview-invariant-drift",
        }

    state_root = _outside_runtime(root, state_dir)
    artifacts = _write_artifacts(state_root, preview, source, candidate)

    final_source = source_path.read_bytes()
    if signal_action.digest(final_source) != base_sha256:
        artifact_dir = Path(artifacts["manifestPath"]).parent
        for child in artifact_dir.iterdir():
            child.unlink()
        artifact_dir.rmdir()
        return {
            "status": "conflict",
            "reason": "source-changed-after-artifact-preparation",
            "expectedSha256": base_sha256,
            "currentSha256": signal_action.digest(final_source),
        }

    return {
        "status": "prepared-signal-action-artifacts",
        **artifacts,
        "sourceWritable": True,
        "previewProof": preview["previewProof"],
        "parentSemanticRebind": preview["parentSemanticRebind"],
        "existingActionSemanticRebind": preview["existingActionSemanticRebind"],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default=str(Path(__file__).resolve().parents[2]))
    parser.add_argument("--target-id", default="bar/media")
    parser.add_argument("--signal-action-target-id", default=signal_action.REVIEWED_TARGET_ID)
    parser.add_argument("--base-sha256", required=True)
    parser.add_argument("--expected-candidate-sha256", required=True)
    parser.add_argument("--parent-semantic-anchor", required=True)
    parser.add_argument("--existing-action-semantic-anchor", required=True)
    parser.add_argument("--inserted-handler-semantic-anchor", required=True)
    parser.add_argument("--state-dir", required=True)
    parser.add_argument("--grammar", default="")
    parser.add_argument("--library", default="")
    args = parser.parse_args()

    root = Path(args.root).expanduser().resolve()
    if not root.is_dir():
        return emit({"status": "invalid-request", "reason": "runtime-root-missing"}, 4)
    try:
        result = prepare_reviewed_signal_action_artifacts(
            root,
            args.target_id,
            args.signal_action_target_id,
            args.base_sha256,
            args.expected_candidate_sha256,
            args.parent_semantic_anchor,
            args.existing_action_semantic_anchor,
            args.inserted_handler_semantic_anchor,
            Path(args.state_dir),
            args.grammar,
            args.library,
        )
    except (OSError, ValueError, UnicodeError, RuntimeError) as exc:
        return emit({"status": "invalid-request", "reason": str(exc)}, 4)

    status = str(result.get("status", "error"))
    return emit(
        result,
        0 if status == "prepared-signal-action-artifacts"
        else 6 if status == "conflict"
        else 7 if status == "blocked"
        else 8,
    )


if __name__ == "__main__":
    raise SystemExit(main())
