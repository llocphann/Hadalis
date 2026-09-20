#!/usr/bin/env python3
"""Read-only Code Workflow parser protocol.

The helper analyzes exactly one QML file beneath the active Hadalis runtime root.
It never downloads/builds dependencies and never writes source. Native parser
capability is optional: callers receive a structured unavailable result when the
grammar or Tree-sitter shared library is missing.
"""

from __future__ import annotations

import argparse
from hashlib import sha256
import json
import os
from pathlib import Path
import sys

from native import Parser, verify_ranges
from semantics import extract


PROTOCOL = 1
DEFAULT_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_GRAMMAR = Path("assets/code-workflow/qmljs.so")
SYSTEM_GRAMMAR = Path("/usr/lib/inir/code-workflow/qmljs.so")
QMLJS_VERSION = "0.3.1"


def emit(payload: dict, exit_code: int) -> int:
    print(json.dumps({"protocol": PROTOCOL, **payload}, ensure_ascii=False))
    return exit_code


def invalid(reason: str) -> int:
    return emit({"status": "invalid-request", "reason": reason}, 4)


def unavailable(reason: str, detail: str = "") -> int:
    payload = {"status": "unavailable", "reason": reason}
    if detail:
        payload["detail"] = detail
    return emit(payload, 3)


def resolve_grammar(root: Path, explicit: str) -> Path | None:
    if explicit:
        candidate = Path(explicit).expanduser().resolve()
        return candidate if candidate.is_file() else None

    env_value = os.environ.get("HADALIS_WORKFLOW_GRAMMAR", "")
    if env_value:
        candidate = Path(env_value).expanduser().resolve()
        return candidate if candidate.is_file() else None

    for candidate in ((root / DEFAULT_GRAMMAR).resolve(), SYSTEM_GRAMMAR):
        if candidate.is_file():
            return candidate
    return None


def _byte_point(source: bytes, offset: int) -> list[int]:
    prefix = source[:offset]
    return [prefix.count(b"\n"), len(prefix.rsplit(b"\n", 1)[-1])]


def resolve_reviewed_anchor(
    source: bytes,
    nodes,
    entries: list[dict],
    needle: str,
) -> dict:
    if not needle:
        return {"status": "not-requested", "occurrences": 0}

    target = needle.encode("utf-8")
    starts = []
    cursor = 0
    while True:
        found = source.find(target, cursor)
        if found < 0:
            break
        starts.append(found)
        cursor = found + max(1, len(target))

    if len(starts) == 0:
        return {"status": "missing", "occurrences": 0}
    if len(starts) != 1:
        return {"status": "ambiguous", "occurrences": len(starts)}

    start = starts[0]
    end = start + len(target)

    cst_candidates = [
        node for node in nodes
        if node.named
        and not node.error
        and not node.missing
        and node.start <= start
        and end <= node.end
    ]
    cst_node = min(
        cst_candidates,
        key=lambda node: (node.end - node.start, node.start, node.kind),
        default=None,
    )

    semantic_candidates = []
    for entry in entries:
        span = entry.get("range")
        if (
            isinstance(span, list)
            and len(span) == 2
            and span[0] <= start
            and end <= span[1]
        ):
            semantic_candidates.append(entry)
    semantic_entry = min(
        semantic_candidates,
        key=lambda entry: (
            entry["range"][1] - entry["range"][0],
            entry["range"][0],
            entry.get("anchor", ""),
        ),
        default=None,
    )

    result = {
        "status": "resolved",
        "occurrences": 1,
        "needleRange": [start, end],
        "needleStartPoint": _byte_point(source, start),
        "needleEndPoint": _byte_point(source, end),
    }
    if cst_node is not None:
        result["cstKind"] = cst_node.kind
        result["cstRange"] = [cst_node.start, cst_node.end]
        result["cstStartPoint"] = list(cst_node.start_point)
        result["cstEndPoint"] = list(cst_node.end_point)
    if semantic_entry is not None:
        result["semanticAnchor"] = semantic_entry.get("anchor", "")
        result["semanticAnchorUnique"] = bool(
            semantic_entry.get("anchor_unique", False))
        result["semanticKind"] = semantic_entry.get("kind", "")
        result["semanticName"] = semantic_entry.get("name", "")
        result["semanticRange"] = semantic_entry.get("range")
        value_range = semantic_entry.get("value_range")
        result["semanticValueRange"] = value_range
        result["semanticValueKind"] = semantic_entry.get("value_kind")
        if (
            isinstance(value_range, list)
            and len(value_range) == 2
            and 0 <= value_range[0] <= value_range[1] <= len(source)
        ):
            result["semanticValueText"] = source[
                value_range[0]:value_range[1]
            ].decode("utf-8")
        result["semanticDeclaredType"] = semantic_entry.get(
            "declared_type", "")
    return result


