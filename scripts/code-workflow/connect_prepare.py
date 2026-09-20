#!/usr/bin/env python3
"""Capability-gated preparation for one qualified Connect candidate.

This production coordinator never writes tracked QML source and never authorizes
Apply. It can first report whether the native QML parser, qmllint oracle and
writable reviewed source are available. On an explicit preparation request it
regenerates the full qualified proof from current source, reconstructs the exact
Connect candidate, reparses it, closes source/dependency TOCTOU windows, and
writes only rollback/candidate/manifest artifacts to an external state
directory.

Low-level type/cycle/qualification modules are implementation support for this
single coordinator; QML/UI code must not invoke those helpers directly.
"""

from __future__ import annotations

import argparse
from hashlib import sha256
import json
import os
from pathlib import Path
import shutil
from typing import Callable

from analyze import resolve_grammar, resolve_semantic_anchor, resolve_source
from apply import atomic_state_write
from connect import (
    DIRECT_BINDING_VALUE_KINDS,
    prepare_connect_binding_patch,
)
from connect_cycle import PROVEN_ACYCLIC_CROSS_FILE
from connect_preview import (
    CYCLE_UNKNOWN,
    TYPE_UNKNOWN,
    load_reviewed_connect_target,
)
from connect_qualify import (
    QUALIFICATION_PROOF,
    qualify_reviewed_connect,
)
from connect_type import (
    TYPE_PROOF,
    _find_qmllint,
    _qmllint_import_paths,
    _qmllint_version,
)
from native import Parser, verify_ranges
from semantics import extract

PROTOCOL = 1
ARTIFACT_PROOF = "prepared-qualified-connect-artifacts-v1"

QualificationRunner = Callable[..., dict]


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
        "artifactProof": "",
        "typeCompatibility": TYPE_UNKNOWN,
        "cycleStatus": CYCLE_UNKNOWN,
        "writeAuthorized": False,
        "applyEnabled": False,
        "artifactsStaged": False,
        "productionIntegrated": False,
    }
    payload.update(evidence)
    return payload


def _valid_sha(value: object) -> bool:
    return (
        isinstance(value, str)
        and len(value) == 64
        and all(ch in "0123456789abcdef" for ch in value.lower())
    )


def _runtime_file(root: Path, relative: str) -> Path:
    request = Path(str(relative))
    if request.is_absolute():
        raise ValueError("qualified source path must be runtime-relative")
    candidate = (root / request).resolve()
    try:
        candidate.relative_to(root)
    except ValueError as exc:
        raise ValueError("qualified source path escapes runtime root") from exc
    if candidate.suffix != ".qml" or not candidate.is_file():
        raise ValueError(
            "qualified source path must name an existing .qml file")
    return candidate


def _state_root_outside_runtime(root: Path, state_dir: Path) -> Path:
    state = state_dir.expanduser().resolve()
    if state == root:
        raise ValueError("Connect artifact state directory must be outside runtime root")
    try:
        state.relative_to(root)
    except ValueError:
        pass
    else:
        raise ValueError(
            "Connect artifact state directory must not be inside runtime root")
    return state


