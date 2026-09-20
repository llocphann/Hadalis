#!/usr/bin/env python3
"""Preview-only proof for inserting one absent direct QML binding.

This helper never writes source. It re-resolves a stable parent-object semantic
anchor, derives a legal insertion point from current CST/source formatting,
inserts one simple binding in memory, reparses the full candidate, and proves the
new binding appears in the same semantic scope.

Type compatibility and global cycle safety are intentionally unresolved at this
gate, so the result is never Apply-authorized.
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
from native import Parser, verify_ranges
from semantics import extract

DIRECT_BINDING_VALUE_KINDS = {"identifier", "member_expression"}


def digest(source: bytes) -> str:
    return sha256(source).hexdigest()


def emit(payload: dict, exit_code: int) -> int:
    print(json.dumps({"protocol": PROTOCOL, **payload}, ensure_ascii=False))
    return exit_code


def _simple_qml_name(name: str) -> bool:
    if not name:
        return False
    first = name[0]
    if not (first == "_" or "A" <= first <= "Z" or "a" <= first <= "z"):
        return False
    return all(
        ch == "_" or "0" <= ch <= "9"
        or "A" <= ch <= "Z" or "a" <= ch <= "z"
        for ch in name[1:]
    )


def _line_prefix(source: bytes, position: int):
    line_start = source.rfind(b"\n", 0, position) + 1
    prefix = source[line_start:position]
    if prefix.strip():
        return None
    return prefix


def prepare_connect_binding_patch(
    source: bytes,
    base_sha256: str,
    parent_entry: dict,
    semantic_entries: list[dict],
    binding_name: str,
    expression: str,
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
        parent_entry.get("kind") not in {"object", "component"}
        or not parent_entry.get("anchor_unique", False)
        or parent_entry.get("opaque_context", False)
    ):
        return ({
            "status": "unsupported",
            "reason": "parent-object-not-safe-for-binding-insertion",
        }, None)

    initializer_range = parent_entry.get("initializer_range")
    if (
        not isinstance(initializer_range, list)
        or len(initializer_range) != 2
        or not all(isinstance(value, int) for value in initializer_range)
    ):
        return ({
            "status": "unsupported",
            "reason": "parent-object-has-no-initializer-range",
        }, None)

    init_start, init_end = initializer_range
    if not (
        0 <= init_start < init_end <= len(source)
        and source[init_start:init_start + 1] == b"{"
        and source[init_end - 1:init_end] == b"}"
    ):
        return ({
            "status": "error",
            "reason": "parent-initializer-range-invalid",
        }, None)

    name = str(binding_name)
    if not _simple_qml_name(name):
        return ({
            "status": "unsupported",
            "reason": "binding-name-must-be-simple-qml-identifier",
        }, None)

    next_expression = str(expression)
    if (
        not next_expression
        or next_expression != next_expression.strip()
        or "\n" in next_expression
        or "\r" in next_expression
        or len(next_expression.encode("utf-8")) > 512
    ):
        return ({
            "status": "unsupported",
            "reason": "expression-must-be-one-trimmed-direct-binding",
        }, None)

    scope = parent_entry.get("scope")
    if not isinstance(scope, list) or not scope:
        return ({
            "status": "unsupported",
            "reason": "parent-object-has-no-semantic-scope",
        }, None)

    same_scope = [
        entry for entry in semantic_entries
        if entry is not parent_entry
        and entry.get("scope") == scope
    ]
    if any(entry.get("name") == name for entry in same_scope):
        return ({
            "status": "conflict",
            "reason": "target-member-already-exists",
            "bindingName": name,
        }, None)

    closing_brace = init_end - 1
    closing_line_start = source.rfind(b"\n", 0, closing_brace) + 1
    closing_prefix = source[closing_line_start:closing_brace]
    if closing_prefix.strip():
        return ({
            "status": "unsupported",
            "reason": "parent-closing-brace-not-on-standalone-line",
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
                "parent-member-indentation-unresolved"
                if not unique_indents
                else "parent-member-indentation-inconsistent"
            ),
        }, None)

    member_indent = next(iter(unique_indents))
    if (
        len(member_indent) <= len(closing_prefix)
        or not member_indent.startswith(closing_prefix)
    ):
        return ({
            "status": "unsupported",
            "reason": "parent-member-indentation-not-nested",
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
        + next_expression.encode("utf-8")
        + newline
    )
    candidate = source[:closing_line_start] + inserted + source[closing_line_start:]
    line = source[:closing_line_start].count(b"\n") + 1
    return ({
        "status": "candidate",
        "sourceSha256": current_sha,
        "candidateSha256": digest(candidate),
        "parentSemanticAnchor": parent_entry.get("anchor"),
        "bindingName": name,
        "expression": next_expression,
        "insertionEvidence": {
            "line": line,
            "memberIndentBytes": len(member_indent),
            "closingIndentBytes": len(closing_prefix),
            "newline": "crlf" if newline == b"\r\n" else "lf",
        },
        "patch": {
            "start": closing_line_start,
            "end": closing_line_start,
            "line": line,
            "oldText": "",
            "newText": inserted.decode("utf-8").rstrip("\r\n"),
        },
    }, candidate)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default=str(Path(__file__).resolve().parents[2]))
    parser.add_argument("--path", required=True)
    parser.add_argument("--base-sha256", required=True)
    parser.add_argument("--parent-semantic-anchor", required=True)
    parser.add_argument("--binding-name", required=True)
    parser.add_argument("--expression", required=True)
    parser.add_argument("--grammar", default="")
    parser.add_argument("--library", default="")
    args = parser.parse_args()

    root = Path(args.root).expanduser().resolve()
    if not root.is_dir():
        return emit({"status": "invalid-request", "reason": "runtime-root-missing"}, 4)

    try:
        source_path = resolve_source(root, args.path)
        source = source_path.read_bytes()
        source.decode("utf-8")
    except (ValueError, OSError, UnicodeError) as exc:
        return emit({"status": "invalid-request", "reason": str(exc)}, 4)

    if digest(source) != args.base_sha256:
        return emit({
            "status": "conflict",
            "reason": "base-sha-mismatch",
            "expectedSha256": args.base_sha256,
            "currentSha256": digest(source),
        }, 6)

    grammar = resolve_grammar(root, args.grammar)
    if grammar is None:
        return emit({"status": "unavailable", "reason": "grammar-missing"}, 3)

    library = (
        args.library
        or os.environ.get("HADALIS_TREE_SITTER_LIBRARY", "")
        or None
    )

    native_parser = None
    try:
        native_parser = Parser(grammar, library)
        with native_parser.parse(source) as (_, nodes):
            verify_ranges(source, nodes)
            semantic = extract(args.path, source, nodes)

        if semantic["diagnostics"]:
            return emit({
                "status": "unsupported",
                "reason": "current-source-has-parser-diagnostics",
                "diagnostics": semantic["diagnostics"],
            }, 7)

        parent_rebind = resolve_semantic_anchor(
            semantic["entries"],
            args.parent_semantic_anchor,
        )
        if parent_rebind.get("status") != "resolved":
            return emit({
                "status": "conflict",
                "reason": "parent-semantic-anchor-" + str(
                    parent_rebind.get("status", "unknown")),
                "semanticRebind": parent_rebind,
            }, 6)

        parent_matches = [
            entry for entry in semantic["entries"]
            if entry.get("anchor") == args.parent_semantic_anchor
        ]
        if len(parent_matches) != 1:
            return emit({
                "status": "conflict",
                "reason": "parent-semantic-anchor-not-unique",
            }, 6)

        prepared, candidate = prepare_connect_binding_patch(
            source,
            args.base_sha256,
            parent_matches[0],
            semantic["entries"],
            args.binding_name,
            args.expression,
        )
        if candidate is None:
            status = prepared.get("status")
            return emit(
                prepared,
                6 if status == "conflict"
                else 7 if status == "unsupported"
                else 8,
            )

        with native_parser.parse(candidate) as (_, candidate_nodes):
            verify_ranges(candidate, candidate_nodes)
            candidate_semantic = extract(args.path, candidate, candidate_nodes)

        if candidate_semantic["diagnostics"]:
            return emit({
                "status": "invalid-patch",
                "reason": "candidate-has-parser-diagnostics",
                "diagnostics": candidate_semantic["diagnostics"],
            }, 8)

        rebound_parent = resolve_semantic_anchor(
            candidate_semantic["entries"],
            args.parent_semantic_anchor,
        )
        if rebound_parent.get("status") != "resolved":
            return emit({
                "status": "invalid-patch",
                "reason": "parent-semantic-anchor-did-not-survive-candidate",
                "semanticRebind": rebound_parent,
            }, 8)

        parent_scope = parent_matches[0].get("scope")
        new_bindings = [
            entry for entry in candidate_semantic["entries"]
            if entry.get("kind") == "binding"
            and entry.get("name") == args.binding_name
            and entry.get("scope") == parent_scope
            and entry.get("anchor_unique", False)
            and not entry.get("opaque_context", False)
        ]
        if len(new_bindings) != 1:
            return emit({
                "status": "invalid-patch",
                "reason": "inserted-binding-not-uniquely-resolved",
            }, 8)

        inserted = new_bindings[0]
        if inserted.get("value_kind") not in DIRECT_BINDING_VALUE_KINDS:
            return emit({
                "status": "invalid-patch",
                "reason": "inserted-binding-left-direct-binding-subset",
                "valueKind": inserted.get("value_kind"),
            }, 8)

        value_range = inserted.get("value_range")
        if not isinstance(value_range, list) or len(value_range) != 2:
            return emit({
                "status": "invalid-patch",
                "reason": "inserted-binding-lost-value-range",
            }, 8)
        rendered = candidate[value_range[0]:value_range[1]].decode("utf-8")
        if rendered != args.expression:
            return emit({
                "status": "invalid-patch",
                "reason": "inserted-binding-value-does-not-match-expression",
            }, 8)

        patch = prepared["patch"]
        preview = (
            f"@@ {args.path}:{patch['line']} bytes "
            f"{patch['start']}-{patch['end']} @@\n"
            f"+ {patch['newText']}"
        )
        return emit({
            "status": "preview",
            "sourcePath": args.path,
            "baseSha256": prepared["sourceSha256"],
            "candidateSha256": prepared["candidateSha256"],
            "parentSemanticAnchor": args.parent_semantic_anchor,
            "insertedSemanticAnchor": inserted.get("anchor"),
            "bindingName": args.binding_name,
            "expression": args.expression,
            "commandKind": "connect-binding",
            "previewMode": "connect",
            "semanticRebind": rebound_parent,
            "insertedSemanticKind": inserted.get("kind"),
            "insertedValueKind": inserted.get("value_kind"),
            "insertionEvidence": prepared["insertionEvidence"],
            "cycleStatus": "unknown-incomplete-projection",
            "typeCompatibility": "unknown-unresolved",
            "patch": patch,
            "preview": preview,
            "sourceWritable": os.access(source_path, os.W_OK),
            "applyEnabled": False,
            "parser": {
                "qmljsVersion": QMLJS_VERSION,
                "grammar": str(grammar),
                "treeSitterLibrary": library or "system",
            },
        }, 0)
    except OSError as exc:
        return emit({
            "status": "unavailable",
            "reason": "tree-sitter-library-missing",
            "detail": str(exc),
        }, 3)
    except (RuntimeError, AssertionError, UnicodeError) as exc:
        return emit({
            "status": "error",
            "reason": "connect-preview-failed",
            "detail": str(exc),
        }, 8)
    finally:
        if native_parser is not None:
            native_parser.close()


if __name__ == "__main__":
    raise SystemExit(main())
