#!/usr/bin/env python3
from hashlib import sha256
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
SCRIPT_DIR = ROOT / "scripts/code-workflow"
sys.path.insert(0, str(SCRIPT_DIR))

import connect_preview


def fail(message: str) -> None:
    raise SystemExit("FAIL: " + message)


manifest = json.loads(
    (ROOT / "defaults/code-workflow-ir.json").read_text(encoding="utf-8")
)
target = manifest["graphs"]["bar/clock"]["connectTargets"][0]
source = (ROOT / target["sourcePath"]).read_bytes()
source_sha = sha256(source).hexdigest()
parent_anchor = "qml-semantic:object:clock-root"
inserted_anchor = "qml-semantic:binding:clock-root:visible"

calls: list[list[str]] = []


def good_runner(argv: list[str]):
    calls.append(list(argv))
    helper = Path(argv[1]).name
    if helper == "analyze.py":
        return 0, {
            "protocol": 1,
            "status": "ok",
            "sourcePath": target["sourcePath"],
            "sourceSha256": source_sha,
            "diagnostics": [],
            "reviewedObjectAnchor": {
                "status": "resolved",
                "semanticAnchor": parent_anchor,
                "semanticAnchorUnique": True,
                "semanticKind": "object",
                "semanticName": "Item",
                "semanticRange": [0, 999],
                "initializerRange": [100, 998],
                "scope": ["Item#root[1]"],
                "opaqueContext": False,
            },
        }
    if helper == "connect.py":
        return 0, {
            "protocol": 1,
            "status": "preview",
            "sourcePath": target["sourcePath"],
            "baseSha256": source_sha,
            "candidateSha256": "1" * 64,
            "parentSemanticAnchor": parent_anchor,
            "insertedSemanticAnchor": inserted_anchor,
            "bindingName": target["bindingName"],
            "expression": target["sourceExpression"],
            "commandKind": "connect-binding",
            "previewMode": "connect",
            "insertedSemanticKind": "binding",
            "insertedValueKind": target["reviewedValueKind"],
            "insertionEvidence": {
                "line": 99,
                "memberIndentBytes": 4,
                "closingIndentBytes": 0,
                "newline": "lf",
            },
            "patch": {
                "start": 999,
                "end": 999,
                "line": 99,
                "oldText": "",
                "newText": "    visible: root.showDate",
            },
            "preview": "+     visible: root.showDate",
            "cycleStatus": "unknown-incomplete-projection",
            "typeCompatibility": "unknown-unresolved",
            "applyEnabled": False,
        }
    fail("unexpected helper request " + helper)


result = connect_preview.coordinate_connect_preview(
    ROOT,
    "bar/clock",
    target["id"],
    request_runner=good_runner,
)
if result.get("status") != "preview":
    fail("reviewed target plus insertion proof must compose into preview")
if len(calls) != 2:
    fail("coordinator must issue exactly resolver + insertion requests")

resolver_call, insertion_call = calls
if Path(resolver_call[1]).name != "analyze.py":
    fail("first coordinator request must use analyzer")
if Path(insertion_call[1]).name != "connect.py":
    fail("second coordinator request must use parser-backed insertion helper")


def arg_value(argv: list[str], name: str) -> str:
    try:
        return argv[argv.index(name) + 1]
    except (ValueError, IndexError):
        fail("missing command argument " + name)


if arg_value(resolver_call, "--path") != target["sourcePath"]:
    fail("resolver must use reviewed source path")
if arg_value(resolver_call, "--object-needle") != target["parentObjectNeedle"]:
    fail("resolver must use reviewed parent object needle")
if arg_value(insertion_call, "--base-sha256") != source_sha:
    fail("insertion must use resolver source SHA")
if arg_value(insertion_call, "--parent-semantic-anchor") != parent_anchor:
    fail("insertion must use stable resolved parent anchor")
if arg_value(insertion_call, "--binding-name") != target["bindingName"]:
    fail("insertion must preserve reviewed binding name")
if arg_value(insertion_call, "--expression") != target["sourceExpression"]:
    fail("insertion must preserve reviewed source expression")

for forbidden in (
    "--initializer-range",
    "--semantic-range",
    "--parser-node",
    "--node-index",
    "--scope",
):
    if forbidden in insertion_call:
        fail("transient parser evidence crossed coordinator boundary: " + forbidden)

handoff = result.get("primitiveHandoff") or {}
if set(handoff) != {
    "sourcePath",
    "sourceSha256",
    "connectTargetId",
    "parentSemanticAnchor",
    "bindingName",
    "sourceExpression",
    "reviewedParentSemanticKind",
    "reviewedValueKind",
}:
    fail("primitive Connect handoff fields drifted")
for value in handoff.values():
    if not isinstance(value, str):
        fail("Connect handoff must contain primitive strings only")
for forbidden_key in (
    "initializerRange",
    "semanticRange",
    "needleRange",
    "scope",
    "entries",
    "parser",
):
    if forbidden_key in handoff:
        fail("transient resolver evidence leaked into primitive handoff")

if result.get("typeCompatibility") != "unknown-unresolved":
    fail("type compatibility UNKNOWN must survive coordinator")
if result.get("cycleStatus") != "unknown-incomplete-projection":
    fail("cycle UNKNOWN must survive coordinator")
if result.get("applyEnabled") is not False:
    fail("coordinator must never authorize Connect Apply")
if result.get("artifactsStaged") is not False:
    fail("coordinator must never stage Apply artifacts")


