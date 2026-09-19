#!/usr/bin/env python3
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
ANALYZER = ROOT / "scripts/code-workflow/analyze.py"


def fail(message: str) -> None:
    raise SystemExit("FAIL: " + message)


def run(*args: str):
    return subprocess.run(
        [sys.executable, str(ANALYZER), *args],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )


source = ANALYZER.read_text(encoding="utf-8")
for forbidden in ("curl ", "wget ", "npm ", "node ", "subprocess."):
    if forbidden in source:
        fail("production analyzer must not download/build/spawn tooling: " + forbidden)
if "write_text(" in source or "write_bytes(" in source:
    fail("production analyzer must not write source")

missing = run(
    "--root", str(ROOT),
    "--path", "modules/bar/Media.qml",
    "--grammar", str(ROOT / ".definitely-missing-qmljs.so"),
)
if missing.returncode != 3:
    fail("missing grammar must return capability-unavailable exit 3")
try:
    missing_payload = json.loads(missing.stdout)
except json.JSONDecodeError as exc:
    fail("missing grammar result is not JSON: " + str(exc))
if missing_payload.get("protocol") != 1:
    fail("analyzer protocol must be version 1")
if missing_payload.get("status") != "unavailable":
    fail("missing grammar must report unavailable")
if missing_payload.get("reason") != "grammar-missing":
    fail("missing grammar reason drifted")

escaped = run(
    "--root", str(ROOT),
    "--path", "../outside.qml",
    "--grammar", str(ROOT / ".definitely-missing-qmljs.so"),
)
if escaped.returncode != 4:
    fail("path escape must be rejected before parser capability checks")
escaped_payload = json.loads(escaped.stdout)
if escaped_payload.get("status") != "invalid-request":
    fail("path escape must report invalid-request")
if "escapes runtime root" not in escaped_payload.get("reason", ""):
    fail("path escape reason must remain explicit")

wrong_type = run(
    "--root", str(ROOT),
    "--path", "README.md",
    "--grammar", str(ROOT / ".definitely-missing-qmljs.so"),
)
if wrong_type.returncode != 4:
    fail("non-QML source must be rejected")

service = (ROOT / "services/CodeWorkflowAnalyzer.qml").read_text(encoding="utf-8")
page = (ROOT / "modules/settings/CodeWorkflow.qml").read_text(encoding="utf-8")
qmldir = (ROOT / "services/qmldir").read_text(encoding="utf-8")

for token in (
    "singleton CodeWorkflowAnalyzer 1.0 CodeWorkflowAnalyzer.qml",
):
    if token not in qmldir:
        fail("services/qmldir missing analyzer singleton")

for token in (
    'property string status: "idle"',
    'Quickshell.shellPath("scripts/code-workflow/analyze.py")',
    '"--path", nextPath',
    'payload?.status === "unavailable"',
    "StdioCollector",
):
    if token not in service:
        fail("analyzer service missing " + token)

for token in (
    "CodeWorkflowAnalyzer.request(root.sourcePath, false)",
    "CodeWorkflowAnalyzer.request(root.sourcePath, true)",
    "CodeWorkflowAnalyzer.entryCount",
    "CodeWorkflowAnalyzer.diagnostics.length",
):
    if token not in page:
        fail("Code Workflow page missing analyzer integration " + token)

payload = subprocess.run(
    [sys.executable, str(ROOT / "sdata/lib/runtime-payload.py"), "list", "--root", str(ROOT)],
    cwd=ROOT,
    text=True,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    check=True,
).stdout.splitlines()
runtime_paths = set(payload)

for required in (
    "scripts/code-workflow/analyze.py",
    "scripts/code-workflow/native.py",
    "scripts/code-workflow/semantics.py",
):
    if required not in runtime_paths:
        fail("production parser core missing from runtime payload: " + required)

for excluded in (
    "scripts/code-workflow/GraphSandbox.qml",
    "scripts/code-workflow/build-parser.sh",
    "scripts/code-workflow/corpus.py",
    "scripts/code-workflow/run-runtime.py",
    "scripts/code-workflow/runtime/PickerProbe.qml",
    "scripts/code-workflow/virtual-pointer.c",
):
    if excluded in runtime_paths:
        fail("Phase 0 harness leaked into runtime payload: " + excluded)

print("ok - Code Workflow parser process boundary and runtime payload contract")
