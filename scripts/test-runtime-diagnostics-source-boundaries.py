#!/usr/bin/env python3
"""Prove diagnostics source semantics discover future runtime boundaries."""

from pathlib import Path
import os
import sys

ROOT = Path(__file__).resolve().parents[1]
CORE = ROOT / "scripts" / "code-workflow"
sys.path.insert(0, str(CORE))

from native import Parser
from semantics import extract

grammar = os.environ.get("HADALIS_WORKFLOW_GRAMMAR", "")
if not grammar:
    system_grammar = Path("/usr/lib/inir/code-workflow/qmljs.so")
    repo_grammar = ROOT / "assets/code-workflow/qmljs.so"
    if repo_grammar.is_file():
        grammar = str(repo_grammar)
    elif system_grammar.is_file():
        grammar = str(system_grammar)

if not grammar or not Path(grammar).is_file():
    raise SystemExit("FAIL: runtime-boundary contract requires QML parser grammar")

source = b"""import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    Loader { id: dynLoader }
    LazyLoader { id: lazyLoader }
    Repeater { model: [] }
    Timer { interval: 1000 }
    Process { command: [\"true\"] }
    FileView { path: \"/tmp/example\" }

    Component {
        id: factory
        Item {}
    }

    function spawnRuntimeObjects() {
        factory.createObject(root)
        Qt.createComponent(\"Future.qml\")
        Qt.createQmlObject(\"Item {}\", root)
        dynLoader.setSource(\"Future.qml\")
        const xhr = new XMLHttpRequest()
    }
}
"""

parser = Parser(grammar, os.environ.get("HADALIS_TREE_SITTER_LIBRARY") or None)
try:
    with parser.parse(source) as (_, nodes):
        semantic = extract("synthetic/runtime-boundaries.qml", source, nodes)
finally:
    parser.close()

entries = semantic["entries"]
boundaries = [
    entry for entry in entries
    if str(entry.get("runtime_boundary", ""))
]

by_name = {str(entry.get("name", "")): entry for entry in boundaries}

expected_objects = {
    "Loader": "lifecycle",
    "LazyLoader": "lifecycle",
    "Repeater": "lifecycle",
    "Timer": "timer",
    "Process": "process",
    "FileView": "file-view",
}
for name, boundary in expected_objects.items():
    entry = by_name.get(name)
    if entry is None:
        raise SystemExit(f"FAIL: source semantics missed runtime object {name}")
    if entry.get("runtime_boundary") != boundary:
        raise SystemExit(
            f"FAIL: {name} boundary drifted: {entry.get('runtime_boundary')!r}"
        )

expected_calls = {
    "factory.createObject": "dynamic-object",
    "Qt.createComponent": "dynamic-component",
    "Qt.createQmlObject": "dynamic-qml-object",
    "dynLoader.setSource": "dynamic-loader-source",
    "XMLHttpRequest": "network",
}
for name, boundary in expected_calls.items():
    entry = by_name.get(name)
    if entry is None:
        raise SystemExit(f"FAIL: source semantics missed dynamic boundary {name}")
    if entry.get("kind") != "runtime-boundary":
        raise SystemExit(f"FAIL: {name} must remain an explicit runtime-boundary entry")
    if entry.get("runtime_boundary") != boundary:
        raise SystemExit(
            f"FAIL: {name} boundary drifted: {entry.get('runtime_boundary')!r}"
        )
    if entry.get("editable") is not False:
        raise SystemExit(f"FAIL: source-discovered runtime boundary {name} must be read-only")

# The feature is intentionally structural. It must discover arbitrary receiver
# IDs rather than only a reviewed loader name baked into Diagnostics.
if "dynLoader.setSource" not in by_name:
    raise SystemExit("FAIL: dynamic Loader setSource receiver was hardcoded away")

print("ok - runtime source semantics discover dynamic creation/resource boundaries")