def probe_connect_preparation_capability(
    root: Path,
    target_id: str,
    connect_target_id: str,
    grammar: str = "",
    library: str = "",
    qmllint: str = "",
) -> dict:
    root = root.expanduser().resolve()
    common = {
        "status": "capability",
        "targetId": target_id,
        "connectTargetId": connect_target_id,
        "ready": False,
        "parserAvailable": False,
        "qmllintAvailable": False,
        "sourceWritable": False,
        "writeAuthorized": False,
        "applyEnabled": False,
        "artifactsStaged": False,
    }
    if not root.is_dir():
        return {**common, "reason": "runtime-root-missing"}

    try:
        descriptor = load_reviewed_connect_target(
            root, target_id, connect_target_id)
        source_path = _runtime_file(root, descriptor["sourcePath"])
        source = source_path.read_bytes()
        source.decode("utf-8")
    except (ValueError, OSError, UnicodeError) as exc:
        return {**common, "reason": str(exc)}

    source_writable = os.access(source_path, os.W_OK)
    grammar_path = resolve_grammar(root, grammar)
    if grammar_path is None:
        return {
            **common,
            "reason": "grammar-missing",
            "sourceWritable": source_writable,
            "sourcePath": descriptor["sourcePath"],
        }

    native_parser = None
    try:
        native_parser = Parser(grammar_path, library or None)
        with native_parser.parse(source) as (_, nodes):
            verify_ranges(source, nodes)
            semantic = extract(descriptor["sourcePath"], source, nodes)
    except OSError as exc:
        return {
            **common,
            "reason": "tree-sitter-library-missing",
            "detail": str(exc),
            "sourceWritable": source_writable,
            "sourcePath": descriptor["sourcePath"],
        }
    except (RuntimeError, AssertionError, UnicodeError) as exc:
        return {
            **common,
            "reason": "parser-capability-check-failed",
            "detail": str(exc),
            "sourceWritable": source_writable,
            "sourcePath": descriptor["sourcePath"],
        }
    finally:
        if native_parser is not None:
            native_parser.close()

    if semantic["diagnostics"]:
        return {
            **common,
            "reason": "current-source-has-parser-diagnostics",
            "parserAvailable": True,
            "sourceWritable": source_writable,
            "sourcePath": descriptor["sourcePath"],
            "parserGrammar": str(grammar_path),
        }

    tool = _find_qmllint(qmllint)
    if tool is None:
        return {
            **common,
            "reason": "qmllint-unavailable",
            "parserAvailable": True,
            "sourceWritable": source_writable,
            "sourcePath": descriptor["sourcePath"],
            "parserGrammar": str(grammar_path),
        }

    version_text, version = _qmllint_version(tool)
    if version is None or version[0] != 6 or version < (6, 8):
        return {
            **common,
            "reason": "qmllint-version-unqualified",
            "parserAvailable": True,
            "qmllintAvailable": True,
            "sourceWritable": source_writable,
            "sourcePath": descriptor["sourcePath"],
            "parserGrammar": str(grammar_path),
            "qmllintTool": tool,
            "qmllintVersion": version_text,
            "qmllintImportPaths": _qmllint_import_paths(),
        }

    if not source_writable:
        return {
            **common,
            "reason": "source-read-only",
            "parserAvailable": True,
            "qmllintAvailable": True,
            "sourceWritable": False,
            "sourcePath": descriptor["sourcePath"],
            "parserGrammar": str(grammar_path),
            "qmllintTool": tool,
            "qmllintVersion": version_text,
            "qmllintImportPaths": _qmllint_import_paths(),
        }

    return {
        **common,
        "reason": "ready",
        "ready": True,
        "parserAvailable": True,
        "qmllintAvailable": True,
        "sourceWritable": True,
        "sourcePath": descriptor["sourcePath"],
        "parserGrammar": str(grammar_path),
        "treeSitterLibrary": library or "system",
        "qmllintTool": tool,
        "qmllintVersion": version_text,
        "qmllintImportPaths": _qmllint_import_paths(),
    }


def _qualification_snapshot(qualification: dict) -> dict:
    keys = (
        "qualificationProof",
        "targetId",
        "connectTargetId",
        "sourcePath",
        "baseSha256",
        "candidateSha256",
        "parentSemanticAnchor",
        "targetProperty",
        "sourceExpression",
        "sourcePropertySemanticAnchor",
        "sourceDeclaredType",
        "typeCompatibilityProof",
        "cycleSafetyProof",
        "dependencyPath",
        "externalModuleUri",
        "externalSourcePath",
        "externalSourceSha256",
        "aliasTargetId",
        "terminalPropertySemanticAnchor",
        "terminalDeclaredType",
        "terminalValueKind",
        "terminalValueText",
        "fallbackLiteral",
        "oracleTool",
        "oracleVersion",
        "proofsComposed",
        "sourceReverified",
        "externalSourceReverified",
        "typeCompatibility",
        "cycleStatus",
        "writeAuthorized",
        "applyEnabled",
        "artifactsStaged",
        "productionIntegrated",
    )
    return {key: qualification.get(key) for key in keys}


