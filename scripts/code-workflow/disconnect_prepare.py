#!/usr/bin/env python3
"""Prepare exact artifacts for the first reviewed Disconnect target.

2K-T-A is intentionally narrower than the existing generic Disconnect preview:
only bar/clock edge clock.data.time may prepare artifacts. The helper reparses
the current source, verifies the exact binding/property/expression identity,
reconstructs the deletion candidate, proves the old semantic anchor is absent
from the candidate, and writes mode-0600 state artifacts outside the runtime
source tree. It never writes tracked QML and does not use Connect TYPE/CYCLE
proofs.
"""

from __future__ import annotations

import argparse
from hashlib import sha256
import json
import os
from pathlib import Path

from analyze import (
    PROTOCOL,
    QMLJS_VERSION,
    resolve_grammar,
    resolve_semantic_anchor,
    resolve_source,
)
from apply import atomic_state_write
from native import Parser, verify_ranges
from semantics import extract
from transaction import digest, prepare_disconnect_binding_patch

ARTIFACT_PROOF = "prepared-reviewed-disconnect-artifacts-v1"
POSTCONDITION = "semantic-anchor-missing"

REVIEWED_TARGETS = {
    "clock.data.time": {
        "graphTargetId": "bar/clock",
        "sourcePath": "modules/bar/ClockWidget.qml",
        "propertyName": "text",
        "expectedCurrent": "DateTime.timeDisplay",
        "resultingState": "unbound/default",
    },
}


def emit(payload: dict, exit_code: int) -> int:
    print(json.dumps({"protocol": PROTOCOL, **payload}, ensure_ascii=False))
    return exit_code


def _outside_runtime(root: Path, state_dir: Path) -> Path:
    resolved = state_dir.expanduser().resolve()
    try:
        resolved.relative_to(root)
    except ValueError:
        return resolved
    raise ValueError("Disconnect state directory must be outside runtime source tree")


