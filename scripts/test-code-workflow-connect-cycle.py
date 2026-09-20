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



parsed = connect_cycle.parse_optional_member_chain_with_literal_fallback(
    "Config.options?.bar?.verbose ?? true"
)
if parsed.get("status") != "resolved":
    fail("reviewed Config optional/nullish chain must enter 2K-J subset")
if parsed.get("base") != "Config":
    fail("external dependency base drifted")
if parsed.get("path") != ["options", "bar", "verbose"]:
    fail("external dependency member path drifted")
if parsed.get("optionalHops") != [False, True, True]:
    fail("optional member hop evidence drifted")
if parsed.get("fallbackLiteral") != "true":
    fail("nullish fallback literal evidence drifted")

for expression in (
    "Config.options.bar.verbose",
    "Config.options?.bar?.verbose || true",
    "Config.options?.bar?.verbose ?? root.enabled",
    "Config.options[index]?.verbose ?? true",
    "Config.options?.bar?.verbose() ?? true",
):
    rejected = connect_cycle.parse_optional_member_chain_with_literal_fallback(
        expression
    )
    if rejected.get("status") != "unknown":
        fail("unsupported cross-file expression must remain UNKNOWN: " + expression)


alias_source = (
    b"Singleton { property alias options: adapter; "
    b"JsonAdapter { id: adapter; "
    b"property JsonObject bar: JsonObject { "
    b"property bool verbose: true } } }\n"
)
options_span = value_span(alias_source, b"adapter")
bar_value = b"JsonObject { property bool verbose: true }"
bar_value_span = value_span(alias_source, bar_value)
bar_object_start = bar_value_span[0]
bar_object_end = bar_value_span[1]
verbose_span = value_span(alias_source, b"true")
alias_entries = [
    {
        "anchor": "options",
        "anchor_unique": True,
        "kind": "property",
        "name": "options",
        "scope": ["Singleton#root[1]"],
        "declared_type": "alias",
        "value_range": options_span,
        "value_kind": "identifier",
        "opaque_context": False,
    },
    {
        "anchor": "adapter",
        "anchor_unique": True,
        "kind": "object",
        "name": "JsonAdapter",
        "qml_id": "adapter",
        "scope": ["Singleton#root[1]", "JsonAdapter#adapter[1]"],
        "range": [alias_source.index(b"JsonAdapter"), len(alias_source) - 3],
        "opaque_context": False,
    },
    {
        "anchor": "bar",
        "anchor_unique": True,
        "kind": "property",
        "name": "bar",
        "scope": ["Singleton#root[1]", "JsonAdapter#adapter[1]"],
        "declared_type": "JsonObject",
        "value_range": bar_value_span,
        "value_kind": "ui_object_definition",
        "opaque_context": False,
    },
    {
        "anchor": "bar-object",
        "anchor_unique": True,
        "kind": "object",
        "name": "JsonObject",
        "qml_id": None,
        "scope": [
            "Singleton#root[1]",
            "JsonAdapter#adapter[1]",
            "JsonObject[1]",
        ],
        "range": [bar_object_start, bar_object_end],
        "opaque_context": False,
    },
    {
        "anchor": "verbose",
        "anchor_unique": True,
        "kind": "property",
        "name": "verbose",
        "scope": [
            "Singleton#root[1]",
            "JsonAdapter#adapter[1]",
            "JsonObject[1]",
        ],
        "declared_type": "bool",
        "value_range": verbose_span,
        "value_kind": "true",
        "opaque_context": False,
    },
]
nested = connect_cycle._resolve_alias_nested_literal(
    alias_source,
    alias_entries,
    "options",
    ["bar", "verbose"],
)
if nested.get("status") != "resolved":
    fail("alias -> JsonObject -> literal proof subset must resolve")
if nested.get("terminalValueText") != "true":
    fail("cross-file literal terminal value drifted")
