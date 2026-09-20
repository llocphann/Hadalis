#!/usr/bin/env python3
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
SCRIPT_DIR = ROOT / "scripts/code-workflow"
sys.path.insert(0, str(SCRIPT_DIR))

import connect_cycle
from native import Parser, verify_ranges
from semantics import extract


def fail(message: str) -> None:
    raise SystemExit("FAIL: " + message)


def value_span(source: bytes, needle: bytes, start: int = 0) -> list[int]:
    offset = source.index(needle, start)
    return [offset, offset + len(needle)]


def parent_entry() -> dict:
    return {
        "anchor": "parent",
        "anchor_unique": True,
        "kind": "object",
        "name": "Item",
        "qml_id": "root",
        "scope": ["Item#root[1]"],
        "opaque_context": False,
    }


acyclic_source = (
    b"Item { id: root; property bool a: root.b; property bool b: true }\n"
)
a_range = value_span(acyclic_source, b"root.b")
b_range = value_span(acyclic_source, b"true")
acyclic_entries = [
    parent_entry(),
    {
        "anchor": "a",
        "anchor_unique": True,
        "kind": "property",
        "name": "a",
        "scope": ["Item#root[1]"],
        "value_range": a_range,
        "value_kind": "member_expression",
        "opaque_context": False,
    },
    {
        "anchor": "b",
        "anchor_unique": True,
        "kind": "property",
        "name": "b",
        "scope": ["Item#root[1]"],
        "value_range": b_range,
        "value_kind": "true",
        "opaque_context": False,
    },
]
result = connect_cycle.prove_local_dependency_closure(
    acyclic_source,
    acyclic_entries,
    "parent",
    "root.a",
    "visible",
)
if result.get("status") != "proven-acyclic":
    fail("closed local member chain ending in literal must prove acyclic")
if result.get("cycleSafetyProof") != connect_cycle.PROVEN_ACYCLIC:
    fail("acyclic proof token drifted")
if result.get("dependencyPath") != ["a", "b"]:
    fail("acyclic dependency path drifted")


cycle_source = b"Item { id: root; property bool a: root.visible }\n"
cycle_entries = [
    parent_entry(),
    {
        "anchor": "a",
        "anchor_unique": True,
        "kind": "property",
        "name": "a",
        "scope": ["Item#root[1]"],
        "value_range": value_span(cycle_source, b"root.visible"),
        "value_kind": "member_expression",
        "opaque_context": False,
    },
]
result = connect_cycle.prove_local_dependency_closure(
    cycle_source,
    cycle_entries,
    "parent",
    "root.a",
    "visible",
)
if result.get("status") != "proven-cycle":
    fail("dependency path reaching proposed target must prove cycle")
if result.get("cycleSafetyProof") != connect_cycle.PROVEN_CYCLE:
    fail("cycle proof token drifted")
if result.get("cycleKind") != "proposed-target-cycle":
    fail("proposed target cycle classification drifted")
if result.get("dependencyPath") != ["a", "visible"]:
    fail("target cycle dependency path drifted")


existing_cycle_source = (
    b"Item { id: root; property bool a: root.b; property bool b: root.a }\n"
)
first = value_span(existing_cycle_source, b"root.b")
second = value_span(existing_cycle_source, b"root.a", first[1])
existing_cycle_entries = [
    parent_entry(),
    {
        "anchor": "a",
        "anchor_unique": True,
        "kind": "property",
        "name": "a",
        "scope": ["Item#root[1]"],
        "value_range": first,
        "value_kind": "member_expression",
        "opaque_context": False,
    },
    {
        "anchor": "b",
        "anchor_unique": True,
        "kind": "property",
        "name": "b",
        "scope": ["Item#root[1]"],
        "value_range": second,
        "value_kind": "member_expression",
        "opaque_context": False,
    },
]
result = connect_cycle.prove_local_dependency_closure(
    existing_cycle_source,
    existing_cycle_entries,
    "parent",
    "root.a",
    "visible",
)
if result.get("status") != "proven-cycle":
    fail("existing cycle in dependency closure must fail unsafe")
if result.get("cycleKind") != "existing-source-cycle":
    fail("existing source cycle classification drifted")