def _qualification_identity_is_safe(
    qualification: dict,
    target_id: str,
    connect_target_id: str,
    descriptor: dict,
) -> tuple[bool, str]:
    if qualification.get("status") != "proof":
        return False, "qualification-proof-missing"
    if qualification.get("qualificationProof") != QUALIFICATION_PROOF:
        return False, "qualification-token-drifted"
    if qualification.get("targetId") != target_id:
        return False, "qualification-target-id-drifted"
    if qualification.get("connectTargetId") != connect_target_id:
        return False, "qualification-connect-target-id-drifted"
    if qualification.get("sourcePath") != descriptor["sourcePath"]:
        return False, "qualification-source-path-drifted"
    if qualification.get("targetProperty") != descriptor["bindingName"]:
        return False, "qualification-target-property-drifted"
    if qualification.get("sourceExpression") != descriptor["sourceExpression"]:
        return False, "qualification-source-expression-drifted"
    if qualification.get("typeCompatibilityProof") != TYPE_PROOF:
        return False, "qualification-type-proof-drifted"
    if qualification.get("cycleSafetyProof") != PROVEN_ACYCLIC_CROSS_FILE:
        return False, "qualification-cycle-proof-drifted"
    if qualification.get("proofsComposed") is not True:
        return False, "qualification-proofs-not-composed"
    if qualification.get("sourceReverified") is not True:
        return False, "qualification-source-not-reverified"
    if qualification.get("externalSourceReverified") is not True:
        return False, "qualification-external-source-not-reverified"
    if qualification.get("typeCompatibility") != TYPE_UNKNOWN:
        return False, "qualification-production-type-drifted"
    if qualification.get("cycleStatus") != CYCLE_UNKNOWN:
        return False, "qualification-production-cycle-drifted"
    if qualification.get("writeAuthorized") is not False:
        return False, "qualification-write-authorization-drifted"
    if qualification.get("applyEnabled") is not False:
        return False, "qualification-apply-drifted"
    if qualification.get("artifactsStaged") is not False:
        return False, "qualification-artifact-state-drifted"
    if qualification.get("productionIntegrated") is not False:
        return False, "qualification-production-integration-drifted"
    for key in ("baseSha256", "candidateSha256", "externalSourceSha256"):
        if not _valid_sha(qualification.get(key)):
            return False, "qualification-" + key + "-invalid"
    if not str(qualification.get("parentSemanticAnchor") or ""):
        return False, "qualification-parent-anchor-missing"
    if not str(qualification.get("sourcePropertySemanticAnchor") or ""):
        return False, "qualification-source-property-anchor-missing"
    if not str(qualification.get("terminalPropertySemanticAnchor") or ""):
        return False, "qualification-terminal-anchor-missing"
    dependency_path = qualification.get("dependencyPath")
    if (
        not isinstance(dependency_path, list)
        or not dependency_path
        or not all(isinstance(item, str) and item for item in dependency_path)
    ):
        return False, "qualification-dependency-path-invalid"
    return True, ""