if nested.get("dependencyPath") != ["options", "bar", "verbose"]:
    fail("cross-file nested dependency path drifted")


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
    'PROVEN_ACYCLIC_CROSS_FILE = "acyclic-source-backed-cross-file-closure"',
    'PROOF_UNKNOWN = "unknown-incomplete-local-closure"',
    '"dependency-closure-reaches-connect-target"',
    '"dependency-leaves-reviewed-parent-scope"',
    '"dependency-value-kind-outside-closed-subset"',
    "def parse_optional_member_chain_with_literal_fallback(",
    "def _resolve_imported_local_singleton(",
    "def _resolve_alias_nested_literal(",
    "def prove_cross_file_dependency_closure(",
    '"source-backed-cross-file-chain-ends-in-literal"',
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
    "Milestone 2K-J — source-backed cross-file Connect closure",
    "cycle-proven-local-closure",
    "acyclic-closed-local-closure",
    "acyclic-source-backed-cross-file-closure",
    "Config.options?.bar?.verbose ?? true",
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
            fail("native 2K-J real fixture analysis failed")
        if payload.get("localCycleSafetyProof") != connect_cycle.PROOF_UNKNOWN:
            fail("2K-I local subset must still report the real Clock as UNKNOWN")
        if len(str(payload.get("candidateSha256") or "")) != 64:
            fail("native 2K-J must bind cycle proof to preview candidate SHA")
        if payload.get("cycleSafetyProof") != (
            connect_cycle.PROVEN_ACYCLIC_CROSS_FILE
        ):
            fail("real Clock dependency must close through source-backed Config")
        if payload.get("cycleAnalysisStatus") != "proven-acyclic":
            fail("real Clock cross-file cycle analysis must prove acyclic")
        if payload.get("cycleAnalysisReason") != (
            "source-backed-cross-file-chain-ends-in-literal"
        ):
            fail("real Clock cross-file proof reason drifted")
        if payload.get("externalModuleUri") != "qs.modules.common":
            fail("real Clock external module resolution drifted")
        if payload.get("externalSourcePath") != "modules/common/Config.qml":
            fail("real Clock Config source resolution drifted")
        if len(str(payload.get("externalSourceSha256") or "")) != 64:
            fail("real Clock Config source SHA evidence missing")
        if payload.get("aliasTargetId") != "configOptionsJsonAdapter":
            fail("real Clock Config alias target drifted")
        if payload.get("terminalDeclaredType") != "bool":
            fail("real Clock Config terminal type must resolve to bool")
        if payload.get("terminalValueKind") != "true":
            fail("real Clock Config terminal must be direct true literal")
        if payload.get("terminalValueText") != "true":
            fail("real Clock Config terminal value drifted")
        if payload.get("fallbackLiteral") != "true":
            fail("real Clock nullish fallback evidence drifted")
        if payload.get("dependencyPath") != [
            "showDate",
            "Config",
            "options",
            "bar",
            "verbose",
        ]:
            fail("real Clock cross-file dependency path drifted")
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
        "candidateSha256",
        "parentSemanticAnchor",
        "targetProperty",
        "sourceExpression",
        "cycleAnalysisStatus",
        "cycleSafetyProof",
        "cycleAnalysisReason",
        "dependencyPath",
        "localCycleSafetyProof",
        "localCycleAnalysisReason",
        "externalModuleUri",
        "externalSourcePath",
        "externalSourceSha256",
        "aliasTargetId",
        "terminalPropertySemanticAnchor",
        "terminalDeclaredType",
        "terminalValueKind",
        "terminalValueText",
        "fallbackLiteral",
        "cycleStatus",
        "typeCompatibility",
    )
    first = {key: analyses[0].get(key) for key in stable_fields}
    second = {key: analyses[1].get(key) for key in stable_fields}
    if first != second:
        fail("repeated native 2K-I analysis must be deterministic")

print("ok - Code Workflow 2K-J source-backed cross-file Connect cycle proof")
