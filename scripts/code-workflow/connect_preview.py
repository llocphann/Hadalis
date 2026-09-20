#!/usr/bin/env python3
"""Compose reviewed Connect identity with parser-backed insertion preview.

This coordinator is deliberately preview-only. It resolves one explicit reviewed
connect target through analyze.py, passes only primitive semantic identity to a
second connect.py request, and rejects any drift between the two requests.

No parser ranges, node indices, QObject/QJSValue references, or parser objects
cross the request boundary. Type compatibility and cycle safety remain UNKNOWN,
so this helper never grants Apply authorization or stages artifacts.
"""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
from typing import Callable

PROTOCOL = 1
TYPE_UNKNOWN = "unknown-unresolved"
CYCLE_UNKNOWN = "unknown-incomplete-projection"
DIRECT_BINDING_VALUE_KINDS = {"identifier", "member_expression"}

Runner = Callable[[list[str]], tuple[int, dict]]


def emit(payload: dict, exit_code: int) -> int:
    print(json.dumps({"protocol": PROTOCOL, **payload}, ensure_ascii=False))
    return exit_code


def _runtime_path(root: Path, relative: str) -> Path:
    request = Path(relative)
    if request.is_absolute():
        raise ValueError("reviewed source path must be runtime-relative")
    candidate = (root / request).resolve()
    try:
        candidate.relative_to(root)
    except ValueError as exc:
        raise ValueError("reviewed source path escapes runtime root") from exc
    if candidate.suffix != ".qml" or not candidate.is_file():
        raise ValueError("reviewed source path must name an existing .qml file")
    return candidate


def load_reviewed_connect_target(
    root: Path,
    target_id: str,
    connect_target_id: str,
) -> dict:
    manifest_path = root / "defaults/code-workflow-ir.json"
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise ValueError(f"reviewed manifest unavailable: {exc}") from exc

    graph = (manifest.get("graphs") or {}).get(target_id)
    if not isinstance(graph, dict):
        raise ValueError("reviewed target graph missing")

    matches = [
        item for item in (graph.get("connectTargets") or [])
        if isinstance(item, dict) and item.get("id") == connect_target_id
    ]
    if len(matches) != 1:
        raise ValueError("reviewed connect target must resolve exactly once")
    target = matches[0]

    required_strings = (
        "id",
        "parentNodeId",
        "sourcePath",
        "parentObjectNeedle",
        "bindingName",
        "sourceExpression",
        "reviewedParentSemanticKind",
        "reviewedValueKind",
        "typeCompatibility",
        "cycleStatus",
    )
    for key in required_strings:
        if not isinstance(target.get(key), str) or not target[key]:
            raise ValueError(f"reviewed connect target missing {key}")

    if target["id"] != connect_target_id:
        raise ValueError("reviewed connect target identity drifted")
    if graph.get("sourcePath") != target["sourcePath"]:
        raise ValueError("reviewed connect target source path drifted from graph")

    parent_nodes = [
        node for node in (graph.get("nodes") or [])
        if isinstance(node, dict) and node.get("id") == target["parentNodeId"]
    ]
    if len(parent_nodes) != 1:
        raise ValueError("reviewed connect target parent node must resolve exactly once")
    if parent_nodes[0].get("sourcePath") != target["sourcePath"]:
        raise ValueError("reviewed connect target source path drifted from parent node")

    _runtime_path(root, target["sourcePath"])

    if target["reviewedParentSemanticKind"] != "object":
        raise ValueError("reviewed Connect parent must remain an object")
    if target["reviewedValueKind"] not in DIRECT_BINDING_VALUE_KINDS:
        raise ValueError("reviewed Connect value kind left direct-binding subset")
    if target["typeCompatibility"] != TYPE_UNKNOWN:
        raise ValueError("reviewed Connect type status must remain UNKNOWN")
    if target["cycleStatus"] != CYCLE_UNKNOWN:
        raise ValueError("reviewed Connect cycle status must remain UNKNOWN")
    if target.get("previewable") is not False or target.get("editable") is not False:
        raise ValueError("reviewed Connect target must remain non-authoritative")

    return {
        "connectTargetId": target["id"],
        "parentNodeId": target["parentNodeId"],
        "sourcePath": target["sourcePath"],
        "parentObjectNeedle": target["parentObjectNeedle"],
        "bindingName": target["bindingName"],
        "sourceExpression": target["sourceExpression"],
        "reviewedParentSemanticKind": target["reviewedParentSemanticKind"],
        "reviewedValueKind": target["reviewedValueKind"],
        "typeCompatibility": target["typeCompatibility"],
        "cycleStatus": target["cycleStatus"],
    }


