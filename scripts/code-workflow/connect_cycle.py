#!/usr/bin/env python3
"""Research-only Connect dependency/cycle coverage proof.

This helper deliberately does not authorize production Connect. It proves only a
small parser-resolved local dependency subset:

- the reviewed source expression is one explicit parent-id member reference;
- every traversed same-object property/binding is uniquely resolved by semantic
  scope and remains non-opaque;
- each dependency value is either another explicit parent-id member reference or
  a direct literal terminal.

Within that closed subset, reaching the absent target property proves a cycle and
reaching only literal terminals proves acyclicity. Any external object, complex
expression, unqualified identifier, missing/ambiguous member, or opaque semantic
entry remains UNKNOWN. The reviewed presentation graph is never treated as a
complete dependency graph.
"""

from __future__ import annotations

import argparse
from hashlib import sha256
import json
import os
from pathlib import Path
import re

from analyze import resolve_grammar, resolve_source
from connect_preview import (
    CYCLE_UNKNOWN,
    TYPE_UNKNOWN,
    coordinate_connect_preview,
    load_reviewed_connect_target,
)
from native import Parser, verify_ranges
from semantics import extract

PROTOCOL = 1
PROVEN_CYCLE = "cycle-proven-local-closure"
PROVEN_ACYCLIC = "acyclic-closed-local-closure"
PROOF_UNKNOWN = "unknown-incomplete-local-closure"
_LITERAL_VALUE_KINDS = {"true", "false", "number", "string"}
_SIMPLE_MEMBER = re.compile(
    r"^([A-Za-z_][A-Za-z0-9_]*)\.([A-Za-z_][A-Za-z0-9_]*)$"
)


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
        "cycleSafetyProof": PROOF_UNKNOWN,
        "cycleStatus": CYCLE_UNKNOWN,
        "typeCompatibility": TYPE_UNKNOWN,
        "applyEnabled": False,
        "artifactsStaged": False,
        "productionIntegrated": False,
    }
    payload.update(evidence)
    return payload


def _value_text(source: bytes, entry: dict) -> str | None:
    span = entry.get("value_range")
    if (
        not isinstance(span, list)
        or len(span) != 2
        or not all(isinstance(item, int) for item in span)
        or not (0 <= span[0] <= span[1] <= len(source))
    ):
        return None
    try:
        return source[span[0]:span[1]].decode("utf-8").strip()
    except UnicodeError:
        return None


