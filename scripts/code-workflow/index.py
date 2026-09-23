#!/usr/bin/env python3
"""Cached whole-tree read-only runtime-boundary index for Code Workflow.

This helper scans QML beneath the active Hadalis runtime root, reuses semantic
results for byte-identical files, and emits only parser evidence about runtime
boundaries. It never mutates QML and does not promote parser evidence to live
runtime identity or mutation authority.
"""

from __future__ import annotations

import argparse
from collections import Counter
from hashlib import sha256
import json
import os
from pathlib import Path
import sys

from analyze import DEFAULT_ROOT, QMLJS_VERSION, resolve_grammar
from native import Parser, verify_ranges
from semantics import extract


PROTOCOL = 1
CACHE_SCHEMA = 1
SKIP_DIRS = {
    ".git",
    ".direnv",
    ".venv",
    "__pycache__",
    "build",
    "dist",
    "node_modules",
    "result",
}


def emit(payload: dict, exit_code: int = 0) -> int:
    print(json.dumps({"protocol": PROTOCOL, **payload}, ensure_ascii=False))
    return exit_code


def unavailable(reason: str, detail: str = "") -> int:
    payload = {"status": "unavailable", "reason": reason}
    if detail:
        payload["detail"] = detail
    return emit(payload, 3)


def default_cache_path() -> Path:
    cache_home = Path(
        os.environ.get("XDG_CACHE_HOME")
        or (Path.home() / ".cache")
    )
    return cache_home / "inir" / "code-workflow-runtime-boundaries-v1.json"


def discover_qml(root: Path) -> list[Path]:
    discovered = []
    for current, dirnames, filenames in os.walk(root, followlinks=False):
        dirnames[:] = sorted(
            name for name in dirnames
            if name not in SKIP_DIRS
        )
        current_path = Path(current)
        for filename in sorted(filenames):
            if not filename.endswith(".qml"):
                continue
            candidate = (current_path / filename).resolve()
            try:
                candidate.relative_to(root)
            except ValueError:
                continue
            if candidate.is_file():
                discovered.append(candidate)
    return sorted(discovered, key=lambda path: path.relative_to(root).as_posix())


def load_cache(path: Path, parser_signature: dict) -> dict:
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError, UnicodeError):
        return {"files": {}}
    if (
        payload.get("schema") != CACHE_SCHEMA
        or payload.get("parserSignature") != parser_signature
        or not isinstance(payload.get("files"), dict)
    ):
        return {"files": {}}
    return payload


