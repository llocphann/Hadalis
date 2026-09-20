#!/usr/bin/env python3
"""Dry-run Code Workflow source transaction preview.

This helper performs no file write. It re-resolves a unique semantic anchor,
checks the analyzer base SHA, replaces exactly one literal property value range
in memory, reparses the candidate, and emits a minimal patch preview.
"""

from __future__ import annotations

import argparse
from hashlib import sha256
import json
import os
from pathlib import Path

from analyze import (
    QMLJS_VERSION,
    resolve_grammar,
    resolve_semantic_anchor,
    resolve_source,
)
from native import Parser, verify_ranges
from semantics import extract


PROTOCOL = 1
LITERAL_VALUE_KINDS = {"true", "false", "number", "string"}
DIRECT_BINDING_VALUE_KINDS = {"identifier", "member_expression"}


def digest(source: bytes) -> str:
    return sha256(source).hexdigest()


def emit(payload: dict, exit_code: int) -> int:
    print(json.dumps({"protocol": PROTOCOL, **payload}, ensure_ascii=False))
    return exit_code


def prepare_literal_patch(
    source: bytes,
    base_sha256: str,
    entry: dict,
    replacement: str,
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
        entry.get("kind") != "property"
        or not entry.get("anchor_unique", False)
        or entry.get("opaque_context", False)
    ):
        return ({
            "status": "unsupported",
            "reason": "semantic-entry-not-safe-literal-property",
        }, None)

    value_kind = entry.get("value_kind")
    if value_kind not in LITERAL_VALUE_KINDS:
        return ({
            "status": "unsupported",
            "reason": "current-value-is-not-supported-literal",
            "valueKind": value_kind,
        }, None)

    value_range = entry.get("value_range")
    if (
        not isinstance(value_range, list)
        or len(value_range) != 2
        or not all(isinstance(value, int) for value in value_range)
    ):
        return ({
            "status": "unsupported",
            "reason": "semantic-entry-has-no-value-range",
        }, None)

    start, end = value_range
    if not (0 <= start <= end <= len(source)):
        return ({
            "status": "error",
            "reason": "semantic-value-range-out-of-bounds",
        }, None)

    next_value = str(replacement)
    if (
        not next_value
        or next_value != next_value.strip()
        or "\n" in next_value
        or "\r" in next_value
        or len(next_value.encode("utf-8")) > 512
    ):
        return ({
            "status": "unsupported",
            "reason": "replacement-must-be-one-trimmed-literal-expression",
        }, None)

    replacement_bytes = next_value.encode("utf-8")
    old_bytes = source[start:end]
    candidate = source[:start] + replacement_bytes + source[end:]
    line = source[:start].count(b"\n") + 1

    return ({
        "status": "candidate",
        "sourceSha256": current_sha,
        "candidateSha256": digest(candidate),
        "patch": {
            "start": start,
            "end": end,
            "line": line,
            "oldText": old_bytes.decode("utf-8"),
            "newText": next_value,
        },
    }, candidate)


def prepare_binding_patch(
    source: bytes,
    base_sha256: str,
    entry: dict,
    replacement: str,
):
    """Prepare a dry-run direct QML binding patch.

    This subset is intentionally preview-only. It accepts only a semantic
    ui_binding projected as kind=binding whose current value is a plain
    identifier or member_expression. No call/binary/conditional/script body is
    admitted here.
    """
    current_sha = digest(source)
    if current_sha != base_sha256:
        return ({
            "status": "conflict",
            "reason": "base-sha-mismatch",
            "expectedSha256": base_sha256,
            "currentSha256": current_sha,
        }, None)

    if (
        entry.get("kind") != "binding"
        or not entry.get("anchor_unique", False)
        or entry.get("opaque_context", False)
    ):
        return ({
            "status": "unsupported",
            "reason": "semantic-entry-not-safe-direct-binding",
        }, None)

    value_kind = entry.get("value_kind")
    if value_kind not in DIRECT_BINDING_VALUE_KINDS:
        return ({
            "status": "unsupported",
            "reason": "current-value-is-not-supported-direct-binding",
            "valueKind": value_kind,
        }, None)

    value_range = entry.get("value_range")
    if (
        not isinstance(value_range, list)
        or len(value_range) != 2
        or not all(isinstance(value, int) for value in value_range)
    ):
        return ({
            "status": "unsupported",
            "reason": "semantic-entry-has-no-value-range",
        }, None)

    start, end = value_range
    if not (0 <= start <= end <= len(source)):
        return ({
            "status": "error",
            "reason": "semantic-value-range-out-of-bounds",
        }, None)

    next_value = str(replacement)
    if (
        not next_value
        or next_value != next_value.strip()
        or "\n" in next_value
        or "\r" in next_value
        or len(next_value.encode("utf-8")) > 512
    ):
        return ({
            "status": "unsupported",
            "reason": "replacement-must-be-one-trimmed-binding-expression",
        }, None)

    replacement_bytes = next_value.encode("utf-8")
    old_bytes = source[start:end]
    candidate = source[:start] + replacement_bytes + source[end:]
    line = source[:start].count(b"\n") + 1

    return ({
        "status": "candidate",
        "sourceSha256": current_sha,
        "candidateSha256": digest(candidate),
        "patch": {
            "start": start,
            "end": end,
            "line": line,
            "oldText": old_bytes.decode("utf-8"),
            "newText": next_value,
        },
    }, candidate)