external_source = b"Item { id: root; property bool a: Config.flag }\n"
external_entries = [
    parent_entry(),
    {
        "anchor": "a",
        "anchor_unique": True,
        "kind": "property",
        "name": "a",
        "scope": ["Item#root[1]"],
        "value_range": value_span(external_source, b"Config.flag"),
        "value_kind": "member_expression",
        "opaque_context": False,
    },
]
result = connect_cycle.prove_local_dependency_closure(
    external_source,
    external_entries,
    "parent",
    "root.a",
    "visible",
)
if result.get("status") != "unknown":
    fail("external dependency must remain UNKNOWN")
if result.get("reason") != "dependency-leaves-reviewed-parent-scope":
    fail("external dependency UNKNOWN reason drifted")


complex_source = b"Item { id: root; property bool a: root.b || true }\n"
complex_entries = [
    parent_entry(),
    {
        "anchor": "a",
        "anchor_unique": True,
        "kind": "property",
        "name": "a",
        "scope": ["Item#root[1]"],
        "value_range": value_span(complex_source, b"root.b || true"),
        "value_kind": "binary_expression",
        "opaque_context": False,
    },
]
result = connect_cycle.prove_local_dependency_closure(
    complex_source,
    complex_entries,
    "parent",
    "root.a",
    "visible",
)
if result.get("status") != "unknown":
    fail("complex dependency expression must remain UNKNOWN")
if result.get("reason") != "dependency-value-kind-outside-closed-subset":
    fail("complex dependency UNKNOWN reason drifted")


manifest = json.loads(
    (ROOT / "defaults/code-workflow-ir.json").read_text(encoding="utf-8")
)
target = manifest["graphs"]["bar/clock"]["connectTargets"][0]
helper = (SCRIPT_DIR / "connect_cycle.py").read_text(encoding="utf-8")
transaction = (
    ROOT / "services/CodeWorkflowTransaction.qml"
).read_text(encoding="utf-8")
phase2 = (ROOT / "docs/CODE_WORKFLOW_PHASE2.md").read_text(encoding="utf-8")
exclusions = json.loads(
    (ROOT / "sdata/runtime-exclusions.json").read_text(encoding="utf-8")
)

for token in (
    "def prove_local_dependency_closure(",
    'PROVEN_CYCLE = "cycle-proven-local-closure"',
    'PROVEN_ACYCLIC = "acyclic-closed-local-closure"',
    'PROOF_UNKNOWN = "unknown-incomplete-local-closure"',
    '"dependency-closure-reaches-connect-target"',
    '"dependency-leaves-reviewed-parent-scope"',
    '"dependency-value-kind-outside-closed-subset"',
    '"cycleStatus": CYCLE_UNKNOWN',
    '"typeCompatibility": TYPE_UNKNOWN',
    '"applyEnabled": False',
    '"artifactsStaged": False',
    '"productionIntegrated": False',
):
    if token not in helper:
        fail("2K-I cycle proof helper missing " + token)

for forbidden in (
    "write_text(",
    "write_bytes(",
    "os.replace(",
    "setText(",
):
    if forbidden in helper:
        fail("cycle proof helper must never write source: " + forbidden)

if 'Quickshell.shellPath("scripts/code-workflow/connect_cycle.py")' in transaction:
    fail("2K-I research proof must not be wired into production transaction")
if '"cycleSafetyProof"' in transaction:
    fail("2K-I research proof must not become production authorization")

if "scripts/code-workflow/connect_cycle.py" not in exclusions.get(
        "excludedPaths", []):
    fail("research-only cycle helper must stay outside runtime payload")

payload = subprocess.run(
    [sys.executable, str(ROOT / "sdata/lib/runtime-payload.py"),
     "list", "--root", str(ROOT)],
    cwd=ROOT,
    text=True,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    check=True,
).stdout.splitlines()
if "scripts/code-workflow/connect_cycle.py" in set(payload):
    fail("research-only cycle helper leaked into runtime payload")