def prove_local_dependency_closure(
    source: bytes,
    entries: list[dict],
    parent_anchor: str,
    source_expression: str,
    target_property: str,
) -> dict:
    parent_matches = [
        entry for entry in entries
        if entry.get("anchor") == parent_anchor
    ]
    if len(parent_matches) != 1:
        return {
            "status": "unknown",
            "reason": "parent-semantic-anchor-not-unique",
            "cycleSafetyProof": PROOF_UNKNOWN,
            "dependencyPath": [],
        }

    parent = parent_matches[0]
    if (
        parent.get("kind") != "object"
        or parent.get("anchor_unique") is not True
        or parent.get("opaque_context") is True
    ):
        return {
            "status": "unknown",
            "reason": "parent-object-not-safe-for-cycle-resolution",
            "cycleSafetyProof": PROOF_UNKNOWN,
            "dependencyPath": [],
        }

    parent_id = str(parent.get("qml_id") or "")
    scope = parent.get("scope")
    if (
        not parent_id
        or not isinstance(scope, list)
        or not scope
        or not isinstance(target_property, str)
        or not target_property
    ):
        return {
            "status": "unknown",
            "reason": "parent-cycle-identity-incomplete",
            "cycleSafetyProof": PROOF_UNKNOWN,
            "dependencyPath": [],
        }

    def parse_member(expression: str) -> tuple[str, str] | None:
        match = _SIMPLE_MEMBER.fullmatch(str(expression))
        if not match:
            return None
        return match.group(1), match.group(2)

    start_ref = parse_member(source_expression)
    if start_ref is None:
        return {
            "status": "unknown",
            "reason": "source-expression-outside-explicit-member-subset",
            "cycleSafetyProof": PROOF_UNKNOWN,
            "dependencyPath": [],
        }
    if start_ref[0] != parent_id:
        return {
            "status": "unknown",
            "reason": "source-expression-base-is-external",
            "cycleSafetyProof": PROOF_UNKNOWN,
            "dependencyPath": [],
        }

    completed: set[str] = set()

    def walk(member_name: str, stack: list[str]) -> dict:
        path = [*stack, member_name]
        if member_name == target_property:
            return {
                "status": "proven-cycle",
                "reason": "dependency-closure-reaches-connect-target",
                "cycleSafetyProof": PROVEN_CYCLE,
                "cycleKind": "proposed-target-cycle",
                "dependencyPath": path,
            }

        if member_name in stack:
            cycle_start = stack.index(member_name)
            return {
                "status": "proven-cycle",
                "reason": "existing-cycle-in-source-dependency-closure",
                "cycleSafetyProof": PROVEN_CYCLE,
                "cycleKind": "existing-source-cycle",
                "dependencyPath": [*stack[cycle_start:], member_name],
            }

        if member_name in completed:
            return {
                "status": "proven-acyclic",
                "reason": "dependency-already-proven-closed",
                "cycleSafetyProof": PROVEN_ACYCLIC,
                "dependencyPath": path,
            }

        candidates = [
            entry for entry in entries
            if entry.get("scope") == scope
            and entry.get("name") == member_name
            and entry.get("kind") in {"property", "binding"}
            and entry.get("anchor_unique") is True
            and entry.get("opaque_context") is not True
        ]
        if len(candidates) != 1:
            return {
                "status": "unknown",
                "reason": "same-scope-dependency-not-unique",
                "cycleSafetyProof": PROOF_UNKNOWN,
                "dependencyPath": path,
                "dependencyName": member_name,
                "occurrences": len(candidates),
            }

        entry = candidates[0]
        value_kind = str(entry.get("value_kind") or "")
        value_text = _value_text(source, entry)
        if value_text is None:
            return {
                "status": "unknown",
                "reason": "dependency-value-range-unavailable",
                "cycleSafetyProof": PROOF_UNKNOWN,
                "dependencyPath": path,
                "dependencyName": member_name,
            }

        if value_kind in _LITERAL_VALUE_KINDS:
            completed.add(member_name)
            return {
                "status": "proven-acyclic",
                "reason": "closed-local-dependency-chain-ends-in-literal",
                "cycleSafetyProof": PROVEN_ACYCLIC,
                "dependencyPath": path,
                "terminalValueKind": value_kind,
            }

        if value_kind != "member_expression":
            return {
                "status": "unknown",
                "reason": "dependency-value-kind-outside-closed-subset",
                "cycleSafetyProof": PROOF_UNKNOWN,
                "dependencyPath": path,
                "dependencyName": member_name,
                "dependencyValueKind": value_kind,
            }

        dependency = parse_member(value_text)
        if dependency is None:
            return {
                "status": "unknown",
                "reason": "dependency-member-expression-not-simple",
                "cycleSafetyProof": PROOF_UNKNOWN,
                "dependencyPath": path,
                "dependencyName": member_name,
            }
        if dependency[0] != parent_id:
            return {
                "status": "unknown",
                "reason": "dependency-leaves-reviewed-parent-scope",
                "cycleSafetyProof": PROOF_UNKNOWN,
                "dependencyPath": path,
                "dependencyName": member_name,
                "externalBase": dependency[0],
            }

        result = walk(dependency[1], path)
        if result.get("status") == "proven-acyclic":
            completed.add(member_name)
        return result

    return walk(start_ref[1], [])