def _write_connect_artifacts(
    state_dir: Path,
    source_path: str,
    source: bytes,
    candidate: bytes,
    qualification: dict,
    inserted_anchor: str,
) -> dict:
    base_sha = sha256(source).hexdigest()
    candidate_sha = sha256(candidate).hexdigest()
    external_path = str(qualification["externalSourcePath"])
    external_sha = str(qualification["externalSourceSha256"])
    identity = "\0".join([
        source_path,
        base_sha,
        candidate_sha,
        str(qualification["parentSemanticAnchor"]),
        str(qualification["targetProperty"]),
        str(qualification["sourceExpression"]),
        external_path,
        external_sha,
    ])
    transaction_id = sha256(identity.encode("utf-8")).hexdigest()[:24]
    directory = state_dir / transaction_id
    snapshot_path = directory / "snapshot.qml"
    candidate_path = directory / "candidate.qml"
    manifest_path = directory / "manifest.json"

    metadata = {
        "version": 1,
        "transactionId": transaction_id,
        "commandKind": "connect-binding",
        "artifactProof": ARTIFACT_PROOF,
        "qualificationProof": QUALIFICATION_PROOF,
        "sourcePath": source_path,
        "baseSha256": base_sha,
        "candidateSha256": candidate_sha,
        "parentSemanticAnchor": qualification["parentSemanticAnchor"],
        "insertedSemanticAnchor": inserted_anchor,
        "bindingName": qualification["targetProperty"],
        "expression": qualification["sourceExpression"],
        "sourcePropertySemanticAnchor":
            qualification["sourcePropertySemanticAnchor"],
        "typeCompatibilityProof": qualification["typeCompatibilityProof"],
        "cycleSafetyProof": qualification["cycleSafetyProof"],
        "dependencyPath": qualification["dependencyPath"],
        "externalSourcePath": external_path,
        "externalSourceSha256": external_sha,
        "terminalPropertySemanticAnchor":
            qualification["terminalPropertySemanticAnchor"],
        "typeCompatibility": TYPE_UNKNOWN,
        "cycleStatus": CYCLE_UNKNOWN,
        "snapshotPath": str(snapshot_path),
        "candidatePath": str(candidate_path),
        "writeAuthorized": False,
        "applyEnabled": False,
        "artifactsStaged": True,
        "productionIntegrated": False,
    }

    atomic_state_write(snapshot_path, source)
    atomic_state_write(candidate_path, candidate)
    atomic_state_write(
        manifest_path,
        (json.dumps(metadata, indent=2, sort_keys=True) + "\n").encode(
            "utf-8"),
    )

    if snapshot_path.read_bytes() != source:
        raise RuntimeError("prepared Connect rollback snapshot bytes drifted")
    if candidate_path.read_bytes() != candidate:
        raise RuntimeError("prepared Connect candidate bytes drifted")
    if sha256(candidate_path.read_bytes()).hexdigest() != candidate_sha:
        raise RuntimeError("prepared Connect candidate hash drifted")

    return {
        **metadata,
        "manifestPath": str(manifest_path),
    }


