#!/usr/bin/env python3
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
SCRIPT_DIR = ROOT / "scripts/code-workflow"
sys.path.insert(0, str(SCRIPT_DIR))

import connect_type


def fail(message: str) -> None:
    raise SystemExit("FAIL: " + message)


manifest = json.loads(
    (ROOT / "defaults/code-workflow-ir.json").read_text(encoding="utf-8")
)
target = manifest["graphs"]["bar/clock"]["connectTargets"][0]

expected_metadata = {
    "reviewedParentTypeModule": "QtQuick",
    "reviewedParentTypeName": "Item",
    "typeCompatibility": "unknown-unresolved",
    "cycleStatus": "unknown-incomplete-projection",
}
for key, value in expected_metadata.items():
    if target.get(key) != value:
        fail(f"2K-H reviewed type metadata {key} drifted: {target.get(key)!r}")

entries = [
    {
        "anchor": "parent",
        "anchor_unique": True,
        "kind": "object",
        "name": "Item",
        "qml_id": "root",
        "scope": ["Item#root[1]"],
        "opaque_context": False,
    },
    {
        "anchor": "show-date",
        "anchor_unique": True,
        "kind": "property",
        "name": "showDate",
        "scope": ["Item#root[1]"],
        "declared_type": "bool",
        "opaque_context": False,
    },
]
resolved = connect_type.resolve_parent_member_declared_type(
    entries, "parent", "root.showDate")
if resolved.get("status") != "resolved":
    fail("simple parent member must resolve declared source type")
if resolved.get("declaredType") != "bool":
    fail("source-declared bool type evidence drifted")
if resolved.get("propertySemanticAnchor") != "show-date":
    fail("source property semantic identity drifted")

for expression, reason in (
    ("other.showDate", "member-base-is-not-reviewed-parent-id"),
    ("root.showDate.value", "expression-is-not-one-simple-member-reference"),
    ("root.showDate()", "expression-is-not-one-simple-member-reference"),
):
    result = connect_type.resolve_parent_member_declared_type(
        entries, "parent", expression)
    if result.get("status") != "unknown" or result.get("reason") != reason:
        fail("unsupported source expression must fail closed: " + expression)

ambiguous_entries = entries + [dict(entries[1], anchor="show-date-2")]
result = connect_type.resolve_parent_member_declared_type(
    ambiguous_entries, "parent", "root.showDate")
if result.get("reason") != "source-property-declaration-not-unique":
    fail("ambiguous source property type must fail closed")

helper = (SCRIPT_DIR / "connect_type.py").read_text(encoding="utf-8")

original_qml_import_path = os.environ.get("QML_IMPORT_PATH")
original_qml2_import_path = os.environ.get("QML2_IMPORT_PATH")
try:
    os.environ["QML_IMPORT_PATH"] = os.pathsep.join([
        str(ROOT / "modules"),
        str(ROOT / "missing-qml-import"),
    ])
    os.environ["QML2_IMPORT_PATH"] = os.pathsep.join([
        str(ROOT / "modules"),
        str(ROOT / "services"),
    ])
    import_paths = connect_type._qmllint_import_paths()
finally:
    if original_qml_import_path is None:
        os.environ.pop("QML_IMPORT_PATH", None)
    else:
        os.environ["QML_IMPORT_PATH"] = original_qml_import_path
    if original_qml2_import_path is None:
        os.environ.pop("QML2_IMPORT_PATH", None)
    else:
        os.environ["QML2_IMPORT_PATH"] = original_qml2_import_path

expected_import_paths = [
    str((ROOT / "modules").resolve()),
    str((ROOT / "services").resolve()),
]
if import_paths != expected_import_paths:
    fail("qmllint import roots must be explicit, existing and deduplicated")

coordinator = (
    SCRIPT_DIR / "connect_preview.py"
).read_text(encoding="utf-8")
transaction = (
    ROOT / "services/CodeWorkflowTransaction.qml"
).read_text(encoding="utf-8")
phase2 = (ROOT / "docs/CODE_WORKFLOW_PHASE2.md").read_text(encoding="utf-8")
exclusions = json.loads(
    (ROOT / "sdata/runtime-exclusions.json").read_text(encoding="utf-8")
)

for token in (
    "def resolve_parent_member_declared_type(",
    '"qmllint"',
    '"--json", "-",',
    '"--ignore-settings"',
    '"QML_IMPORT_PATH", "QML2_IMPORT_PATH"',
    'import_args += ["-I", path]',
    '"importPaths": _qmllint_import_paths()',
    "def _negative_control_source(",
    "property date workflowIncompatibleControl: 42",
    '"incompatible-type"',
    '"typeCompatibilityProof": TYPE_PROOF',
    '"typeCompatibility": TYPE_UNKNOWN',
    '"cycleStatus": CYCLE_UNKNOWN',
    '"applyEnabled": False',
    '"artifactsStaged": False',
    '"productionIntegrated": False',
):
    if token not in helper:
        fail("2K-H type proof helper missing " + token)