def analyze_connect_cycle(
    root: Path,
    target_id: str,
    connect_target_id: str,
    grammar: str = "",
    library: str = "",
) -> dict:
    try:
        descriptor = load_reviewed_connect_target(
            root, target_id, connect_target_id)
    except ValueError as exc:
        return _blocked(
            "descriptor",
            str(exc),
            target_id,
            connect_target_id,
        )

    preview = coordinate_connect_preview(
        root,
        target_id,
        connect_target_id,
        grammar,
        library,
    )
    if preview.get("status") != "preview":
        return _blocked(
            "connect-preview",
            str(preview.get("reason", "connect-preview-unavailable")),
            target_id,
            connect_target_id,
            connectPreviewStatus=preview.get("status", ""),
        )
    if preview.get("cycleStatus") != CYCLE_UNKNOWN:
        return _blocked(
            "connect-preview",
            "production-cycle-status-must-remain-unknown",
            target_id,
            connect_target_id,
        )

    try:
        source_path = resolve_source(root, descriptor["sourcePath"])
        source = source_path.read_bytes()
        source.decode("utf-8")
    except (ValueError, OSError, UnicodeError) as exc:
        return _blocked(
            "source",
            str(exc),
            target_id,
            connect_target_id,
        )

    source_sha = sha256(source).hexdigest()
    if source_sha != preview.get("baseSha256"):
        return _blocked(
            "source",
            "cycle-proof-source-sha-drift",
            target_id,
            connect_target_id,
            currentSha256=source_sha,
            previewSha256=preview.get("baseSha256", ""),
        )

    grammar_path = resolve_grammar(root, grammar)
    if grammar_path is None:
        return _blocked(
            "cycle-analysis",
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
    except OSError as exc:
        return _blocked(
            "cycle-analysis",
            "tree-sitter-library-missing",
            target_id,
            connect_target_id,
            detail=str(exc),
        )
    except (RuntimeError, AssertionError, UnicodeError) as exc:
        return _blocked(
            "cycle-analysis",
            "cycle-source-analysis-failed",
            target_id,
            connect_target_id,
            detail=str(exc),
        )
    finally:
        if native_parser is not None:
            native_parser.close()

    if semantic["diagnostics"]:
        return _blocked(
            "cycle-analysis",
            "current-source-has-parser-diagnostics",
            target_id,
            connect_target_id,
        )

    local = prove_local_dependency_closure(
        source,
        semantic["entries"],
        str(preview.get("parentSemanticAnchor") or ""),
        descriptor["sourceExpression"],
        descriptor["bindingName"],
    )

    return {
        "status": "analysis",
        "targetId": target_id,
        "connectTargetId": connect_target_id,
        "sourcePath": descriptor["sourcePath"],
        "baseSha256": source_sha,
        "parentSemanticAnchor": preview.get("parentSemanticAnchor", ""),
        "targetProperty": descriptor["bindingName"],
        "sourceExpression": descriptor["sourceExpression"],
        "cycleAnalysisStatus": local.get("status", "unknown"),
        "cycleSafetyProof": local.get(
            "cycleSafetyProof", PROOF_UNKNOWN),
        "cycleAnalysisReason": local.get("reason", ""),
        "dependencyPath": local.get("dependencyPath", []),
        "cycleKind": local.get("cycleKind", ""),
        "dependencyValueKind": local.get("dependencyValueKind", ""),
        "typeCompatibility": TYPE_UNKNOWN,
        "cycleStatus": CYCLE_UNKNOWN,
        "applyEnabled": False,
        "artifactsStaged": False,
        "productionIntegrated": False,
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
    args = parser.parse_args()

    root = Path(args.root).expanduser().resolve()
    if not root.is_dir():
        return emit({
            "status": "invalid-request",
            "reason": "runtime-root-missing",
            "cycleSafetyProof": PROOF_UNKNOWN,
            "cycleStatus": CYCLE_UNKNOWN,
            "typeCompatibility": TYPE_UNKNOWN,
            "applyEnabled": False,
            "artifactsStaged": False,
            "productionIntegrated": False,
        }, 4)

    grammar = args.grammar or os.environ.get(
        "HADALIS_WORKFLOW_GRAMMAR", "")
    library = args.library or os.environ.get(
        "HADALIS_TREE_SITTER_LIBRARY", "")

    result = analyze_connect_cycle(
        root,
        args.target_id,
        args.connect_target_id,
        grammar,
        library,
    )
    return emit(result, 0 if result.get("status") == "analysis" else 7)


if __name__ == "__main__":
    raise SystemExit(main())