for token in (
    "Milestone 2K-I — parser-closed Connect cycle proof",
    "cycle-proven-local-closure",
    "acyclic-closed-local-closure",
    "UNKNOWN",
    "root.showDate",
    "production CYCLE remains UNKNOWN",
):
    if token not in phase2:
        fail("2K-I documentation missing " + token)


grammar = os.environ.get("HADALIS_WORKFLOW_GRAMMAR", "")
library = os.environ.get("HADALIS_TREE_SITTER_LIBRARY", "")
if grammar and Path(grammar).is_file():
    parser = Parser(grammar, library or None)
    try:
        native_acyclic = (
            b"import QtQuick\n"
            b"Item {\n"
            b"    id: root\n"
            b"    property bool a: root.b\n"
            b"    property bool b: true\n"
            b"}\n"
        )
        with parser.parse(native_acyclic) as (_, nodes):
            verify_ranges(native_acyclic, nodes)
            semantic = extract("fixture.qml", native_acyclic, nodes)
        if semantic["diagnostics"]:
            fail("native acyclic fixture must parse cleanly")
        parent = next(
            entry for entry in semantic["entries"]
            if entry.get("kind") == "object"
            and entry.get("qml_id") == "root"
        )
        proof = connect_cycle.prove_local_dependency_closure(
            native_acyclic,
            semantic["entries"],
            parent["anchor"],
            "root.a",
            "visible",
        )
        if proof.get("cycleSafetyProof") != connect_cycle.PROVEN_ACYCLIC:
            fail("native closed local chain must prove acyclic")

        native_cycle = (
            b"import QtQuick\n"
            b"Item {\n"
            b"    id: root\n"
            b"    property bool a: root.visible\n"
            b"}\n"
        )
        with parser.parse(native_cycle) as (_, nodes):
            verify_ranges(native_cycle, nodes)
            semantic = extract("fixture.qml", native_cycle, nodes)
        if semantic["diagnostics"]:
            fail("native cycle fixture must parse cleanly")
        parent = next(
            entry for entry in semantic["entries"]
            if entry.get("kind") == "object"
            and entry.get("qml_id") == "root"
        )
        proof = connect_cycle.prove_local_dependency_closure(
            native_cycle,
            semantic["entries"],
            parent["anchor"],
            "root.a",
            "visible",
        )
        if proof.get("cycleSafetyProof") != connect_cycle.PROVEN_CYCLE:
            fail("native target dependency must prove cycle")
    finally:
        parser.close()

    analyses = []
    for _ in range(2):
        payload = connect_cycle.analyze_connect_cycle(
            ROOT,
            "bar/clock",
            target["id"],
            grammar,
            library,
        )
        if payload.get("status") != "analysis":
            fail("native 2K-I real fixture analysis failed")
        if payload.get("cycleSafetyProof") != connect_cycle.PROOF_UNKNOWN:
            fail("real clock fixture must remain UNKNOWN in first local subset")
        if payload.get("cycleAnalysisStatus") != "unknown":
            fail("real clock fixture cycle analysis status must stay unknown")
        if payload.get("cycleStatus") != "unknown-incomplete-projection":
            fail("production CYCLE must remain UNKNOWN after research proof")
        if payload.get("typeCompatibility") != "unknown-unresolved":
            fail("production TYPE must remain UNKNOWN during cycle proof")
        if payload.get("applyEnabled") is not False:
            fail("2K-I proof must not authorize Apply")
        if payload.get("artifactsStaged") is not False:
            fail("2K-I proof must not stage artifacts")
        if payload.get("productionIntegrated") is not False:
            fail("2K-I proof must stay outside production authorization")
        analyses.append(payload)

    stable_fields = (
        "baseSha256",
        "parentSemanticAnchor",
        "targetProperty",
        "sourceExpression",
        "cycleAnalysisStatus",
        "cycleSafetyProof",
        "cycleAnalysisReason",
        "dependencyPath",
        "cycleStatus",
        "typeCompatibility",
    )
    first = {key: analyses[0].get(key) for key in stable_fields}
    second = {key: analyses[1].get(key) for key in stable_fields}
    if first != second:
        fail("repeated native 2K-I analysis must be deterministic")

print("ok - Code Workflow 2K-I parser-closed Connect cycle proof")