def prepare_qualified_connect_artifacts(
    root: Path,
    target_id: str,
    connect_target_id: str,
    state_dir: Path,
    grammar: str = "",
    library: str = "",
    qmllint: str = "",
    qualification_runner: QualificationRunner = qualify_reviewed_connect,
) -> dict:
    root = root.expanduser().resolve()
    if not root.is_dir():
        return _blocked(
            "request",
            "runtime-root-missing",
            target_id,
            connect_target_id,
        )

    try:
        state_root = _state_root_outside_runtime(root, state_dir)
        descriptor = load_reviewed_connect_target(
            root, target_id, connect_target_id)
    except ValueError as exc:
        return _blocked(
            "request",
            str(exc),
            target_id,
            connect_target_id,
        )

    qualification = qualification_runner(
        root,
        target_id,
        connect_target_id,
        grammar,
        library,
        qmllint,
    )
    safe, reason = _qualification_identity_is_safe(
        qualification,
        target_id,
        connect_target_id,
        descriptor,
    )
    if not safe:
        return _blocked(
            "qualification",
            reason,
            target_id,
            connect_target_id,
            qualificationStatus=qualification.get("status", ""),
        )

    try:
        source_path = _runtime_file(root, descriptor["sourcePath"])
        source = source_path.read_bytes()
        source.decode("utf-8")
        external_path = _runtime_file(
            root, str(qualification["externalSourcePath"]))
        external_source = external_path.read_bytes()
        external_source.decode("utf-8")
    except (ValueError, OSError, UnicodeError) as exc:
        return _blocked(
            "source",
            str(exc),
            target_id,
            connect_target_id,
        )

    source_sha = sha256(source).hexdigest()
    external_sha = sha256(external_source).hexdigest()
    if source_sha != qualification["baseSha256"]:
        return _blocked(
            "source",
            "qualified-source-became-stale-before-preparation",
            target_id,
            connect_target_id,
            qualifiedSha256=qualification["baseSha256"],
            currentSha256=source_sha,
        )
    if external_sha != qualification["externalSourceSha256"]:
        return _blocked(
            "source",
            "qualified-external-source-became-stale-before-preparation",
            target_id,
            connect_target_id,
            qualifiedSha256=qualification["externalSourceSha256"],
            currentSha256=external_sha,
        )
    if not os.access(source_path, os.W_OK):
        return _blocked(
            "source",
            "source-read-only",
            target_id,
            connect_target_id,
        )

    grammar_path = resolve_grammar(root, grammar)
    if grammar_path is None:
        return _blocked(
            "candidate",
            "grammar-missing",
            target_id,
            connect_target_id,
        )

    native_parser = None
    try:
        native_parser = Parser(grammar_path, library or None)
        with native_parser.parse(source) as (_, nodes):
            verify_ranges(source, nodes)
            semantic = extract(descriptor["sourcePath"], source, nodes)

        if semantic["diagnostics"]:
            return _blocked(
                "candidate",
                "current-source-has-parser-diagnostics",
                target_id,
                connect_target_id,
            )

        parent_anchor = str(qualification["parentSemanticAnchor"])
        parent_rebind = resolve_semantic_anchor(
            semantic["entries"], parent_anchor)
        if parent_rebind.get("status") != "resolved":
            return _blocked(
                "candidate",
                "qualified-parent-semantic-anchor-"
                    + str(parent_rebind.get("status", "unknown")),
                target_id,
                connect_target_id,
            )

        parent_matches = [
            entry for entry in semantic["entries"]
            if entry.get("anchor") == parent_anchor
        ]
        if len(parent_matches) != 1:
            return _blocked(
                "candidate",
                "qualified-parent-semantic-anchor-not-unique",
                target_id,
                connect_target_id,
            )
        parent_entry = parent_matches[0]

        prepared, candidate = prepare_connect_binding_patch(
            source,
            source_sha,
            parent_entry,
            semantic["entries"],
            descriptor["bindingName"],
            descriptor["sourceExpression"],
        )
        if candidate is None:
            return _blocked(
                "candidate",
                str(prepared.get(
                    "reason", "Connect candidate preparation failed")),
                target_id,
                connect_target_id,
                candidateStatus=prepared.get("status", ""),
            )

        candidate_sha = sha256(candidate).hexdigest()
        if candidate_sha != qualification["candidateSha256"]:
            return _blocked(
                "candidate",
                "qualified-candidate-sha-drift",
                target_id,
                connect_target_id,
                qualifiedCandidateSha256=qualification["candidateSha256"],
                preparedCandidateSha256=candidate_sha,
            )

        with native_parser.parse(candidate) as (_, candidate_nodes):
            verify_ranges(candidate, candidate_nodes)
            candidate_semantic = extract(
                descriptor["sourcePath"], candidate, candidate_nodes)

        if candidate_semantic["diagnostics"]:
            return _blocked(
                "candidate",
                "prepared-candidate-has-parser-diagnostics",
                target_id,
                connect_target_id,
            )

        rebound_parent = resolve_semantic_anchor(
            candidate_semantic["entries"], parent_anchor)
        if rebound_parent.get("status") != "resolved":
            return _blocked(
                "candidate",
                "qualified-parent-anchor-did-not-survive-candidate",
                target_id,
                connect_target_id,
            )

        parent_scope = parent_entry.get("scope")
        inserted_matches = [
            entry for entry in candidate_semantic["entries"]
            if entry.get("kind") == "binding"
            and entry.get("name") == descriptor["bindingName"]
            and entry.get("scope") == parent_scope
            and entry.get("anchor_unique") is True
            and entry.get("opaque_context") is not True
        ]
        if len(inserted_matches) != 1:
            return _blocked(
                "candidate",
                "prepared-inserted-binding-not-unique",
                target_id,
                connect_target_id,
            )

        inserted = inserted_matches[0]
        if inserted.get("value_kind") not in DIRECT_BINDING_VALUE_KINDS:
            return _blocked(
                "candidate",
                "prepared-inserted-binding-left-direct-subset",
                target_id,
                connect_target_id,
            )
        value_range = inserted.get("value_range")
        if (
            not isinstance(value_range, list)
            or len(value_range) != 2
            or not all(isinstance(value, int) for value in value_range)
        ):
            return _blocked(
                "candidate",
                "prepared-inserted-binding-value-range-unavailable",
                target_id,
                connect_target_id,
            )
        rendered = candidate[
            value_range[0]:value_range[1]
        ].decode("utf-8")
        if rendered != descriptor["sourceExpression"]:
            return _blocked(
                "candidate",
                "prepared-inserted-binding-expression-drift",
                target_id,
                connect_target_id,
            )
        inserted_anchor = str(inserted.get("anchor") or "")
        if not inserted_anchor:
            return _blocked(
                "candidate",
                "prepared-inserted-binding-anchor-missing",
                target_id,
                connect_target_id,
            )

        # Final TOCTOU closure immediately before writing state artifacts.
        final_source = source_path.read_bytes()
        final_external = external_path.read_bytes()
        if final_source != source:
            return _blocked(
                "pre-stage",
                "source-changed-before-artifact-staging",
                target_id,
                connect_target_id,
            )
        if sha256(final_external).hexdigest() != external_sha:
            return _blocked(
                "pre-stage",
                "external-source-changed-before-artifact-staging",
                target_id,
                connect_target_id,
            )
        if not os.access(source_path, os.W_OK):
            return _blocked(
                "pre-stage",
                "source-became-read-only-before-artifact-staging",
                target_id,
                connect_target_id,
            )

        artifacts = _write_connect_artifacts(
            state_root,
            descriptor["sourcePath"],
            source,
            candidate,
            qualification,
            inserted_anchor,
        )

        # State writes are not source writes, but success still requires that
        # both proof inputs remained unchanged through artifact persistence.
        source_after = source_path.read_bytes()
        external_after = external_path.read_bytes()
        if (
            source_after != source
            or sha256(external_after).hexdigest() != external_sha
        ):
            artifact_root = Path(artifacts["manifestPath"]).parent
            shutil.rmtree(artifact_root, ignore_errors=True)
            return _blocked(
                "post-stage",
                (
                    "source-changed-during-artifact-staging"
                    if source_after != source
                    else "external-source-changed-during-artifact-staging"
                ),
                target_id,
                connect_target_id,
            )

        return {
            "status": "prepared-connect-artifacts",
            "targetId": target_id,
            "connectTargetId": connect_target_id,
            **artifacts,
            "qualificationSnapshot": _qualification_snapshot(qualification),
            "sourceWritable": True,
            "sourceUnchanged": True,
            "externalSourceReverifiedAtStage": True,
            "writeAuthorized": False,
            "applyEnabled": False,
            "artifactsStaged": True,
            "productionIntegrated": False,
        }
    except OSError as exc:
        return _blocked(
            "candidate",
            "tree-sitter-library-or-artifact-write-failed",
            target_id,
            connect_target_id,
            detail=str(exc),
        )
    except (RuntimeError, AssertionError, UnicodeError) as exc:
        return _blocked(
            "candidate",
            "Connect artifact preparation failed",
            target_id,
            connect_target_id,
            detail=str(exc),
        )
    finally:
        if native_parser is not None:
            native_parser.close()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--root",
        default=str(Path(__file__).resolve().parents[2]),
    )
    parser.add_argument("--target-id", required=True)
    parser.add_argument("--connect-target-id", required=True)
    parser.add_argument("--probe", action="store_true")
    parser.add_argument("--state-dir", default="")
    parser.add_argument("--grammar", default="")
    parser.add_argument("--library", default="")
    parser.add_argument("--qmllint", default="")
    args = parser.parse_args()

    grammar = args.grammar or os.environ.get(
        "HADALIS_WORKFLOW_GRAMMAR", "")
    library = args.library or os.environ.get(
        "HADALIS_TREE_SITTER_LIBRARY", "")
    qmllint = args.qmllint or os.environ.get(
        "HADALIS_WORKFLOW_QMLLINT", "")

    if args.probe:
        result = probe_connect_preparation_capability(
            Path(args.root),
            args.target_id,
            args.connect_target_id,
            grammar,
            library,
            qmllint,
        )
        return emit(result, 0 if result.get("ready") is True else 7)

    if not str(args.state_dir).strip():
        return emit({
            "status": "invalid-request",
            "reason": "state-dir-required",
            "targetId": args.target_id,
            "connectTargetId": args.connect_target_id,
            "writeAuthorized": False,
            "applyEnabled": False,
            "artifactsStaged": False,
        }, 4)

    result = prepare_qualified_connect_artifacts(
        Path(args.root),
        args.target_id,
        args.connect_target_id,
        Path(args.state_dir),
        grammar,
        library,
        qmllint,
    )
    return emit(
        result,
        0 if result.get("status") == "prepared-connect-artifacts" else 7,
    )


if __name__ == "__main__":
    raise SystemExit(main())