def runner_with_resolver_kind_drift(argv: list[str]):
    code, payload = good_runner(argv)
    if Path(argv[1]).name == "analyze.py":
        payload = dict(payload)
        payload["reviewedObjectAnchor"] = dict(payload["reviewedObjectAnchor"])
        payload["reviewedObjectAnchor"]["semanticKind"] = "binding"
    return code, payload


calls.clear()
blocked = connect_preview.coordinate_connect_preview(
    ROOT,
    "bar/clock",
    target["id"],
    request_runner=runner_with_resolver_kind_drift,
)
if blocked.get("reason") != "reviewed-parent-semantic-kind-drift":
    fail("reviewed parent semantic kind drift must fail closed")
if len(calls) != 1:
    fail("resolver drift must block before insertion request")


def runner_with_missing_opaque_evidence(argv: list[str]):
    code, payload = good_runner(argv)
    if Path(argv[1]).name == "analyze.py":
        payload = dict(payload)
        payload["reviewedObjectAnchor"] = dict(payload["reviewedObjectAnchor"])
        payload["reviewedObjectAnchor"].pop("opaqueContext", None)
    return code, payload


calls.clear()
blocked = connect_preview.coordinate_connect_preview(
    ROOT,
    "bar/clock",
    target["id"],
    request_runner=runner_with_missing_opaque_evidence,
)
if blocked.get("reason") != "reviewed-parent-object-became-opaque":
    fail("missing non-opaque evidence must fail closed")
if len(calls) != 1:
    fail("missing non-opaque evidence must block before insertion request")


def runner_with_sha_drift(argv: list[str]):
    code, payload = good_runner(argv)
    if Path(argv[1]).name == "connect.py":
        payload = dict(payload)
        payload["baseSha256"] = "2" * 64
    return code, payload


calls.clear()
blocked = connect_preview.coordinate_connect_preview(
    ROOT,
    "bar/clock",
    target["id"],
    request_runner=runner_with_sha_drift,
)
if blocked.get("reason") != "insertion-source-sha-drift":
    fail("source SHA drift between parser requests must fail closed")


def runner_with_value_kind_drift(argv: list[str]):
    code, payload = good_runner(argv)
    if Path(argv[1]).name == "connect.py":
        payload = dict(payload)
        payload["insertedValueKind"] = "binary_expression"
    return code, payload


calls.clear()
blocked = connect_preview.coordinate_connect_preview(
    ROOT,
    "bar/clock",
    target["id"],
    request_runner=runner_with_value_kind_drift,
)
if blocked.get("reason") != "inserted-value-kind-drift":
    fail("inserted value kind drift must fail closed")

coordinator_source = (
    SCRIPT_DIR / "connect_preview.py"
).read_text(encoding="utf-8")
transaction_source = (
    ROOT / "services/CodeWorkflowTransaction.qml"
).read_text(encoding="utf-8")
phase2 = (ROOT / "docs/CODE_WORKFLOW_PHASE2.md").read_text(encoding="utf-8")

for forbidden in ("write_text(", "write_bytes(", "os.replace(", "setText("):
    if forbidden in coordinator_source:
        fail("Connect coordinator must never write source: " + forbidden)

if 'Quickshell.shellPath("scripts/code-workflow/connect.py")' in transaction_source:
    fail("production transaction service must not bypass the coordinator")
for token in (
    'Quickshell.shellPath("scripts/code-workflow/connect_preview.py")',
    'function previewConnectBinding(',
    '"connect-binding"',
    'String(root.activeCommand?.kind ?? "") === "literal-property"',
    'if (String(command.kind ?? "") !== "literal-property")',
    'blockers.push("write-subset-not-authorized")',
):
    if token not in transaction_source:
        fail("2K-G integration lost coordinator/Apply isolation: " + token)

for token in (
    "Milestone 2K-F — deterministic Connect preview coordinator",
    "primitive-only handoff",
    "same-SHA",
    "TYPE UNKNOWN",
    "CYCLE UNKNOWN",
    "PREVIEW ONLY",
):
    if token not in phase2:
        fail("2K-F documentation missing " + token)

grammar = os.environ.get("HADALIS_WORKFLOW_GRAMMAR", "")
if grammar and Path(grammar).is_file():
    command = [
        sys.executable,
        str(SCRIPT_DIR / "connect_preview.py"),
        "--root", str(ROOT),
        "--target-id", "bar/clock",
        "--connect-target-id", target["id"],
        "--grammar", grammar,
    ]
    library = os.environ.get("HADALIS_TREE_SITTER_LIBRARY", "")
    if library:
        command += ["--library", library]

    native_results = []
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
                "native coordinator proof failed: "
                + completed.stdout.strip()
                + " "
                + completed.stderr.strip()
            )
        payload = json.loads(completed.stdout)
        if payload.get("status") != "preview":
            fail("native coordinator did not return preview")
        native_results.append(payload)

    stable_fields = (
        "sourcePath",
        "baseSha256",
        "candidateSha256",
        "parentSemanticAnchor",
        "insertedSemanticAnchor",
        "bindingName",
        "expression",
        "insertedSemanticKind",
        "insertedValueKind",
        "typeCompatibility",
        "cycleStatus",
        "patch",
    )
    first = {key: native_results[0].get(key) for key in stable_fields}
    second = {key: native_results[1].get(key) for key in stable_fields}
    if first != second:
        fail("repeated native coordinator preview must be deterministic")
    if native_results[0].get("applyEnabled") is not False:
        fail("native coordinator proof must remain preview-only")

print("ok - Code Workflow 2K-F deterministic Connect preview coordinator")
