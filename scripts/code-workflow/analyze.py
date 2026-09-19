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
        "parser": {
            "grammar": str(grammar),
            "qmljsVersion": QMLJS_VERSION,
            "treeSitterLibrary": library or "system",
        },
        "editable": False,
    }, 0)


if __name__ == "__main__":
    raise SystemExit(main())
