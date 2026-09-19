#!/usr/bin/env python3
"""Spike A: inspect an immutable Git QML corpus without writing source files."""

import argparse
from collections import Counter
from hashlib import sha256
import json
from pathlib import Path
import platform
import subprocess
import time

from native import Parser, insertion, verify_ranges
from semantics import extract


REQUIRED = [
    "modules/bar/BarContent.qml", "modules/bar/Media.qml",
    "modules/dashboard/DashboardContent.qml", "modules/overview/OverviewNiriWidget.qml",
    "modules/settings/SettingsPageHost.qml", "services/NiriService.qml",
    "services/ShellEditSession.qml", "modules/waffle/ShellWafflePanelsImpl.qml",
    "modules/waffle/bar/WaffleBarContent.qml",
    "modules/waffle/actionCenter/volumeControl/VolumeEntry.qml",
]
PREFIX = "// Spike A: unrelated line insertion — tiếng Việt 🌊\r\n\n".encode()


def git(repo, *args):
    return subprocess.check_output(["git", "-C", str(repo), *args])


def inspect(parser, path, source):
    with parser.parse(source) as (tree, nodes):
        preservation = verify_ranges(source, nodes)
        semantic = extract(path, source, nodes)
        # Keep a BOM at byte zero. Newline/Unicode offsets are bytes, not columns
        # in a Python string or UTF-16 offsets in a QML/JS string.
        offset = 3 if source.startswith(b"\xef\xbb\xbf") else 0
        changed = source[:offset] + PREFIX + source[offset:]
        with parser.parse(changed, tree, insertion(source, offset, PREFIX)) as (_, incremental):
            verify_ranges(changed, incremental)
            moved = extract(path, changed, incremental)
        with parser.parse(changed) as (_, fresh):
            assert fresh == incremental, "Incremental CST differs from fresh parse"
        assert [(e["anchor"], e["kind"]) for e in semantic["entries"]] == [
            (e["anchor"], e["kind"]) for e in moved["entries"]], "Anchors changed after prefix insertion"
        assert len(semantic["diagnostics"]) == len(moved["diagnostics"]), "Diagnostics changed after comment insertion"
        features = Counter()
        for e in semantic["entries"]:
            if "object_type" in e:
                features[e["object_type"].rsplit(".", 1)[-1]] += 1
            if e["kind"] == "inline-component":
                features["inline-component"] += 1
                if sum(s.startswith("component:") for s in e["scope"]) > 1:
                    features["nested-inline-component"] += 1
            if e["name"] == "Qt.binding":
                features["Qt.binding"] += 1
            if e.get("declared_type") == "alias":
                features["property-alias"] += 1
            if "required" in e.get("modifiers", []):
                features["required-property"] += 1
            if e["kind"] == "pragma" and e["name"] == "ComponentBehavior" and e["value"] == "Bound":
                features["ComponentBehavior:Bound"] += 1
    return {"path": path, "sha256": sha256(source).hexdigest(), "bytes": len(source),
            "preservation": preservation, "incremental_equals_fresh": True,
            "anchors_stable_after_prefix": True, "features": dict(features), **semantic}


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--grammar", type=Path, required=True)
    ap.add_argument("--library", help="Optional path to the public Tree-sitter shared library")
    ap.add_argument("--repo", type=Path, default=Path(__file__).resolve().parents[2])
    ap.add_argument("--revision", default="HEAD", help="Immutable commit is resolved before reading any source")
    ap.add_argument("--inspect", help="Emit full extraction proof for one tracked QML path")
    args = ap.parse_args()
    revision = git(args.repo, "rev-parse", "--verify", args.revision + "^{commit}").decode().strip()
    paths = [p for p in git(args.repo, "ls-tree", "-r", "-z", "--name-only", revision).decode().split("\0") if p.endswith(".qml")]
    if args.inspect:
        if args.inspect not in paths:
            ap.error("--inspect must name a tracked QML file in the selected revision")
        paths = [args.inspect]
    elif not set(REQUIRED).issubset(paths):
        ap.error("Required corpus files missing: " + ", ".join(sorted(set(REQUIRED) - set(paths))))
    parser, started = Parser(args.grammar, args.library), time.monotonic()
    files, counts, features, proofs, opaque_reasons = [], Counter(), Counter(), {}, Counter()
    failures, manifest = [], sha256()
    try:
        for path in paths:
            source = git(args.repo, "show", f"{revision}:{path}")
            manifest.update(path.encode() + b"\0" + sha256(source).digest())
            try:
                result = inspect(parser, path, source)
            except (AssertionError, UnicodeError, RuntimeError) as exc:
                failures.append({"path": path, "failure": str(exc)})
                continue
            counts.update(result["counts"])
            features.update(result["features"])
            if args.inspect:
                print(json.dumps({"source_revision": revision, **result}, indent=2))
                return int(bool(result["diagnostics"]))
            entries = result.pop("entries")
            result["opaque_ranges"] = [{"range": e["range"], "name": e["name"], "reason": e["reason"]}
                                       for e in entries if e["kind"] == "opaque"]
            opaque_reasons.update(e["reason"] for e in entries if e["kind"] == "opaque")
            for e in entries:
                key = e.get("reason", e["kind"])
                if key not in proofs or len(proofs[key]) < 3:
                    proofs.setdefault(key, []).append({"path": path, **e,
                        "source_excerpt": source[e["range"][0]:e["range"][1]].decode()[:300]})
            files.append(result)
    finally:
        parser.close()
    required_features = {"Qt.binding", "Binding", "inline-component", "Component",
                         "State", "Transition", "Variants", "LazyLoader", "Connections", "Loader",
                         "property-alias", "required-property", "ComponentBehavior:Bound"}
    missing_features = sorted(required_features - features.keys())
    parse_errors = [r for r in files if r["diagnostics"]]
    report = {
        "schema": 1, "spike": "A", "source_revision": revision,
        "corpus_manifest_sha256": manifest.hexdigest(),
        "grammar": {"name": "tree-sitter-qmljs", "version": "0.3.1",
                    "upstream_commit": "de96ed62abded51fcdfcbeaaa120e0dd0d20c697",
                    "build_sha256": sha256(args.grammar.read_bytes()).hexdigest()},
        "environment": {"platform": platform.platform(), "python": platform.python_version(),
                        "tree_sitter_library": parser.lib._name},
        "summary": {"files": len(paths), "files_without_syntax_errors": len(files) - len(parse_errors),
                    "preserved_files": len(files), "incremental_equivalent_files": len(files),
                    "anchor_stable_files": len(files),
                    "nodes": sum(r["preservation"]["nodes"] for r in files),
                    "comments": sum(r["preservation"]["comments"] for r in files),
                    "bytes": sum(r["bytes"] for r in files), "extracted": dict(sorted(counts.items())),
                    "opaque_reasons": dict(sorted(opaque_reasons.items())),
                    "anchor_collision_files": sum(bool(r["anchor_collisions"]) for r in files),
                    "missing_required_features": missing_features, "elapsed_s": round(time.monotonic() - started, 3)},
        "scope_limits": ["All extracted entries are read-only syntax candidates, not resolved Workflow IR.",
                         "Structural ordinal anchors promise comment/line-shift stability only, not arbitrary edits.",
                         "Opaque groups, interceptors, imperative rebinding and colliding anchors require later semantic work.",
                         "No-op uses source slices plus trivia gaps; no pretty-printing or source-writing transform.",
                         "Runtime helper transport and installation packaging remain unproven."],
        "required_files": REQUIRED, "features": dict(sorted(features.items())),
        "semantic_proofs": proofs, "failures": failures, "files": files,
    }
    print(json.dumps(report, indent=2))
    return int(bool(failures or parse_errors or missing_features))


if __name__ == "__main__":
    raise SystemExit(main())