for token in (
    '"reviewedParentTypeModule"',
    '"reviewedParentTypeName"',
    '"typeCompatibility": target["typeCompatibility"]',
):
    if token not in coordinator:
        fail("reviewed type metadata boundary missing " + token)

if 'Quickshell.shellPath("scripts/code-workflow/connect_type.py")' in transaction:
    fail("2K-H research proof must not be wired into production transaction")
if '"typeCompatibilityProof"' in transaction:
    fail("2K-H proof must not become production transaction authorization")

if "scripts/code-workflow/connect_type.py" not in exclusions.get(
        "excludedPaths", []):
    fail("research-only type helper must stay outside runtime payload")

payload = subprocess.run(
    [sys.executable, str(ROOT / "sdata/lib/runtime-payload.py"),
     "list", "--root", str(ROOT)],
    cwd=ROOT,
    text=True,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    check=True,
).stdout.splitlines()
if "scripts/code-workflow/connect_type.py" in set(payload):
    fail("research-only type helper leaked into runtime payload")

for token in (
    "Milestone 2K-H — qmllint-backed Connect type proof",
    "positive oracle",
    "negative control",
    "compatible-qmllint-proof",
    "production Connect still reports TYPE UNKNOWN",
):
    if token not in phase2:
        fail("2K-H documentation missing " + token)

grammar = os.environ.get("HADALIS_WORKFLOW_GRAMMAR", "")
if grammar and Path(grammar).is_file():
    tool = connect_type._find_qmllint("")
    if tool is None:
        fail("native 2K-H acceptance has grammar but qmllint is unavailable")

    command = [
        sys.executable,
        str(SCRIPT_DIR / "connect_type.py"),
        "--root", str(ROOT),
        "--target-id", "bar/clock",
        "--connect-target-id", target["id"],
        "--grammar", grammar,
        "--qmllint", tool,
    ]
    library = os.environ.get("HADALIS_TREE_SITTER_LIBRARY", "")
    if library:
        command += ["--library", library]

    proofs = []
    for _ in range(2):
        completed = subprocess.run(
            command,
            check=False,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        if completed.returncode != 0:
            fail(
                "native 2K-H type proof failed: "
                + completed.stdout.strip()
                + " "
                + completed.stderr.strip()
            )
        payload = json.loads(completed.stdout)
        if payload.get("status") != "proof":
            fail("native 2K-H did not return proof status")
        if payload.get("typeCompatibilityProof") != "compatible-qmllint-proof":
            fail("native 2K-H compatibility proof drifted")
        if payload.get("sourceDeclaredType") != "bool":
            fail("native 2K-H source type must resolve to bool")
        if len(str(payload.get("candidateSha256") or "")) != 64:
            fail("native 2K-H must bind proof to preview candidate SHA")
        if payload.get("typeCompatibility") != "unknown-unresolved":
            fail("production TYPE must stay UNKNOWN after research proof")
        if payload.get("cycleStatus") != "unknown-incomplete-projection":
            fail("CYCLE must stay UNKNOWN after type proof")
        if payload.get("applyEnabled") is not False:
            fail("2K-H proof must not authorize Apply")
        if payload.get("artifactsStaged") is not False:
            fail("2K-H proof must not stage artifacts")
        if payload.get("productionIntegrated") is not False:
            fail("2K-H proof must remain outside production authorization")
        oracle = payload.get("oracle") or {}
        if not oracle.get("importPaths"):
            fail("native 2K-H must pass explicit QML import roots to qmllint")
        positive = oracle.get("positiveMarkers") or {}
        negative = oracle.get("negativeMarkers") or {}
        if any(positive.values()):
            fail("positive qmllint oracle must be clean")
        if negative.get("incompatibleType") is not True:
            fail("negative qmllint control must detect incompatible-type")
        proofs.append(payload)

    stable_fields = (
        "baseSha256",
        "candidateSha256",
        "parentSemanticAnchor",
        "parentTypeModule",
        "parentTypeName",
        "targetProperty",
        "sourceExpression",
        "sourcePropertySemanticAnchor",
        "sourceDeclaredType",
        "typeCompatibilityProof",
        "typeCompatibility",
        "cycleStatus",
    )
    first = {key: proofs[0].get(key) for key in stable_fields}
    second = {key: proofs[1].get(key) for key in stable_fields}
    if first != second:
        fail("repeated native 2K-H proof must be deterministic")

print("ok - Code Workflow 2K-H qmllint-backed Connect type proof")
