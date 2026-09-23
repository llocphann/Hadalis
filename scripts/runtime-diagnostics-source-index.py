#!/usr/bin/env python3
"""On-demand Hadalis QML runtime-boundary source index.

The scanner is invoked only by the leased Runtime Diagnostics session. It reuses
Code Workflow's native Tree-sitter semantics, enumerates the packaged runtime
payload instead of a hand-maintained component list, includes installed custom
widget entrypoints, and caches parsed results by source hash + parser version.
"""

from __future__ import annotations

import argparse
from hashlib import sha256
import importlib.util
import json
import os
from pathlib import Path
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
CORE = ROOT / "scripts" / "code-workflow"
sys.path.insert(0, str(CORE))

from native import Parser
from semantics import extract

QMLJS_VERSION = "0.3.1"
CACHE_VERSION = 1


def load_payload_class(root: Path):
    module_path = root / "sdata" / "lib" / "runtime-payload.py"
    spec = importlib.util.spec_from_file_location(
        "hadalis_runtime_payload", module_path
    )
    if spec is None or spec.loader is None:
        raise RuntimeError("runtime-payload-loader-unavailable")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module.Payload


def resolve_grammar(root: Path, explicit: str) -> Path | None:
    if explicit:
        candidate = Path(explicit).expanduser().resolve()
        return candidate if candidate.is_file() else None

    env_value = os.environ.get("HADALIS_WORKFLOW_GRAMMAR", "")
    if env_value:
        candidate = Path(env_value).expanduser().resolve()
        if candidate.is_file():
            return candidate

    for candidate in (
        (root / "assets/code-workflow/qmljs.so").resolve(),
        Path("/usr/lib/inir/code-workflow/qmljs.so"),
    ):
        if candidate.is_file():
            return candidate
    return None


def default_cache_path() -> Path:
    cache_root = os.environ.get("XDG_CACHE_HOME", "")
    if cache_root:
        base = Path(cache_root).expanduser()
    else:
        base = Path.home() / ".cache"
    return base / "inir" / "runtime-diagnostics-source-index-v1.json"


def load_cache(path: Path) -> dict:
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {"version": CACHE_VERSION, "parserVersion": QMLJS_VERSION, "files": {}}
    if (
        payload.get("version") != CACHE_VERSION
        or payload.get("parserVersion") != QMLJS_VERSION
        or not isinstance(payload.get("files"), dict)
    ):
        return {"version": CACHE_VERSION, "parserVersion": QMLJS_VERSION, "files": {}}
    return payload