def resolve_reviewed_object_anchor(
    source: bytes,
    entries: list[dict],
    needle: str,
) -> dict:
    if not needle:
        return {"status": "not-requested", "occurrences": 0}

    target = needle.encode("utf-8")
    starts = []
    cursor = 0
    while True:
        found = source.find(target, cursor)
        if found < 0:
            break
        starts.append(found)
        cursor = found + max(1, len(target))

    if not starts:
        return {"status": "missing", "occurrences": 0}
    if len(starts) != 1:
        return {"status": "ambiguous", "occurrences": len(starts)}

    start = starts[0]
    end = start + len(target)
    candidates = []
    for entry in entries:
        span = entry.get("range")
        if (
            entry.get("kind") == "object"
            and isinstance(span, list)
            and len(span) == 2
            and span[0] <= start
            and end <= span[1]
        ):
            candidates.append(entry)

    if not candidates:
        return {
            "status": "unresolved",
            "occurrences": 1,
            "reason": "needle-is-not-contained-by-reviewed-object",
        }

    entry = min(
        candidates,
        key=lambda item: (
            item["range"][1] - item["range"][0],
            item["range"][0],
            item.get("anchor", ""),
        ),
    )
    if not entry.get("anchor_unique", False) or entry.get("opaque_context", False):
        return {
            "status": "ambiguous",
            "occurrences": 1,
            "semanticAnchor": entry.get("anchor", ""),
        }

    return {
        "status": "resolved",
        "occurrences": 1,
        "needleRange": [start, end],
        "semanticAnchor": entry.get("anchor", ""),
        "semanticAnchorUnique": True,
        "semanticKind": entry.get("kind", ""),
        "semanticName": entry.get("name", ""),
        "semanticRange": entry.get("range"),
        "initializerRange": entry.get("initializer_range"),
        "scope": entry.get("scope", []),
        "opaqueContext": False,
    }


def resolve_semantic_anchor(entries: list[dict], anchor: str) -> dict:
    if not anchor:
        return {"status": "not-requested"}

    matches = [
        entry for entry in entries
        if entry.get("anchor") == anchor
    ]
    if len(matches) == 0:
        return {"status": "missing", "anchor": anchor}
    if len(matches) != 1 or not matches[0].get("anchor_unique", False):
        return {
            "status": "ambiguous",
            "anchor": anchor,
            "occurrences": len(matches),
        }

    entry = matches[0]
    return {
        "status": "resolved",
        "anchor": anchor,
        "kind": entry.get("kind", ""),
        "name": entry.get("name", ""),
        "range": entry.get("range"),
        "parentRange": entry.get("parent_range"),
        "scope": entry.get("scope", []),
        "opaqueContext": bool(entry.get("opaque_context", False)),
        "editable": False,
    }


def resolve_source(root: Path, relative: str) -> Path:
    request = Path(relative)
    if request.is_absolute():
        raise ValueError("source path must be runtime-relative")
    candidate = (root / request).resolve()
    try:
        candidate.relative_to(root)
    except ValueError as exc:
        raise ValueError("source path escapes runtime root") from exc
    if candidate.suffix != ".qml":
        raise ValueError("source path must name a .qml file")
    if not candidate.is_file():
        raise ValueError("source file does not exist")
    return candidate


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default=str(DEFAULT_ROOT))
    parser.add_argument("--path", required=True, help="QML path relative to --root")
    parser.add_argument("--grammar", default="")
    parser.add_argument("--library", default="")
    parser.add_argument(
        "--needle",
        default="",
        help="reviewed source needle to resolve to transient CST evidence",
    )
    parser.add_argument(
        "--semantic-anchor",
        default="",
        help="stable semantic anchor to re-resolve after source movement",
    )
    parser.add_argument(
        "--object-needle",
        default="",
        help="reviewed unique needle used only to resolve a containing object",
    )
    args = parser.parse_args()

    root = Path(args.root).expanduser().resolve()
    if not root.is_dir():
        return invalid("runtime root does not exist")

    try:
        source_path = resolve_source(root, args.path)
    except ValueError as exc:
        return invalid(str(exc))

    grammar = resolve_grammar(root, args.grammar)
    if grammar is None:
        return unavailable("grammar-missing")

    library = (
        args.library
        or os.environ.get("HADALIS_TREE_SITTER_LIBRARY", "")
        or None
    )

    try:
        source = source_path.read_bytes()
        source.decode("utf-8")
    except (OSError, UnicodeError) as exc:
        return invalid(f"source-read-failed: {exc}")

    native_parser = None
    try:
        native_parser = Parser(grammar, library)
        with native_parser.parse(source) as (_, nodes):
            preservation = verify_ranges(source, nodes)
            semantic = extract(args.path, source, nodes)
            reviewed_anchor = resolve_reviewed_anchor(
                source,
                nodes,
                semantic["entries"],
                args.needle,
            )
            semantic_rebind = resolve_semantic_anchor(
                semantic["entries"],
                args.semantic_anchor,
            )
            reviewed_object_anchor = resolve_reviewed_object_anchor(
                source,
                semantic["entries"],
                args.object_needle,
            )
    except OSError as exc:
        return unavailable("tree-sitter-library-missing", str(exc))
    except (RuntimeError, AssertionError, UnicodeError) as exc:
        return emit({
            "status": "error",
            "reason": "parse-failed",
            "detail": str(exc),
            "sourcePath": args.path,
            "sourceSha256": sha256(source).hexdigest(),
        }, 5)
    finally:
        if native_parser is not None:
            native_parser.close()

    return emit({
        "status": "ok",
        "sourcePath": args.path,
        "sourceSha256": sha256(source).hexdigest(),
        "bytes": len(source),
        "preservation": preservation,
        "entries": semantic["entries"],
        "diagnostics": semantic["diagnostics"],
        "counts": semantic["counts"],
        "anchorCollisions": semantic["anchor_collisions"],
        "reviewedAnchor": reviewed_anchor,
        "reviewedObjectAnchor": reviewed_object_anchor,
        "semanticRebind": semantic_rebind,
        "parser": {
            "grammar": str(grammar),
            "qmljsVersion": QMLJS_VERSION,
            "treeSitterLibrary": library or "system",
        },
        "editable": False,
    }, 0)


if __name__ == "__main__":
    raise SystemExit(main())