def _write_artifacts(
    state_dir: Path,
    target: dict,
    edge_id: str,
    base_sha256: str,
    candidate_sha256: str,
    semantic_anchor: str,
    source: bytes,
    candidate: bytes,
) -> dict:
    identity = (
        ARTIFACT_PROOF
        + "\0" + edge_id
        + "\0" + target["sourcePath"]
        + "\0" + base_sha256
        + "\0" + candidate_sha256
        + "\0" + semantic_anchor
        + "\0" + target["propertyName"]
        + "\0" + target["expectedCurrent"]
    )
    transaction_id = sha256(identity.encode("utf-8")).hexdigest()[:24]
    artifact_root = state_dir / transaction_id
    snapshot_path = artifact_root / "snapshot.qml"
    candidate_path = artifact_root / "candidate.qml"
    manifest_path = artifact_root / "manifest.json"

    metadata = {
        "version": 1,
        "commandKind": "disconnect-binding",
        "artifactProof": ARTIFACT_PROOF,
        "transactionId": transaction_id,
        "graphTargetId": target["graphTargetId"],
        "reviewedEdgeId": edge_id,
        "sourcePath": target["sourcePath"],
        "baseSha256": base_sha256,
        "candidateSha256": candidate_sha256,
        "semanticAnchor": semantic_anchor,
        "propertyName": target["propertyName"],
        "expectedCurrent": target["expectedCurrent"],
        "resultingState": target["resultingState"],
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
        raise RuntimeError("prepared Disconnect snapshot bytes drifted")
    if candidate_path.read_bytes() != candidate:
        raise RuntimeError("prepared Disconnect candidate bytes drifted")
    if manifest_path.read_bytes() != manifest_bytes:
        raise RuntimeError("prepared Disconnect manifest bytes drifted")
    if digest(snapshot_path.read_bytes()) != base_sha256:
        raise RuntimeError("prepared Disconnect snapshot hash drifted")
    if digest(candidate_path.read_bytes()) != candidate_sha256:
        raise RuntimeError("prepared Disconnect candidate hash drifted")

    return {
        **metadata,
        "manifestPath": str(manifest_path),
        "manifestSha256": sha256(manifest_bytes).hexdigest(),
    }


def prepare_reviewed_disconnect_artifacts(
    root: Path,
    edge_id: str,
    base_sha256: str,
    expected_candidate_sha256: str,
    semantic_anchor: str,
    state_dir: Path,
    grammar_path: str = "",
    tree_sitter_library: str = "",
) -> dict:
    root = root.expanduser().resolve()
    target = REVIEWED_TARGETS.get(edge_id)
    if target is None:
        raise ValueError("Disconnect target is not in reviewed 2K-T subset")

    source_path = resolve_source(root, target["sourcePath"])
    if not os.access(source_path, os.W_OK):
        return {"status": "blocked", "reason": "source-read-only"}

    source = source_path.read_bytes()
    source.decode("utf-8")
    current_sha = digest(source)
    if current_sha != base_sha256:
        return {
            "status": "conflict",
            "reason": "base-sha-mismatch",
            "expectedSha256": base_sha256,
            "currentSha256": current_sha,
        }

    grammar = resolve_grammar(root, grammar_path)
    if grammar is None:
        return {"status": "unavailable", "reason": "grammar-missing"}
    library = (
        tree_sitter_library
        or os.environ.get("HADALIS_TREE_SITTER_LIBRARY", "")
        or None
    )

    parser = None
    try:
        parser = Parser(grammar, library)
        with parser.parse(source) as (_, nodes):
            verify_ranges(source, nodes)
            semantic = extract(target["sourcePath"], source, nodes)
        if semantic["diagnostics"]:
            return {
                "status": "blocked",
                "reason": "current-source-has-parser-diagnostics",
                "diagnostics": semantic["diagnostics"],
            }

        rebind = resolve_semantic_anchor(
            semantic["entries"], semantic_anchor)
        if rebind.get("status") != "resolved":
            return {
                "status": "conflict",
                "reason": "semantic-anchor-" + str(
                    rebind.get("status", "unknown")),
                "semanticRebind": rebind,
            }

        matches = [
            entry for entry in semantic["entries"]
            if entry.get("anchor") == semantic_anchor
        ]
        if len(matches) != 1:
            return {
                "status": "conflict",
                "reason": "semantic-anchor-not-unique",
            }
        entry = matches[0]
        if (
            entry.get("kind") != "binding"
            or entry.get("name") != target["propertyName"]
            or not entry.get("anchor_unique", False)
            or entry.get("opaque_context", False)
        ):
            return {
                "status": "unsupported",
                "reason": "reviewed-disconnect-binding-identity-mismatch",
            }

        value_range = entry.get("value_range")
        if not isinstance(value_range, list) or len(value_range) != 2:
            return {
                "status": "unsupported",
                "reason": "reviewed-disconnect-value-range-missing",
            }
        rendered = source[
            value_range[0]:value_range[1]
        ].decode("utf-8")
        if rendered != target["expectedCurrent"]:
            return {
                "status": "conflict",
                "reason": "reviewed-edge-source-expression-drift",
                "expectedCurrent": target["expectedCurrent"],
                "currentValue": rendered,
            }

        prepared, candidate = prepare_disconnect_binding_patch(
            source,
            base_sha256,
            entry,
            target["expectedCurrent"],
        )
        if candidate is None:
            return prepared

        candidate_sha = digest(candidate)
        if candidate_sha != expected_candidate_sha256:
            return {
                "status": "conflict",
                "reason": "preview-candidate-drift",
                "expectedCandidateSha256": expected_candidate_sha256,
                "currentCandidateSha256": candidate_sha,
            }

        with parser.parse(candidate) as (_, candidate_nodes):
            verify_ranges(candidate, candidate_nodes)
            candidate_semantic = extract(
                target["sourcePath"], candidate, candidate_nodes)
        if candidate_semantic["diagnostics"]:
            return {
                "status": "invalid-patch",
                "reason": "candidate-has-parser-diagnostics",
                "diagnostics": candidate_semantic["diagnostics"],
            }

        postcondition = resolve_semantic_anchor(
            candidate_semantic["entries"], semantic_anchor)
        if postcondition.get("status") != "missing":
            return {
                "status": "invalid-patch",
                "reason": "disconnected-semantic-anchor-still-resolves",
                "semanticRebind": postcondition,
            }

        state_root = _outside_runtime(root, state_dir)
        artifacts = _write_artifacts(
            state_root,
            target,
            edge_id,
            base_sha256,
            candidate_sha,
            semantic_anchor,
            source,
            candidate,
        )

        # Close the preparation TOCTOU window before handoff.
        final_source = source_path.read_bytes()
        if digest(final_source) != base_sha256:
            artifact_dir = Path(artifacts["manifestPath"]).parent
            for child in artifact_dir.iterdir():
                child.unlink()
            artifact_dir.rmdir()
            return {
                "status": "conflict",
                "reason": "source-changed-after-artifact-preparation",
                "expectedSha256": base_sha256,
                "currentSha256": digest(final_source),
            }

        return {
            "status": "prepared-disconnect-artifacts",
            **artifacts,
            "sourceWritable": True,
            "semanticRebind": rebind,
            "candidatePostcondition": postcondition,
            "parser": {
                "qmljsVersion": QMLJS_VERSION,
                "grammar": str(grammar),
                "treeSitterLibrary": library or "system",
            },
        }
    finally:
        if parser is not None:
            parser.close()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--root",
        default=str(Path(__file__).resolve().parents[2]),
    )
    parser.add_argument("--edge-id", required=True)
    parser.add_argument("--base-sha256", required=True)
    parser.add_argument("--expected-candidate-sha256", required=True)
    parser.add_argument("--semantic-anchor", required=True)
    parser.add_argument("--state-dir", required=True)
    parser.add_argument("--grammar", default="")
    parser.add_argument("--library", default="")
    args = parser.parse_args()

    root = Path(args.root).expanduser().resolve()
    if not root.is_dir():
        return emit({
            "status": "invalid-request",
            "reason": "runtime-root-missing",
        }, 4)

    try:
        result = prepare_reviewed_disconnect_artifacts(
            root=root,
            edge_id=args.edge_id,
            base_sha256=args.base_sha256,
            expected_candidate_sha256=args.expected_candidate_sha256,
            semantic_anchor=args.semantic_anchor,
            state_dir=Path(args.state_dir),
            grammar_path=args.grammar,
            tree_sitter_library=args.library,
        )
    except (OSError, ValueError, UnicodeError, RuntimeError) as exc:
        return emit({
            "status": "invalid-request",
            "reason": str(exc),
        }, 4)

    status = str(result.get("status", "error"))
    if status == "prepared-disconnect-artifacts":
        return emit(result, 0)
    if status == "conflict":
        return emit(result, 6)
    if status in ("blocked", "unsupported", "unavailable"):
        return emit(result, 7)
    return emit(result, 8)


if __name__ == "__main__":
    raise SystemExit(main())
