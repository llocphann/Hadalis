#!/usr/bin/env python3
"""Compose Connect type + cycle proofs without source-write authorization.

2K-K introduced this coordinator as research-only. As of 2K-N it ships as an
audited implementation module used only by the production connect_prepare.py
coordinator; QML/UI code must not invoke it directly. It composes the qmllint
type proof with the source-backed cross-file cycle proof, requires both to
describe the exact same reviewed Connect identity and candidate snapshot, then
re-reads every source file used by the evidence.

A successful result is still not source-write permission. TYPE/CYCLE production
status remain UNKNOWN, Apply stays disabled, and the qualification alone never
stages artifacts.
"""

from __future__ import annotations

import argparse
from hashlib import sha256
import json
import os
from pathlib import Path
from typing import Callable

from connect_cycle import (
    PROVEN_ACYCLIC_CROSS_FILE,
    analyze_connect_cycle,
)
from connect_preview import CYCLE_UNKNOWN, TYPE_UNKNOWN
from connect_type import (
    TYPE_PROOF,
    prove_connect_type_compatibility,
)

PROTOCOL = 1
QUALIFICATION_PROOF = "qualified-reviewed-connect-research-v1"

TypeRunner = Callable[..., dict]
CycleRunner = Callable[..., dict]


def emit(payload: dict, exit_code: int) -> int:
    print(json.dumps({"protocol": PROTOCOL, **payload}, ensure_ascii=False))
    return exit_code


def _blocked(
    phase: str,
    reason: str,
    target_id: str,
    connect_target_id: str,
    **evidence,
) -> dict:
    payload = {
        "status": "blocked",
        "phase": phase,
        "reason": reason,
        "targetId": target_id,
        "connectTargetId": connect_target_id,
        "qualificationProof": "",
        "typeCompatibility": TYPE_UNKNOWN,
        "cycleStatus": CYCLE_UNKNOWN,
        "applyEnabled": False,
        "artifactsStaged": False,
        "productionIntegrated": False,
        "writeAuthorized": False,
    }
    payload.update(evidence)
    return payload


def _runtime_file_hash(root: Path, relative: str) -> tuple[str, str]:
    request = Path(str(relative))
    if request.is_absolute():
        raise ValueError("proof source path must be runtime-relative")
    candidate = (root / request).resolve()
    try:
        candidate.relative_to(root)
    except ValueError as exc:
        raise ValueError("proof source path escapes runtime root") from exc
    if not candidate.is_file():
        raise ValueError("proof source path is missing")
    try:
        data = candidate.read_bytes()
    except OSError as exc:
        raise ValueError(f"proof source read failed: {exc}") from exc
    return candidate.relative_to(root).as_posix(), sha256(data).hexdigest()


def _production_blockers_hold(payload: dict) -> bool:
    return (
        payload.get("typeCompatibility") == TYPE_UNKNOWN
        and payload.get("cycleStatus") == CYCLE_UNKNOWN
        and payload.get("applyEnabled") is False
        and payload.get("artifactsStaged") is False
        and payload.get("productionIntegrated") is False
    )