def save_cache(path: Path, files: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_suffix(path.suffix + ".tmp")
    temp.write_text(
        json.dumps(
            {
                "version": CACHE_VERSION,
                "parserVersion": QMLJS_VERSION,
                "files": files,
            },
            ensure_ascii=False,
            separators=(",", ":"),
        ),
        encoding="utf-8",
    )
    temp.replace(path)


def runtime_sources(root: Path):
    Payload = load_payload_class(root)
    payload = Payload(root)
    for relative in sorted(set(payload.paths())):
        if not relative.endswith(".qml"):
            continue
        path = root / relative
        if path.is_file():
            yield {
                "key": "runtime:" + relative,
                "path": path,
                "sourcePath": relative,
                "origin": "runtime",
                "customWidgetId": "",
            }


def custom_widget_sources(custom_root: Path | None):
    if custom_root is None or not custom_root.is_dir():
        return
    for manifest_path in sorted(custom_root.glob("*/widget.json")):
        widget_id = manifest_path.parent.name
        try:
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            continue
        main_name = str(
            manifest.get("main")
            or (widget_id[:1].upper() + widget_id[1:] + ".qml")
        )
        candidate = (manifest_path.parent / main_name).resolve()
        try:
            candidate.relative_to(manifest_path.parent.resolve())
        except ValueError:
            continue
        if candidate.suffix != ".qml" or not candidate.is_file():
            continue
        yield {
            "key": "custom:" + widget_id + ":" + main_name,
            "path": candidate,
            "sourcePath": str(candidate),
            "origin": "custom-widget",
            "customWidgetId": widget_id,
        }


def boundary_projection(entry: dict, source_info: dict) -> dict:
    result = {
        "sourcePath": source_info["sourcePath"],
        "origin": source_info["origin"],
        "anchor": str(entry.get("anchor", "")),
        "kind": str(entry.get("kind", "")),
        "name": str(entry.get("name", "")),
        "boundary": str(entry.get("runtime_boundary", "")),
        "capability": str(entry.get("runtime_capability", "")),
        "range": entry.get("range"),
        "editable": False,
    }
    if source_info["customWidgetId"]:
        result["customWidgetId"] = source_info["customWidgetId"]
        result["targetId"] = (
            "desktop-widget/custom/" + source_info["customWidgetId"]
        )
    return result


def parse_source(parser: Parser, info: dict) -> dict:
    source = info["path"].read_bytes()
    source.decode("utf-8")
    digest = sha256(source).hexdigest()
    with parser.parse(source) as (_, nodes):
        semantic = extract(info["sourcePath"], source, nodes)
    boundaries = [
        boundary_projection(entry, info)
        for entry in semantic["entries"]
        if str(entry.get("runtime_boundary", ""))
    ]
    return {
        "sha256": digest,
        "sourcePath": info["sourcePath"],
        "origin": info["origin"],
        "customWidgetId": info["customWidgetId"],
        "boundaries": boundaries,
        "diagnosticCount": len(semantic["diagnostics"]),
    }


def main() -> int:
    parser_cli = argparse.ArgumentParser(description=__doc__)
    parser_cli.add_argument("--root", type=Path, default=ROOT)
    parser_cli.add_argument("--custom-root", type=Path)
    parser_cli.add_argument("--grammar", default="")
    parser_cli.add_argument("--library", default="")
    parser_cli.add_argument("--cache", type=Path, default=default_cache_path())
    args = parser_cli.parse_args()

    root = args.root.expanduser().resolve()
    if not root.is_dir():
        print(json.dumps({"status": "error", "reason": "runtime-root-missing"}))
        return 2

    grammar = resolve_grammar(root, args.grammar)
    if grammar is None:
        print(json.dumps({"status": "unavailable", "reason": "grammar-missing"}))
        return 3

    library = (
        args.library
        or os.environ.get("HADALIS_TREE_SITTER_LIBRARY", "")
        or None
    )
    cache_path = args.cache.expanduser().resolve()
    cache = load_cache(cache_path)
    old_files = cache.get("files", {})
    next_files: dict[str, dict] = {}
    reused = 0
    parsed = 0
    errors = []

    sources = list(runtime_sources(root))
    sources.extend(
        list(custom_widget_sources(
            args.custom_root.expanduser().resolve()
            if args.custom_root is not None else None
        ) or [])
    )

    native = Parser(grammar, library)
    try:
        for info in sources:
            try:
                raw = info["path"].read_bytes()
                digest = sha256(raw).hexdigest()
                cached = old_files.get(info["key"])
                if (
                    isinstance(cached, dict)
                    and cached.get("sha256") == digest
                    and cached.get("sourcePath") == info["sourcePath"]
                ):
                    next_files[info["key"]] = cached
                    reused += 1
                    continue
                result = parse_source(native, info)
                next_files[info["key"]] = result
                parsed += 1
            except (OSError, UnicodeError, RuntimeError, AssertionError) as exc:
                errors.append({
                    "sourcePath": info["sourcePath"],
                    "reason": str(exc),
                })
    finally:
        native.close()

    try:
        save_cache(cache_path, next_files)
        cache_error = ""
    except OSError as exc:
        cache_error = str(exc)

    boundaries = []
    for key in sorted(next_files):
        boundaries.extend(next_files[key].get("boundaries", []))

    counts: dict[str, int] = {}
    for boundary in boundaries:
        name = str(boundary.get("boundary", "unknown"))
        counts[name] = counts.get(name, 0) + 1

    result = {
        "status": "ok",
        "generatedAtMs": int(time.time() * 1000),
        "parserVersion": QMLJS_VERSION,
        "files": len(next_files),
        "parsedFiles": parsed,
        "reusedFiles": reused,
        "boundaryCount": len(boundaries),
        "boundaryCounts": dict(sorted(counts.items())),
        "boundaries": boundaries,
        "errors": errors,
        "cache": {
            "path": str(cache_path),
            "error": cache_error,
        },
    }
    print(json.dumps(result, ensure_ascii=False, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
