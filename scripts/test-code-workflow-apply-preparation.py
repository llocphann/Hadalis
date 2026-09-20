#!/usr/bin/env python3
import json
import os
from pathlib import Path
import stat
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SCRIPT_DIR = ROOT / "scripts/code-workflow"
sys.path.insert(0, str(SCRIPT_DIR))

import apply as workflow_apply


def fail(message: str) -> None:
    raise SystemExit("FAIL: " + message)


with tempfile.TemporaryDirectory() as directory:
    root = Path(directory)
    tracked = root / "Tracked.qml"
    original = b"Item { property bool flag: false }\n"
    candidate = b"Item { property bool flag: true }\n"
    tracked.write_bytes(original)

    artifacts = workflow_apply.write_prepared_artifacts(
        root / "state",
        "Tracked.qml",
        workflow_apply.sha256(original).hexdigest(),
        workflow_apply.sha256(candidate).hexdigest(),
        "semantic-flag",
        "true",
        original,
        candidate,
    )

    snapshot = Path(artifacts["snapshotPath"])
    proposed = Path(artifacts["candidatePath"])
    manifest = Path(artifacts["manifestPath"])

    if tracked.read_bytes() != original:
        fail("Apply preparation must not modify tracked source")
    if snapshot.read_bytes() != original:
        fail("rollback snapshot bytes drifted")
    if proposed.read_bytes() != candidate:
        fail("candidate artifact bytes drifted")

    for path in (snapshot, proposed, manifest):
        mode = stat.S_IMODE(path.stat().st_mode)
        if mode != 0o600:
            fail(f"prepared artifact must be mode 0600: {path} -> {oct(mode)}")

    metadata = json.loads(manifest.read_text(encoding="utf-8"))
    if metadata.get("semanticAnchor") != "semantic-flag":
        fail("manifest semantic anchor drifted")
    if metadata.get("applyEnabled") is not False:
        fail("prepared artifact manifest must not authorize Apply")

apply_source = (SCRIPT_DIR / "apply.py").read_text(encoding="utf-8")
service = (ROOT / "services/CodeWorkflowTransaction.qml").read_text(encoding="utf-8")
page = (ROOT / "modules/settings/CodeWorkflow.qml").read_text(encoding="utf-8")
phase2 = (ROOT / "docs/CODE_WORKFLOW_PHASE2.md").read_text(encoding="utf-8")

for token in (
    "def write_prepared_artifacts(",
    "snapshot.qml",
    "candidate.qml",
    "manifest.json",
    "os.chmod(temp_path, mode)",
    '"status": "prepared-artifacts"',
    '"applyEnabled": False',
    "preview-candidate-drift",
    "candidate-semantic-rebind-unresolved",
):
    if token not in apply_source:
        fail("Apply preparation helper missing " + token)

for token in (
    "readonly property bool applyArtifactsReady:",
    "readonly property bool prepareApplyEnabled:",
    "function prepareApplyArtifacts(): bool",
    "function finishApplyPreparation(exitCode: int): void",
    'Quickshell.shellPath("scripts/code-workflow/apply.py")',
    'Quickshell.statePath("code-workflow/transactions")',
    'reloadState.pendingApplyPhase = "artifacts-prepared"',
    'property string pendingApplySnapshotPath: ""',
    'property string pendingApplyCandidatePath: ""',
    'property string pendingApplyManifestPath: ""',
    "function _invalidateApplyHandoff(): void",
    "root._showCommand(root.activeCommand)",
):
    if token not in service:
        fail("Apply preparation service missing " + token)

for token in (
    'mainText: "Prepare Apply"',
    "CodeWorkflowTransaction.prepareApplyArtifacts()",
    '"ARTIFACTS READY"',
    '"source QML is still unchanged until Apply"',
):
    if token not in page:
        fail("Apply preparation UI missing " + token)

for token in (
    "readonly property bool applyCommandMatchesHandoff:",
    "readonly property bool applyEnabled:",
    "root.applyLifecycleReady",
):
    if token not in service:
        fail("Apply enablement must remain downstream of exact artifact preparation: " + token)

payload = subprocess.run(
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
if "scripts/code-workflow/apply.py" not in set(payload):
    fail("Apply preparation helper must ship in runtime payload")

if (
    "Source QML remains" not in phase2
    or "unchanged until the separate Apply action" not in phase2
):
    fail("Phase 2 status must document non-writing Apply preparation")

print("ok - Code Workflow exact Apply preparation artifact contract")
