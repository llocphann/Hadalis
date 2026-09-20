#!/usr/bin/env python3
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
SCRIPT_DIR = ROOT / "scripts/code-workflow"
sys.path.insert(0, str(SCRIPT_DIR))

import connect_prepare
import connect_type


def fail(message: str) -> None:
    raise SystemExit("FAIL: " + message)


manifest = json.loads(
    (ROOT / "defaults/code-workflow-ir.json").read_text(encoding="utf-8")
)
target = manifest["graphs"]["bar/clock"]["connectTargets"][0]
helper = (SCRIPT_DIR / "connect_prepare.py").read_text(encoding="utf-8")
transaction = (
    ROOT / "services/CodeWorkflowTransaction.qml"
).read_text(encoding="utf-8")
page = (ROOT / "modules/settings/CodeWorkflow.qml").read_text(encoding="utf-8")
phase2 = (ROOT / "docs/CODE_WORKFLOW_PHASE2.md").read_text(encoding="utf-8")
exclusions = json.loads(
    (ROOT / "sdata/runtime-exclusions.json").read_text(encoding="utf-8")
)

missing = connect_prepare.probe_connect_preparation_capability(
    ROOT,
    "bar/clock",
    target["id"],
    str(ROOT / ".definitely-missing-qmljs.so"),
)
if missing.get("status") != "capability":
    fail("2K-N capability probe protocol status drifted")
if missing.get("ready") is not False:
    fail("missing parser capability must fail closed")
if missing.get("reason") != "grammar-missing":
    fail("missing parser capability reason drifted")
if missing.get("writeAuthorized") is not False:
    fail("capability probe must never authorize writes")
if missing.get("applyEnabled") is not False:
    fail("capability probe must never enable Apply")
if missing.get("artifactsStaged") is not False:
    fail("capability probe must never stage artifacts")

for token in (
    "def probe_connect_preparation_capability(",
    '"--probe"',
    "_find_qmllint(",
    "_qmllint_version(",
    "_qmllint_import_paths()",
    '"parserAvailable": True',
    '"qmllintAvailable": True',
    '"sourceWritable": True',
    '"qualificationSnapshot": _qualification_snapshot(qualification)',
    '"writeAuthorized": False',
    '"applyEnabled": False',
):
    if token not in helper:
        fail("2K-N production Connect coordinator missing " + token)

for token in (
    "property var connectPreparationCapability:",
    "property string connectPreparationError:",
    "readonly property bool connectPreparationBusy:",
    "readonly property var activeConnectPreparation:",
    "readonly property bool connectArtifactsReady:",
    "readonly property bool connectPrepareEnabled:",
    "function _connectPreparationMatchesCommand(command): bool",
    "function _sanitizeConnectPreparation(payload): var",
    "function probeActiveConnectPreparationCapability(): bool",
    "function finishConnectPreparationCapability(exitCode: int): void",
    "function prepareConnectArtifacts(): bool",
    "function finishConnectPreparation(exitCode: int): void",
    '"scripts/code-workflow/connect_prepare.py"',
    'Quickshell.statePath(',
    '"code-workflow/connect-transactions"',
    '"prepared-qualified-connect-artifacts-v1"',
    'freshness: "fresh"',
    'connectPreparation: preparation',
):
    if token not in transaction:
        fail("2K-N transaction integration missing " + token)

for forbidden in (
    'Quickshell.shellPath("scripts/code-workflow/connect_type.py")',
    'Quickshell.shellPath("scripts/code-workflow/connect_cycle.py")',
    'Quickshell.shellPath("scripts/code-workflow/connect_qualify.py")',
):
    if forbidden in transaction:
        fail("QML transaction must not invoke low-level proof support: " + forbidden)

for token in (
    'mainText: CodeWorkflowTransaction.connectArtifactsReady',
    '"Prepare Connect artifacts"',
    '"CONNECT ARTIFACTS READY · APPLY BLOCKED"',
    '"Connect preparation capability: READY',
    "source QML is unchanged · Apply remains blocked",
    "CodeWorkflowTransaction.prepareConnectArtifacts()",
):
    if token not in page:
        fail("2K-N Connect preparation UI missing " + token)

for forbidden in (
    "Apply Connect",
    "Connect Apply",
    "beginConnectApply",
):
    if forbidden in page or forbidden in transaction:
        fail("2K-N must not expose Connect source Apply: " + forbidden)

for token in (
    'String(root.activeCommand?.kind ?? "") === "literal-property"',
    'if (String(command.kind ?? "") !== "literal-property")',
    'blockers.push("write-subset-not-authorized")',
    "if (!root.applyEnabled)",
):
    if token not in transaction:
        fail("2K-N must preserve literal-only source Apply isolation: " + token)

support_paths = (
    "scripts/code-workflow/connect_type.py",
    "scripts/code-workflow/connect_cycle.py",
    "scripts/code-workflow/connect_qualify.py",
    "scripts/code-workflow/connect_prepare.py",
)
for path in support_paths:
    if path in exclusions.get("excludedPaths", []):
        fail("2K-N runtime support must not remain excluded: " + path)

runtime_payload = subprocess.run(
    [
        sys.executable,
        str(ROOT / "sdata/lib/runtime-payload.py"),
        "list",
        "--root",
        str(ROOT),
    ],
    cwd=ROOT,
    text=True,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    check=True,
).stdout.splitlines()
runtime_set = set(runtime_payload)
for path in support_paths:
    if path not in runtime_set:
        fail("2K-N runtime support missing from payload: " + path)

for token in (
    "Milestone 2K-N — production Connect preparation integration",
    "capability probe",
    "connect_prepare.py",
    "Prepare Connect artifacts",
    "Apply remains blocked",
    "literal-property remains the only",
):
    if token not in phase2:
        fail("2K-N documentation missing " + token)

grammar = os.environ.get("HADALIS_WORKFLOW_GRAMMAR", "")
library = os.environ.get("HADALIS_TREE_SITTER_LIBRARY", "")
if grammar and Path(grammar).is_file():
    tool = connect_type._find_qmllint("")
    if tool is None:
        fail("native 2K-N acceptance has grammar but qmllint is unavailable")

    ready = connect_prepare.probe_connect_preparation_capability(
        ROOT,
        "bar/clock",
        target["id"],
        grammar,
        library,
        tool,
    )
    if ready.get("status") != "capability":
        fail("native 2K-N capability status drifted")
    if ready.get("ready") is not True:
        fail(
            "native 2K-N capability must be ready: "
            + json.dumps(ready, sort_keys=True)
        )
    if ready.get("parserAvailable") is not True:
        fail("native 2K-N parser capability missing")
    if ready.get("qmllintAvailable") is not True:
        fail("native 2K-N qmllint capability missing")
    if ready.get("sourceWritable") is not True:
        fail("native 2K-N reviewed source must be writable in acceptance")
    if not str(ready.get("qmllintVersion") or ""):
        fail("native 2K-N must retain qmllint version evidence")

print("ok - Code Workflow 2K-N production Connect preparation integration")