def write_cache(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(
        path.name + ".tmp-" + str(os.getpid())
    )
    data = json.dumps(payload, ensure_ascii=False, sort_keys=True)
    try:
        temporary.write_text(data, encoding="utf-8")
        os.replace(temporary, path)
    finally:
        try:
            temporary.unlink()
        except FileNotFoundError:
            pass


def boundary_projection(path: str, source_sha: str, entry: dict) -> dict:
    return {
        "sourcePath": path,
        "sourceSha256": source_sha,
        "anchor": str(entry.get("anchor") or ""),
        "kind": str(entry.get("kind") or ""),
        "name": str(entry.get("name") or ""),
        "scope": list(entry.get("scope") or []),
        "range": list(entry.get("range") or []),
        "runtimeBoundary": str(entry.get("runtime_boundary") or ""),
        "runtimeCapability": str(entry.get("runtime_capability") or ""),
        "opaqueContext": bool(entry.get("opaque_context", False)),
        "editable": False,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default=str(DEFAULT_ROOT))
    parser.add_argument("--grammar", default="")
    parser.add_argument("--library", default="")
    parser.add_argument("--cache", default=str(default_cache_path()))
    parser.add_argument("--force", action="store_true")
    args = parser.parse_args()

    root = Path(args.root).expanduser().resolve()
    if not root.is_dir():
        return emit({
            "status": "invalid-request",
            "reason": "runtime root does not exist",
        }, 4)

    grammar = resolve_grammar(root, args.grammar)
    if grammar is None:
        return unavailable("grammar-missing")

    library = (
        args.library
        or os.environ.get("HADALIS_TREE_SITTER_LIBRARY", "")
        or None
    )
    try:
        grammar_stat = grammar.stat()
    except OSError as exc:
        return unavailable("grammar-unreadable", str(exc))

    helper_dir = Path(__file__).resolve().parent
    try:
        helper_hashes = {
            name: sha256((helper_dir / name).read_bytes()).hexdigest()
            for name in ("index.py", "native.py", "semantics.py")
        }
    except OSError as exc:
        return emit({
            "status": "error",
            "reason": "index-helper-read-failed",
            "detail": str(exc),
        }, 5)

    parser_signature = {
        "qmljsVersion": QMLJS_VERSION,
        "grammarPath": str(grammar),
        "grammarSize": grammar_stat.st_size,
        "grammarMtimeNs": grammar_stat.st_mtime_ns,
        "treeSitterLibrary": library or "system",
        "indexerSha256": helper_hashes["index.py"],
        "nativeAdapterSha256": helper_hashes["native.py"],
        "semanticsSha256": helper_hashes["semantics.py"],
    }
    cache_path = Path(args.cache).expanduser()
    cache = {"files": {}} if args.force else load_cache(
        cache_path, parser_signature
    )
    cached_files = cache.get("files") or {}

    qml_files = discover_qml(root)
    next_files = {}
    boundaries = []
    diagnostics = []
    cache_hits = 0
    parsed_files = 0

    native_parser = None
    try:
        native_parser = Parser(grammar, library)
        for source_path in qml_files:
            relative = source_path.relative_to(root).as_posix()
            try:
                source = source_path.read_bytes()
                source.decode("utf-8")
            except (OSError, UnicodeError) as exc:
                diagnostics.append({
                    "sourcePath": relative,
                    "kind": "source-read-failed",
                    "detail": str(exc),
                })
                continue

            source_sha = sha256(source).hexdigest()
            cached = cached_files.get(relative)
            if (
                isinstance(cached, dict)
                and cached.get("sourceSha256") == source_sha
                and isinstance(cached.get("boundaries"), list)
                and isinstance(cached.get("diagnostics"), list)
            ):
                record = cached
                cache_hits += 1
            else:
                try:
                    with native_parser.parse(source) as (_, nodes):
                        verify_ranges(source, nodes)
                        semantic = extract(relative, source, nodes)
                    projected = [
                        boundary_projection(relative, source_sha, entry)
                        for entry in semantic["entries"]
                        if str(entry.get("runtime_boundary") or "")
                    ]
                    record = {
                        "sourceSha256": source_sha,
                        "boundaries": projected,
                        "diagnostics": list(semantic["diagnostics"]),
                    }
                except (RuntimeError, AssertionError, UnicodeError, ValueError) as exc:
                    record = {
                        "sourceSha256": source_sha,
                        "boundaries": [],
                        "diagnostics": [{
                            "kind": "parse-failed",
                            "detail": str(exc),
                        }],
                    }
                parsed_files += 1

            next_files[relative] = record
            boundaries.extend(record["boundaries"])
            for diagnostic in record["diagnostics"]:
                diagnostics.append({
                    "sourcePath": relative,
                    **diagnostic,
                })
    except OSError as exc:
        return unavailable("tree-sitter-library-missing", str(exc))
    except RuntimeError as exc:
        return emit({
            "status": "error",
            "reason": "index-failed",
            "detail": str(exc),
        }, 5)
    finally:
        if native_parser is not None:
            native_parser.close()

    boundaries.sort(key=lambda item: (
        item["sourcePath"],
        item["range"][0] if len(item["range"]) == 2 else -1,
        item["anchor"],
    ))
    boundary_counts = Counter(
        item["runtimeBoundary"] for item in boundaries
    )
    removed_files = sorted(set(cached_files) - set(next_files))

    cache_payload = {
        "schema": CACHE_SCHEMA,
        "parserSignature": parser_signature,
        "files": next_files,
    }
    try:
        write_cache(cache_path, cache_payload)
    except OSError as exc:
        diagnostics.append({
            "sourcePath": "",
            "kind": "cache-write-failed",
            "detail": str(exc),
        })

    return emit({
        "status": "ok",
        "filesScanned": len(qml_files),
        "filesParsed": parsed_files,
        "cacheHits": cache_hits,
        "filesRemoved": removed_files,
        "boundaryCount": len(boundaries),
        "boundaryCounts": dict(sorted(boundary_counts.items())),
        "boundaries": boundaries,
        "diagnostics": diagnostics,
        "cache": {
            "schema": CACHE_SCHEMA,
            "path": str(cache_path),
        },
        "editable": False,
        "liveRuntimeEvidence": False,
    })


if __name__ == "__main__":
    raise SystemExit(main())