def qualify_reviewed_connect(
    root: Path,
    target_id: str,
    connect_target_id: str,
    grammar: str = "",
    library: str = "",
    qmllint: str = "",
    type_runner: TypeRunner = prove_connect_type_compatibility,
    cycle_runner: CycleRunner = analyze_connect_cycle,
) -> dict:
    type_proof = type_runner(
        root,
        target_id,
        connect_target_id,
        grammar,
        library,
        qmllint,
    )
    if (
        type_proof.get("status") != "proof"
        or type_proof.get("typeCompatibilityProof") != TYPE_PROOF
    ):
        return _blocked(
            "type-proof",
            str(type_proof.get("reason", "qualified-type-proof-missing")),
            target_id,
            connect_target_id,
            typeProofStatus=type_proof.get("status", ""),
        )
    if not _production_blockers_hold(type_proof):
        return _blocked(
            "type-proof",
            "type-proof-production-blockers-drifted",
            target_id,
            connect_target_id,
        )

    cycle_proof = cycle_runner(
        root,
        target_id,
        connect_target_id,
        grammar,
        library,
    )
    if (
        cycle_proof.get("status") != "analysis"
        or cycle_proof.get("cycleAnalysisStatus") != "proven-acyclic"
        or cycle_proof.get("cycleSafetyProof")
            != PROVEN_ACYCLIC_CROSS_FILE
    ):
        return _blocked(
            "cycle-proof",
            str(cycle_proof.get(
                "cycleAnalysisReason",
                cycle_proof.get("reason", "qualified-cycle-proof-missing"),
            )),
            target_id,
            connect_target_id,
            cycleProofStatus=cycle_proof.get("status", ""),
            cycleAnalysisStatus=cycle_proof.get(
                "cycleAnalysisStatus", ""),
            cycleSafetyProof=cycle_proof.get("cycleSafetyProof", ""),
        )
    if not _production_blockers_hold(cycle_proof):
        return _blocked(
            "cycle-proof",
            "cycle-proof-production-blockers-drifted",
            target_id,
            connect_target_id,
        )

    identity_fields = (
        "targetId",
        "connectTargetId",
        "sourcePath",
        "baseSha256",
        "candidateSha256",
        "parentSemanticAnchor",
        "targetProperty",
        "sourceExpression",
    )
    for field in identity_fields:
        if type_proof.get(field) != cycle_proof.get(field):
            return _blocked(
                "composition",
                "proof-identity-mismatch",
                target_id,
                connect_target_id,
                mismatchField=field,
                typeValue=type_proof.get(field, ""),
                cycleValue=cycle_proof.get(field, ""),
            )

    if type_proof.get("targetId") != target_id:
        return _blocked(
            "composition",
            "type-proof-target-id-drift",
            target_id,
            connect_target_id,
        )
    if type_proof.get("connectTargetId") != connect_target_id:
        return _blocked(
            "composition",
            "type-proof-connect-target-id-drift",
            target_id,
            connect_target_id,
        )

    source_path = str(type_proof.get("sourcePath") or "")
    base_sha = str(type_proof.get("baseSha256") or "")
    candidate_sha = str(type_proof.get("candidateSha256") or "")
    if len(base_sha) != 64:
        return _blocked(
            "composition",
            "proof-source-sha-invalid",
            target_id,
            connect_target_id,
        )
    if (
        len(candidate_sha) != 64
        or any(ch not in "0123456789abcdef" for ch in candidate_sha.lower())
    ):
        return _blocked(
            "composition",
            "proof-candidate-sha-invalid",
            target_id,
            connect_target_id,
        )

    external_path = str(cycle_proof.get("externalSourcePath") or "")
    external_sha = str(cycle_proof.get("externalSourceSha256") or "")
    if not external_path or len(external_sha) != 64:
        return _blocked(
            "composition",
            "cycle-external-source-evidence-incomplete",
            target_id,
            connect_target_id,
        )

    try:
        current_source_path, current_source_sha = _runtime_file_hash(
            root, source_path)
        current_external_path, current_external_sha = _runtime_file_hash(
            root, external_path)
    except ValueError as exc:
        return _blocked(
            "verification",
            str(exc),
            target_id,
            connect_target_id,
        )

    if current_source_path != source_path or current_source_sha != base_sha:
        return _blocked(
            "verification",
            "qualified-source-became-stale",
            target_id,
            connect_target_id,
            proofSourceSha256=base_sha,
            currentSourceSha256=current_source_sha,
        )
    if (
        current_external_path != external_path
        or current_external_sha != external_sha
    ):
        return _blocked(
            "verification",
            "qualified-external-source-became-stale",
            target_id,
            connect_target_id,
            proofExternalSourceSha256=external_sha,
            currentExternalSourceSha256=current_external_sha,
        )

    dependency_path = cycle_proof.get("dependencyPath")
    if (
        not isinstance(dependency_path, list)
        or not dependency_path
        or not all(isinstance(item, str) and item for item in dependency_path)
    ):
        return _blocked(
            "composition",
            "cycle-dependency-path-invalid",
            target_id,
            connect_target_id,
        )

    source_property_anchor = str(
        type_proof.get("sourcePropertySemanticAnchor") or "")
    terminal_property_anchor = str(
        cycle_proof.get("terminalPropertySemanticAnchor") or "")
    if not source_property_anchor or not terminal_property_anchor:
        return _blocked(
            "composition",
            "semantic-proof-anchor-missing",
            target_id,
            connect_target_id,
        )

    return {
        "status": "proof",
        "qualificationProof": QUALIFICATION_PROOF,
        "targetId": target_id,
        "connectTargetId": connect_target_id,
        "sourcePath": source_path,
        "baseSha256": base_sha,
        "candidateSha256": candidate_sha,
        "parentSemanticAnchor": type_proof.get(
            "parentSemanticAnchor", ""),
        "targetProperty": type_proof.get("targetProperty", ""),
        "sourceExpression": type_proof.get("sourceExpression", ""),
        "sourcePropertySemanticAnchor": source_property_anchor,
        "sourceDeclaredType": type_proof.get("sourceDeclaredType", ""),
        "typeCompatibilityProof": TYPE_PROOF,
        "cycleSafetyProof": PROVEN_ACYCLIC_CROSS_FILE,
        "dependencyPath": dependency_path,
        "externalModuleUri": cycle_proof.get("externalModuleUri", ""),
        "externalSourcePath": external_path,
        "externalSourceSha256": external_sha,
        "aliasTargetId": cycle_proof.get("aliasTargetId", ""),
        "terminalPropertySemanticAnchor": terminal_property_anchor,
        "terminalDeclaredType": cycle_proof.get(
            "terminalDeclaredType", ""),
        "terminalValueKind": cycle_proof.get("terminalValueKind", ""),
        "terminalValueText": cycle_proof.get("terminalValueText", ""),
        "fallbackLiteral": cycle_proof.get("fallbackLiteral", ""),
        "oracleTool": (type_proof.get("oracle") or {}).get("tool", ""),
        "oracleVersion": (type_proof.get("oracle") or {}).get(
            "version", ""),
        "proofsComposed": True,
        "sourceReverified": True,
        "externalSourceReverified": True,
        "typeCompatibility": TYPE_UNKNOWN,
        "cycleStatus": CYCLE_UNKNOWN,
        "applyEnabled": False,
        "artifactsStaged": False,
        "productionIntegrated": False,
        "writeAuthorized": False,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--root",
        default=str(Path(__file__).resolve().parents[2]),
    )
    parser.add_argument("--target-id", required=True)
    parser.add_argument("--connect-target-id", required=True)
    parser.add_argument("--grammar", default="")
    parser.add_argument("--library", default="")
    parser.add_argument("--qmllint", default="")
    args = parser.parse_args()

    root = Path(args.root).expanduser().resolve()
    if not root.is_dir():
        return emit({
            "status": "invalid-request",
            "reason": "runtime-root-missing",
            "qualificationProof": "",
            "typeCompatibility": TYPE_UNKNOWN,
            "cycleStatus": CYCLE_UNKNOWN,
            "applyEnabled": False,
            "artifactsStaged": False,
            "productionIntegrated": False,
            "writeAuthorized": False,
        }, 4)

    grammar = args.grammar or os.environ.get(
        "HADALIS_WORKFLOW_GRAMMAR", "")
    library = args.library or os.environ.get(
        "HADALIS_TREE_SITTER_LIBRARY", "")
    qmllint = args.qmllint or os.environ.get(
        "HADALIS_WORKFLOW_QMLLINT", "")

    result = qualify_reviewed_connect(
        root,
        args.target_id,
        args.connect_target_id,
        grammar,
        library,
        qmllint,
    )
    return emit(result, 0 if result.get("status") == "proof" else 7)


if __name__ == "__main__":
    raise SystemExit(main())