def prepare_disconnect_binding_patch(
    source: bytes,
    base_sha256: str,
    entry: dict,
    expected_current: str,
):
    """Prepare a preview-only deletion of one standalone direct QML binding."""
    current_sha = digest(source)
    if current_sha != base_sha256:
        return ({
            "status": "conflict",
            "reason": "base-sha-mismatch",
            "expectedSha256": base_sha256,
            "currentSha256": current_sha,
        }, None)

    if (
        entry.get("kind") != "binding"
        or not entry.get("anchor_unique", False)
        or entry.get("opaque_context", False)
        or entry.get("value_kind") not in DIRECT_BINDING_VALUE_KINDS
    ):
        return ({
            "status": "unsupported",
            "reason": "semantic-entry-not-safe-disconnect-binding",
        }, None)

    value_range = entry.get("value_range")
    member_range = entry.get("range")
    if (
        not isinstance(value_range, list)
        or len(value_range) != 2
        or not isinstance(member_range, list)
        or len(member_range) != 2
        or not all(isinstance(value, int) for value in value_range + member_range)
    ):
        return ({
            "status": "unsupported",
            "reason": "semantic-entry-has-no-member-range",
        }, None)

    value_start, value_end = value_range
    member_start, member_end = member_range
    if not (
        0 <= member_start <= value_start <= value_end <= member_end <= len(source)
    ):
        return ({
            "status": "error",
            "reason": "semantic-member-range-out-of-bounds",
        }, None)

    current_value = source[value_start:value_end].decode("utf-8")
    if current_value != str(expected_current):
        return ({
            "status": "conflict",
            "reason": "reviewed-edge-source-expression-drift",
            "expectedCurrent": str(expected_current),
            "currentValue": current_value,
        }, None)

    line_start = source.rfind(b"\n", 0, member_start) + 1
    newline = source.find(b"\n", member_end)
    line_end = len(source) if newline < 0 else newline + 1
    before = source[line_start:member_start]
    after_end = newline if newline >= 0 else line_end
    after = source[member_end:after_end]
    if before.strip() or after.strip():
        return ({
            "status": "unsupported",
            "reason": "binding-member-is-not-standalone-line",
        }, None)

    old_bytes = source[line_start:line_end]
    candidate = source[:line_start] + source[line_end:]
    line = source[:line_start].count(b"\n") + 1
    return ({
        "status": "candidate",
        "sourceSha256": current_sha,
        "candidateSha256": digest(candidate),
        "expectedCurrent": current_value,
        "resultingState": "unbound/default",
        "patch": {
            "start": line_start,
            "end": line_end,
            "line": line,
            "oldText": old_bytes.decode("utf-8").rstrip("\n"),
            "newText": "",
        },
    }, candidate)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default=str(Path(__file__).resolve().parents[2]))
    parser.add_argument("--path", required=True)
    parser.add_argument("--base-sha256", required=True)
    parser.add_argument("--semantic-anchor", required=True)
    parser.add_argument("--replacement", default="")
    parser.add_argument("--expected-current", default="")
    parser.add_argument(
        "--mode",
        choices=("literal", "binding", "disconnect"),
        default="literal",
    )
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
        return emit({
            "status": "invalid-request",
            "reason": str(exc),
        }, 4)

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
            current_semantic = extract(args.path, source, nodes)

        if current_semantic["diagnostics"]:
            return emit({
                "status": "unsupported",
                "reason": "current-source-has-parser-diagnostics",
                "diagnostics": current_semantic["diagnostics"],
            }, 7)

        rebind = resolve_semantic_anchor(
            current_semantic["entries"],
            args.semantic_anchor,
        )
        if rebind.get("status") != "resolved":
            return emit({
                "status": "conflict",
                "reason": "semantic-anchor-" + str(rebind.get("status", "unknown")),
                "semanticRebind": rebind,
            }, 6)

        matches = [
            entry for entry in current_semantic["entries"]
            if entry.get("anchor") == args.semantic_anchor
        ]
        if len(matches) != 1:
            return emit({
                "status": "conflict",
                "reason": "semantic-anchor-not-unique",
            }, 6)

        if args.mode == "disconnect":
            prepared, candidate = prepare_disconnect_binding_patch(
                source,
                args.base_sha256,
                matches[0],
                args.expected_current,
            )
            command_kind = "disconnect-binding"
        elif args.mode == "binding":
            prepared, candidate = prepare_binding_patch(
                source,
                args.base_sha256,
                matches[0],
                args.replacement,
            )
            command_kind = "direct-binding"
        else:
            prepared, candidate = prepare_literal_patch(
                source,
                args.base_sha256,
                matches[0],
                args.replacement,
            )
            command_kind = "literal-property"
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
            candidate_semantic = extract(
                args.path,
                candidate,
                candidate_nodes,
            )

        if candidate_semantic["diagnostics"]:
            return emit({
                "status": "invalid-patch",
                "reason": "candidate-has-parser-diagnostics",
                "diagnostics": candidate_semantic["diagnostics"],
            }, 8)

        rebound = resolve_semantic_anchor(
            candidate_semantic["entries"],
            args.semantic_anchor,
        )
        if args.mode == "disconnect":
            if rebound.get("status") != "missing":
                return emit({
                    "status": "invalid-patch",
                    "reason": "disconnected-semantic-anchor-still-resolves",
                    "semanticRebind": rebound,
                }, 8)
            candidate_entry = None
        else:
            if rebound.get("status") != "resolved":
                return emit({
                    "status": "invalid-patch",
                    "reason": "semantic-anchor-did-not-survive-candidate",
                    "semanticRebind": rebound,
                }, 8)
            candidate_entry = next(
                entry for entry in candidate_semantic["entries"]
                if entry.get("anchor") == args.semantic_anchor
            )

        if args.mode == "disconnect":
            candidate_safe = True
            candidate_reason = ""
        elif args.mode == "binding":
            candidate_safe = (
                candidate_entry.get("kind") == "binding"
                and not candidate_entry.get("opaque_context", False)
                and candidate_entry.get("value_kind")
                    in DIRECT_BINDING_VALUE_KINDS
            )
            candidate_reason = "candidate-left-direct-binding-subset"
        else:
            candidate_safe = (
                candidate_entry.get("kind") == "property"
                and not candidate_entry.get("opaque_context", False)
                and candidate_entry.get("value_kind")
                    in LITERAL_VALUE_KINDS
            )
            candidate_reason = "candidate-left-literal-property-subset"
        if not candidate_safe:
            return emit({
                "status": "invalid-patch",
                "reason": candidate_reason,
            }, 8)

        if args.mode != "disconnect":
            value_range = candidate_entry.get("value_range")
            if not isinstance(value_range, list) or len(value_range) != 2:
                return emit({
                    "status": "invalid-patch",
                    "reason": "candidate-lost-value-range",
                }, 8)
            rendered = candidate[value_range[0]:value_range[1]].decode("utf-8")
            if rendered != args.replacement:
                return emit({
                    "status": "invalid-patch",
                    "reason": "candidate-value-range-does-not-match-replacement",
                }, 8)

        patch = prepared["patch"]
        preview = (
            f"@@ {args.path}:{patch['line']} bytes "
            f"{patch['start']}-{patch['end']} @@\n"
            f"- {patch['oldText']}\n"
            f"+ {patch['newText']}"
        )
        return emit({
            "status": "preview",
            "sourcePath": args.path,
            "baseSha256": prepared["sourceSha256"],
            "candidateSha256": prepared["candidateSha256"],
            "semanticAnchor": args.semantic_anchor,
            "semanticRebind": rebound,
            "commandKind": command_kind,
            "previewMode": args.mode,
            "expectedCurrent": prepared.get("expectedCurrent", ""),
            "resultingState": prepared.get("resultingState", ""),
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
            "reason": "preview-failed",
            "detail": str(exc),
        }, 8)
    finally:
        if native_parser is not None:
            native_parser.close()


if __name__ == "__main__":
    raise SystemExit(main())
