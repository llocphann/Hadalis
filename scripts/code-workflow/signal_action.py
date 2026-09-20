#!/usr/bin/env python3
"""Preview one reviewed QML signal -> existing action handler insertion.

2K-W-A is deliberately non-writing. It resolves one reviewed source object and
one already-existing QML action by semantic identity, inserts one simple handler
in memory, reparses the complete candidate, and proves both the inserted handler
and the existing action remain uniquely resolved. No artifact preparation,
authorization, TYPE/CYCLE inference, or source write is permitted here.
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
    resolve_reviewed_anchor,
    resolve_reviewed_object_anchor,
    resolve_semantic_anchor,
    resolve_source,
)
from native import Parser, verify_ranges
from semantics import extract

PREVIEW_PROOF = "reviewed-signal-action-preview-v1"
REVIEWED_TARGET_ID = "media.signal.doubleClickToggle"


def digest(source: bytes) -> str:
    return sha256(source).hexdigest()


def emit(payload: dict, exit_code: int) -> int:
    print(json.dumps({"protocol": PROTOCOL, **payload}, ensure_ascii=False))
    return exit_code


def _simple_handler_name(name: str) -> bool:
    if len(name) < 3 or not name.startswith("on") or not name[2].isupper():
        return False
    return all(
        ch == "_" or "0" <= ch <= "9"
        or "A" <= ch <= "Z" or "a" <= ch <= "z"
        for ch in name
    )


def _line_prefix(source: bytes, position: int):
    line_start = source.rfind(b"\n", 0, position) + 1
    prefix = source[line_start:position]
    return None if prefix.strip() else prefix


def load_reviewed_signal_action_target(
    root: Path,
    target_id: str,
    signal_action_target_id: str,
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
        item for item in (graph.get("signalActionTargets") or [])
        if isinstance(item, dict)
        and item.get("id") == signal_action_target_id
    ]
    if len(matches) != 1:
        raise ValueError(
            "reviewed signal/action target must resolve exactly once"
        )
    target = matches[0]

    required = (
        "id",
        "eventNodeId",
        "actionNodeId",
        "sourcePath",
        "parentObjectNeedle",
        "handlerName",
        "signalName",
        "actionFunctionNeedle",
        "actionFunctionName",
        "actionExpression",
        "reviewedParentSemanticKind",
        "reviewedActionSemanticKind",
        "insertedSemanticKind",
        "insertedValueKind",
    )
    for key in required:
        if not isinstance(target.get(key), str) or not target[key]:
            raise ValueError(
                f"reviewed signal/action target missing {key}"
            )

    if graph.get("sourcePath") != target["sourcePath"]:
        raise ValueError(
            "reviewed signal/action source path drifted from graph"
        )
    nodes = {
        item.get("id"): item
        for item in (graph.get("nodes") or [])
        if isinstance(item, dict)
    }
    if target["eventNodeId"] not in nodes:
        raise ValueError("reviewed event node missing")
    if target["actionNodeId"] not in nodes:
        raise ValueError("reviewed action node missing")
    if nodes[target["eventNodeId"]].get("kind") != "event":
        raise ValueError("reviewed signal source must remain an event node")
    if nodes[target["actionNodeId"]].get("kind") != "action":
        raise ValueError("reviewed action target must remain an action node")
    if nodes[target["eventNodeId"]].get("sourcePath") != target["sourcePath"]:
        raise ValueError("reviewed event source path drifted")
    if nodes[target["actionNodeId"]].get("sourcePath") != target["sourcePath"]:
        raise ValueError("reviewed action source path drifted")
    if target["reviewedParentSemanticKind"] != "object":
        raise ValueError("reviewed signal parent must remain an object")
    if target["reviewedActionSemanticKind"] != "function":
        raise ValueError("reviewed action must remain a QML function")
    if target["insertedSemanticKind"] != "handler-candidate":
        raise ValueError("reviewed insertion must remain a handler")
    if target["insertedValueKind"] != "call_expression":
        raise ValueError("reviewed handler must remain one call expression")
    if target.get("previewable") is not False:
        raise ValueError("W-A target must not be production-previewable")
    if target.get("editable") is not False:
        raise ValueError("W-A target must remain non-authoritative")

    resolve_source(root, target["sourcePath"])
    return target


def prepare_signal_action_patch(
    source: bytes,
    base_sha256: str,
    parent_entry: dict,
    semantic_entries: list[dict],
    handler_name: str,
    action_expression: str,
):
    current_sha = digest(source)
    if current_sha != base_sha256:
        return ({
            "status": "conflict",
            "reason": "base-sha-mismatch",
            "expectedSha256": base_sha256,
            "currentSha256": current_sha,
        }, None)

    if (
        parent_entry.get("kind") != "object"
        or not parent_entry.get("anchor_unique", False)
        or parent_entry.get("opaque_context", False)
    ):
        return ({
            "status": "unsupported",
            "reason": "signal-parent-object-not-safe",
        }, None)

    initializer_range = parent_entry.get("initializer_range")
    if (
        not isinstance(initializer_range, list)
        or len(initializer_range) != 2
        or not all(isinstance(value, int) for value in initializer_range)
    ):
        return ({
            "status": "unsupported",
            "reason": "signal-parent-has-no-initializer-range",
        }, None)
    init_start, init_end = initializer_range
    if not (
        0 <= init_start < init_end <= len(source)
        and source[init_start:init_start + 1] == b"{"
        and source[init_end - 1:init_end] == b"}"
    ):
        return ({
            "status": "error",
            "reason": "signal-parent-initializer-range-invalid",
        }, None)

    name = str(handler_name)
    if not _simple_handler_name(name):
        return ({
            "status": "unsupported",
            "reason": "handler-name-is-not-reviewed-qml-handler",
        }, None)

    expression = str(action_expression)
    if (
        not expression
        or expression != expression.strip()
        or "\n" in expression
        or "\r" in expression
        or len(expression.encode("utf-8")) > 512
    ):
        return ({
            "status": "unsupported",
            "reason": "action-expression-must-be-one-trimmed-expression",
        }, None)

    scope = parent_entry.get("scope")
    if not isinstance(scope, list) or not scope:
        return ({
            "status": "unsupported",
            "reason": "signal-parent-has-no-semantic-scope",
        }, None)

    same_scope = [
        entry for entry in semantic_entries
        if entry is not parent_entry
        and entry.get("scope") == scope
    ]
    if any(entry.get("name") == name for entry in same_scope):
        return ({
            "status": "conflict",
            "reason": "signal-handler-already-exists",
            "handlerName": name,
        }, None)

    closing_brace = init_end - 1
    closing_line_start = source.rfind(b"\n", 0, closing_brace) + 1
    closing_prefix = source[closing_line_start:closing_brace]
    if closing_prefix.strip():
        return ({
            "status": "unsupported",
            "reason": "signal-parent-closing-brace-not-standalone",
        }, None)

    member_indents = []
    for entry in same_scope:
        span = entry.get("range")
        if (
            not isinstance(span, list)
            or len(span) != 2
            or not all(isinstance(value, int) for value in span)
        ):
            continue
        member_start = span[0]
        if not (init_start < member_start < closing_line_start):
            continue
        prefix = _line_prefix(source, member_start)
        if prefix is not None:
            member_indents.append(prefix)

    unique_indents = {indent for indent in member_indents}
    if len(unique_indents) != 1:
        return ({
            "status": "unsupported",
            "reason": (
                "signal-parent-member-indentation-unresolved"
                if not unique_indents
                else "signal-parent-member-indentation-inconsistent"
            ),
        }, None)

    member_indent = next(iter(unique_indents))
    if (
        len(member_indent) <= len(closing_prefix)
        or not member_indent.startswith(closing_prefix)
    ):
        return ({
            "status": "unsupported",
            "reason": "signal-parent-member-indentation-not-nested",
        }, None)

    newline = (
        b"\r\n"
        if closing_line_start >= 2
        and source[closing_line_start - 2:closing_line_start] == b"\r\n"
        else b"\n"
    )
    inserted = (
        member_indent
        + name.encode("utf-8")
        + b": "
        + expression.encode("utf-8")
        + newline
    )
    candidate = (
        source[:closing_line_start]
        + inserted
        + source[closing_line_start:]
    )
    line = source[:closing_line_start].count(b"\n") + 1
    return ({
        "status": "candidate",
        "sourceSha256": current_sha,
        "candidateSha256": digest(candidate),
        "parentSemanticAnchor": parent_entry.get("anchor"),
        "handlerName": name,
        "actionExpression": expression,
        "patch": {
            "start": closing_line_start,
            "end": closing_line_start,
            "line": line,
            "oldText": "",
            "newText": inserted.decode("utf-8").rstrip("\r\n"),
        },
        "insertionEvidence": {
            "line": line,
            "memberIndentBytes": len(member_indent),
            "closingIndentBytes": len(closing_prefix),
            "newline": "crlf" if newline == b"\r\n" else "lf",
        },
    }, candidate)


def build_reviewed_signal_action_preview(
    root: Path,
    target_id: str,
    signal_action_target_id: str,
    grammar_path: str = "",
    tree_sitter_library: str = "",
):
    root = root.expanduser().resolve()
    target = load_reviewed_signal_action_target(
        root, target_id, signal_action_target_id
    )
    source_path = resolve_source(root, target["sourcePath"])
    source = source_path.read_bytes()
    source.decode("utf-8")
    base_sha = digest(source)

    grammar = resolve_grammar(root, grammar_path)
    if grammar is None:
        return ({
            "status": "unavailable",
            "reason": "grammar-missing",
            "applyEnabled": False,
            "artifactsStaged": False,
            "writeAuthorized": False,
        }, None)

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
            return ({
                "status": "unsupported",
                "reason": "current-source-has-parser-diagnostics",
                "diagnostics": semantic["diagnostics"],
                "applyEnabled": False,
                "artifactsStaged": False,
                "writeAuthorized": False,
            }, None)

        parent_review = resolve_reviewed_object_anchor(
            source,
            semantic["entries"],
            target["parentObjectNeedle"],
        )
        if (
            parent_review.get("status") != "resolved"
            or parent_review.get("semanticKind")
                != target["reviewedParentSemanticKind"]
        ):
            return ({
                "status": "blocked",
                "reason": "reviewed-signal-parent-not-resolved",
                "parentReview": parent_review,
                "applyEnabled": False,
                "artifactsStaged": False,
                "writeAuthorized": False,
            }, None)
        parent_anchor = str(parent_review.get("semanticAnchor", ""))
        parent_matches = [
            entry for entry in semantic["entries"]
            if entry.get("anchor") == parent_anchor
        ]
        if len(parent_matches) != 1:
            return ({
                "status": "blocked",
                "reason": "reviewed-signal-parent-not-unique",
                "applyEnabled": False,
                "artifactsStaged": False,
                "writeAuthorized": False,
            }, None)

        action_review = resolve_reviewed_anchor(
            source,
            nodes,
            semantic["entries"],
            target["actionFunctionNeedle"],
        )
        if (
            action_review.get("status") != "resolved"
            or action_review.get("semanticAnchorUnique") is not True
            or action_review.get("semanticKind")
                != target["reviewedActionSemanticKind"]
            or action_review.get("semanticName")
                != target["actionFunctionName"]
        ):
            return ({
                "status": "blocked",
                "reason": "reviewed-existing-action-not-resolved",
                "actionReview": action_review,
                "applyEnabled": False,
                "artifactsStaged": False,
                "writeAuthorized": False,
            }, None)
        action_anchor = str(action_review.get("semanticAnchor", ""))
        action_entries = [
            entry for entry in semantic["entries"]
            if entry.get("anchor") == action_anchor
        ]
        if len(action_entries) != 1:
            return ({
                "status": "blocked",
                "reason": "reviewed-existing-action-not-unique",
                "applyEnabled": False,
                "artifactsStaged": False,
                "writeAuthorized": False,
            }, None)
        action_entry = action_entries[0]
        action_range = action_entry.get("range")
        if not isinstance(action_range, list) or len(action_range) != 2:
            return ({
                "status": "blocked",
                "reason": "reviewed-existing-action-has-no-range",
                "applyEnabled": False,
                "artifactsStaged": False,
                "writeAuthorized": False,
            }, None)
        action_text = source[
            action_range[0]:action_range[1]
        ]

        prepared, candidate = prepare_signal_action_patch(
            source,
            base_sha,
            parent_matches[0],
            semantic["entries"],
            target["handlerName"],
            target["actionExpression"],
        )
        if candidate is None:
            return ({
                **prepared,
                "applyEnabled": False,
                "artifactsStaged": False,
                "writeAuthorized": False,
            }, None)

        with parser.parse(candidate) as (_, candidate_nodes):
            verify_ranges(candidate, candidate_nodes)
            candidate_semantic = extract(
                target["sourcePath"], candidate, candidate_nodes
            )
        if candidate_semantic["diagnostics"]:
            return ({
                "status": "invalid-patch",
                "reason": "candidate-has-parser-diagnostics",
                "diagnostics": candidate_semantic["diagnostics"],
                "applyEnabled": False,
                "artifactsStaged": False,
                "writeAuthorized": False,
            }, None)

        parent_rebind = resolve_semantic_anchor(
            candidate_semantic["entries"],
            parent_anchor,
            candidate,
        )
        action_rebind = resolve_semantic_anchor(
            candidate_semantic["entries"],
            action_anchor,
            candidate,
        )
        if parent_rebind.get("status") != "resolved":
            return ({
                "status": "invalid-patch",
                "reason": "signal-parent-anchor-did-not-survive",
                "semanticRebind": parent_rebind,
                "applyEnabled": False,
                "artifactsStaged": False,
                "writeAuthorized": False,
            }, None)
        if (
            action_rebind.get("status") != "resolved"
            or action_rebind.get("kind")
                != target["reviewedActionSemanticKind"]
            or action_rebind.get("name")
                != target["actionFunctionName"]
        ):
            return ({
                "status": "invalid-patch",
                "reason": "existing-action-anchor-did-not-survive",
                "actionRebind": action_rebind,
                "applyEnabled": False,
                "artifactsStaged": False,
                "writeAuthorized": False,
            }, None)

        candidate_action_entries = [
            entry for entry in candidate_semantic["entries"]
            if entry.get("anchor") == action_anchor
        ]
        if len(candidate_action_entries) != 1:
            return ({
                "status": "invalid-patch",
                "reason": "existing-action-anchor-not-unique-after-insert",
                "applyEnabled": False,
                "artifactsStaged": False,
                "writeAuthorized": False,
            }, None)
        candidate_action_range = candidate_action_entries[0].get("range")
        if (
            not isinstance(candidate_action_range, list)
            or len(candidate_action_range) != 2
            or candidate[
                candidate_action_range[0]:candidate_action_range[1]
            ] != action_text
        ):
            return ({
                "status": "invalid-patch",
                "reason": "existing-action-source-drifted",
                "applyEnabled": False,
                "artifactsStaged": False,
                "writeAuthorized": False,
            }, None)

        parent_scope = parent_matches[0].get("scope")
        handlers = [
            entry for entry in candidate_semantic["entries"]
            if entry.get("scope") == parent_scope
            and entry.get("kind") == target["insertedSemanticKind"]
            and entry.get("name") == target["handlerName"]
            and entry.get("anchor_unique", False)
            and not entry.get("opaque_context", False)
        ]
        if len(handlers) != 1:
            return ({
                "status": "invalid-patch",
                "reason": "inserted-signal-handler-not-uniquely-resolved",
                "applyEnabled": False,
                "artifactsStaged": False,
                "writeAuthorized": False,
            }, None)
        handler = handlers[0]
        if handler.get("value_kind") != target["insertedValueKind"]:
            return ({
                "status": "invalid-patch",
                "reason": "inserted-handler-value-kind-drifted",
                "valueKind": handler.get("value_kind"),
                "applyEnabled": False,
                "artifactsStaged": False,
                "writeAuthorized": False,
            }, None)
        value_range = handler.get("value_range")
        if not isinstance(value_range, list) or len(value_range) != 2:
            return ({
                "status": "invalid-patch",
                "reason": "inserted-handler-lost-value-range",
                "applyEnabled": False,
                "artifactsStaged": False,
                "writeAuthorized": False,
            }, None)
        rendered = candidate[
            value_range[0]:value_range[1]
        ].decode("utf-8")
        if rendered != target["actionExpression"]:
            return ({
                "status": "invalid-patch",
                "reason": "inserted-handler-action-expression-drifted",
                "applyEnabled": False,
                "artifactsStaged": False,
                "writeAuthorized": False,
            }, None)

        patch = prepared["patch"]
        return ({
            "status": "preview",
            "previewProof": PREVIEW_PROOF,
            "targetId": target_id,
            "signalActionTargetId": signal_action_target_id,
            "sourcePath": target["sourcePath"],
            "baseSha256": base_sha,
            "candidateSha256": prepared["candidateSha256"],
            "parentSemanticAnchor": parent_anchor,
            "existingActionSemanticAnchor": action_anchor,
            "insertedHandlerSemanticAnchor": handler.get("anchor"),
            "eventNodeId": target["eventNodeId"],
            "actionNodeId": target["actionNodeId"],
            "signalName": target["signalName"],
            "handlerName": target["handlerName"],
            "actionFunctionName": target["actionFunctionName"],
            "actionExpression": target["actionExpression"],
            "commandKind": "signal-action",
            "previewMode": "signal-action",
            "insertedSemanticKind": handler.get("kind"),
            "insertedValueKind": handler.get("value_kind"),
            "parentSemanticRebind": parent_rebind,
            "existingActionSemanticRebind": action_rebind,
            "signalResolution": "reviewed-handler-name",
            "actionResolution": "existing-function-anchor-resolved",
            "patch": patch,
            "insertionEvidence": prepared["insertionEvidence"],
            "preview": (
                f"@@ {target['sourcePath']}:{patch['line']} bytes "
                f"{patch['start']}-{patch['end']} @@\n"
                f"+ {patch['newText']}"
            ),
            "sourceWritable": os.access(source_path, os.W_OK),
            "applyEnabled": False,
            "artifactsStaged": False,
            "writeAuthorized": False,
            "productionIntegrated": False,
            "parser": {
                "qmljsVersion": QMLJS_VERSION,
                "grammar": str(grammar),
                "treeSitterLibrary": library or "system",
            },
        }, candidate)
    finally:
        if parser is not None:
            parser.close()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--root",
        default=str(Path(__file__).resolve().parents[2]),
    )
    parser.add_argument("--target-id", default="bar/media")
    parser.add_argument(
        "--signal-action-target-id",
        default=REVIEWED_TARGET_ID,
    )
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
            "writeAuthorized": False,
        }, 4)

    try:
        result, _candidate = build_reviewed_signal_action_preview(
            root,
            args.target_id,
            args.signal_action_target_id,
            args.grammar,
            args.library,
        )
    except (OSError, ValueError, UnicodeError, RuntimeError) as exc:
        return emit({
            "status": "invalid-request",
            "reason": str(exc),
            "applyEnabled": False,
            "artifactsStaged": False,
            "writeAuthorized": False,
        }, 4)

    status = str(result.get("status", "error"))
    return emit(
        result,
        0 if status == "preview"
        else 3 if status == "unavailable"
        else 6 if status == "conflict"
        else 7 if status in ("blocked", "unsupported")
        else 8,
    )


if __name__ == "__main__":
    raise SystemExit(main())