def run_json_request(argv: list[str]) -> tuple[int, dict]:
    completed = subprocess.run(
        argv,
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    stdout = completed.stdout.strip()
    if not stdout:
        return completed.returncode, {
            "status": "error",
            "reason": "helper-produced-no-json",
            "detail": completed.stderr.strip(),
        }
    try:
        payload = json.loads(stdout)
    except json.JSONDecodeError as exc:
        return completed.returncode or 8, {
            "status": "error",
            "reason": "helper-produced-invalid-json",
            "detail": str(exc),
        }
    if not isinstance(payload, dict):
        return completed.returncode or 8, {
            "status": "error",
            "reason": "helper-json-must-be-object",
        }
    return completed.returncode, payload


def _helper_command(
    root: Path,
    helper: str,
    grammar: str,
    library: str,
) -> list[str]:
    command = [sys.executable, str(root / "scripts/code-workflow" / helper)]
    if grammar:
        command += ["--grammar", grammar]
    if library:
        command += ["--library", library]
    return command


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
        "typeCompatibility": TYPE_UNKNOWN,
        "cycleStatus": CYCLE_UNKNOWN,
        "applyEnabled": False,
        "artifactsStaged": False,
    }
    payload.update(evidence)
    return payload


def coordinate_connect_preview(
    root: Path,
    target_id: str,
    connect_target_id: str,
    grammar: str = "",
    library: str = "",
    request_runner: Runner = run_json_request,
) -> dict:
    descriptor = load_reviewed_connect_target(
        root, target_id, connect_target_id)

    resolver_command = _helper_command(root, "analyze.py", grammar, library) + [
        "--root", str(root),
        "--path", descriptor["sourcePath"],
        "--object-needle", descriptor["parentObjectNeedle"],
    ]
    resolver_code, resolver = request_runner(resolver_command)
    if resolver_code != 0 or resolver.get("status") != "ok":
        return _blocked(
            "resolver",
            str(resolver.get("reason", "reviewed-parent-resolution-failed")),
            target_id,
            connect_target_id,
            resolverStatus=resolver.get("status", ""),
        )

    if resolver.get("sourcePath") != descriptor["sourcePath"]:
        return _blocked(
            "resolver",
            "resolver-source-path-drift",
            target_id,
            connect_target_id,
        )
    source_sha = resolver.get("sourceSha256")
    if (
        not isinstance(source_sha, str)
        or len(source_sha) != 64
        or any(ch not in "0123456789abcdef" for ch in source_sha.lower())
    ):
        return _blocked(
            "resolver",
            "resolver-source-sha-invalid",
            target_id,
            connect_target_id,
        )
    if resolver.get("diagnostics"):
        return _blocked(
            "resolver",
            "current-source-has-parser-diagnostics",
            target_id,
            connect_target_id,
        )

    reviewed = resolver.get("reviewedObjectAnchor")
    if not isinstance(reviewed, dict) or reviewed.get("status") != "resolved":
        return _blocked(
            "resolver",
            "reviewed-parent-object-not-resolved",
            target_id,
            connect_target_id,
        )
    if reviewed.get("semanticAnchorUnique") is not True:
        return _blocked(
            "resolver",
            "reviewed-parent-object-not-unique",
            target_id,
            connect_target_id,
        )
    if reviewed.get("semanticKind") != descriptor["reviewedParentSemanticKind"]:
        return _blocked(
            "resolver",
            "reviewed-parent-semantic-kind-drift",
            target_id,
            connect_target_id,
        )
    if reviewed.get("opaqueContext") is True:
        return _blocked(
            "resolver",
            "reviewed-parent-object-became-opaque",
            target_id,
            connect_target_id,
        )
    parent_anchor = reviewed.get("semanticAnchor")
    if not isinstance(parent_anchor, str) or not parent_anchor:
        return _blocked(
            "resolver",
            "reviewed-parent-semantic-anchor-missing",
            target_id,
            connect_target_id,
        )

    handoff = {
        "sourcePath": descriptor["sourcePath"],
        "sourceSha256": source_sha,
        "connectTargetId": descriptor["connectTargetId"],
        "parentSemanticAnchor": parent_anchor,
        "bindingName": descriptor["bindingName"],
        "sourceExpression": descriptor["sourceExpression"],
        "reviewedParentSemanticKind": descriptor["reviewedParentSemanticKind"],
        "reviewedValueKind": descriptor["reviewedValueKind"],
    }

    insertion_command = _helper_command(root, "connect.py", grammar, library) + [
        "--root", str(root),
        "--path", handoff["sourcePath"],
        "--base-sha256", handoff["sourceSha256"],
        "--parent-semantic-anchor", handoff["parentSemanticAnchor"],
        "--binding-name", handoff["bindingName"],
        "--expression", handoff["sourceExpression"],
    ]
    insertion_code, insertion = request_runner(insertion_command)
    if insertion_code != 0 or insertion.get("status") != "preview":
        return _blocked(
            "insertion",
            str(insertion.get("reason", "connect-insertion-preview-failed")),
            target_id,
            connect_target_id,
            resolverSourceSha256=source_sha,
            insertionStatus=insertion.get("status", ""),
        )

    if insertion.get("sourcePath") != handoff["sourcePath"]:
        return _blocked(
            "verification",
            "insertion-source-path-drift",
            target_id,
            connect_target_id,
        )
    if insertion.get("baseSha256") != handoff["sourceSha256"]:
        return _blocked(
            "verification",
            "insertion-source-sha-drift",
            target_id,
            connect_target_id,
        )
    if insertion.get("parentSemanticAnchor") != handoff["parentSemanticAnchor"]:
        return _blocked(
            "verification",
            "insertion-parent-anchor-drift",
            target_id,
            connect_target_id,
        )
    if insertion.get("bindingName") != handoff["bindingName"]:
        return _blocked(
            "verification",
            "insertion-binding-name-drift",
            target_id,
            connect_target_id,
        )
    if insertion.get("expression") != handoff["sourceExpression"]:
        return _blocked(
            "verification",
            "insertion-expression-drift",
            target_id,
            connect_target_id,
        )
    if insertion.get("commandKind") != "connect-binding":
        return _blocked(
            "verification",
            "insertion-command-kind-drift",
            target_id,
            connect_target_id,
        )
    if insertion.get("previewMode") != "connect":
        return _blocked(
            "verification",
            "insertion-preview-mode-drift",
            target_id,
            connect_target_id,
        )
    if insertion.get("insertedSemanticKind") != "binding":
        return _blocked(
            "verification",
            "inserted-semantic-kind-drift",
            target_id,
            connect_target_id,
        )
    if insertion.get("insertedValueKind") != handoff["reviewedValueKind"]:
        return _blocked(
            "verification",
            "inserted-value-kind-drift",
            target_id,
            connect_target_id,
        )
    if insertion.get("typeCompatibility") != TYPE_UNKNOWN:
        return _blocked(
            "verification",
            "type-compatibility-must-remain-unknown",
            target_id,
            connect_target_id,
        )
    if insertion.get("cycleStatus") != CYCLE_UNKNOWN:
        return _blocked(
            "verification",
            "cycle-status-must-remain-unknown",
            target_id,
            connect_target_id,
        )
    if insertion.get("applyEnabled") is not False:
        return _blocked(
            "verification",
            "connect-preview-must-not-enable-apply",
            target_id,
            connect_target_id,
        )

    return {
        "status": "preview",
        "coordinator": "reviewed-connect-preview-v1",
        "targetId": target_id,
        "connectTargetId": connect_target_id,
        "sourcePath": handoff["sourcePath"],
        "baseSha256": handoff["sourceSha256"],
        "candidateSha256": insertion.get("candidateSha256", ""),
        "parentSemanticAnchor": handoff["parentSemanticAnchor"],
        "insertedSemanticAnchor": insertion.get("insertedSemanticAnchor", ""),
        "bindingName": handoff["bindingName"],
        "expression": handoff["sourceExpression"],
        "commandKind": "connect-binding",
        "previewMode": "connect",
        "insertedSemanticKind": insertion.get("insertedSemanticKind"),
        "insertedValueKind": insertion.get("insertedValueKind"),
        "primitiveHandoff": handoff,
        "insertionEvidence": insertion.get("insertionEvidence", {}),
        "patch": insertion.get("patch", {}),
        "preview": insertion.get("preview", ""),
        "typeCompatibility": TYPE_UNKNOWN,
        "cycleStatus": CYCLE_UNKNOWN,
        "applyEnabled": False,
        "artifactsStaged": False,
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
            "applyEnabled": False,
            "artifactsStaged": False,
        }, 4)

    grammar = args.grammar or os.environ.get("HADALIS_WORKFLOW_GRAMMAR", "")
    library = args.library or os.environ.get("HADALIS_TREE_SITTER_LIBRARY", "")

    try:
        result = coordinate_connect_preview(
            root,
            args.target_id,
            args.connect_target_id,
            grammar,
            library,
        )
    except ValueError as exc:
        return emit({
            "status": "invalid-request",
            "reason": str(exc),
            "applyEnabled": False,
            "artifactsStaged": False,
        }, 4)

    return emit(result, 0 if result.get("status") == "preview" else 7)


if __name__ == "__main__":
    raise SystemExit(main())
