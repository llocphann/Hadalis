#!/usr/bin/env python3
import json
import os
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
SCRIPT_DIR = ROOT / "scripts/code-workflow"
sys.path.insert(0, str(SCRIPT_DIR))

import signal_action

IR = json.loads(
    (ROOT / "defaults/code-workflow-ir.json").read_text(encoding="utf-8")
)
HELPER = (
    SCRIPT_DIR / "signal_action.py"
).read_text(encoding="utf-8")
SERVICE = (
    ROOT / "services/CodeWorkflowTransaction.qml"
).read_text(encoding="utf-8")
PAGE = (
    ROOT / "modules/settings/CodeWorkflow.qml"
).read_text(encoding="utf-8")
PHASE2 = (
    ROOT / "docs/CODE_WORKFLOW_PHASE2.md"
).read_text(encoding="utf-8")
EXCLUSIONS = json.loads(
    (ROOT / "sdata/runtime-exclusions.json").read_text(encoding="utf-8")
)


def fail(message: str) -> None:
    raise SystemExit("FAIL: " + message)


media = (IR.get("graphs") or {}).get("bar/media") or {}
targets = [
    item for item in (media.get("signalActionTargets") or [])
    if item.get("id") == "media.signal.doubleClickToggle"
]
if len(targets) != 1:
    fail("2K-W-A reviewed signal/action target must resolve exactly once")
target = targets[0]
expected = {
    "eventNodeId": "media.input",
    "actionNodeId": "media.toggle",
    "sourcePath": "modules/bar/Media.qml",
    "parentObjectNeedle": "id: mediaInput",
    "handlerName": "onDoubleClicked",
    "signalName": "doubleClicked",
    "actionFunctionNeedle": "function toggleExpanded(): void",
    "actionFunctionName": "toggleExpanded",
    "actionExpression": "root.toggleExpanded()",
    "reviewedParentSemanticKind": "object",
    "reviewedActionSemanticKind": "function",
    "insertedSemanticKind": "handler-candidate",
    "insertedValueKind": "call_expression",
}
for key, value in expected.items():
    if target.get(key) != value:
        fail(f"2K-W-A reviewed target drifted: {key}")
if target.get("previewable") is not False or target.get("editable") is not False:
    fail("2K-W-A target must remain non-authoritative")

for token in (
    'PREVIEW_PROOF = "reviewed-signal-action-preview-v1"',
    'REVIEWED_TARGET_ID = "media.signal.doubleClickToggle"',
    "def load_reviewed_signal_action_target(",
    "def prepare_signal_action_patch(",
    "def build_reviewed_signal_action_preview(",
    '"inserted-signal-handler-not-uniquely-resolved"',
    '"existing-action-source-drifted"',
    '"signalResolution": "reviewed-handler-name"',
    '"actionResolution": "existing-function-anchor-resolved"',
    '"applyEnabled": False',
    '"artifactsStaged": False',
    '"writeAuthorized": False',
    '"productionIntegrated": False',
):
    if token not in HELPER:
        fail("2K-W-A helper missing " + token)

for forbidden in (
    "typeCompatibility",
    "cycleStatus",
    "qualificationProof",
    "typeCompatibilityProof",
    "cycleSafetyProof",
    "connect_type",
    "connect_cycle",
    "connect_qualify",
):
    if forbidden in HELPER:
        fail(
            "2K-W-A signal/action proof must not inherit data-binding proof: "
            + forbidden
        )

helper_path = "scripts/code-workflow/signal_action.py"
if helper_path in set(EXCLUSIONS.get("excludedPaths", [])):
    fail("2K-W-C promoted signal_action.py must ship in runtime payload")
if helper_path not in SERVICE:
    fail("2K-W-C transaction service must invoke signal_action.py")
if helper_path in PAGE:
    fail("Settings must never invoke signal_action.py directly")

for token in (
    "Milestone 2K-W-A — reviewed signal-to-existing-action preview proof",
    "media.signal.doubleClickToggle",
    "onDoubleClicked: root.toggleExpanded()",
    "Apply remains unavailable",
    "no TYPE/CYCLE",
):
    if token not in PHASE2:
        fail("2K-W-A documentation missing " + token)


def native_proof() -> None:
    grammar = os.environ.get("HADALIS_WORKFLOW_GRAMMAR", "")
    library = os.environ.get("HADALIS_TREE_SITTER_LIBRARY", "")
    if not grammar or not Path(grammar).is_file():
        print(
            "note - native signal/action preview proof skipped: "
            "grammar unavailable"
        )
        return

    source_path = ROOT / "modules/bar/Media.qml"
    source_before = source_path.read_bytes()
    if b"onDoubleClicked:" in source_before:
        fail("reviewed W-A source unexpectedly already has onDoubleClicked")

    result, candidate = (
        signal_action.build_reviewed_signal_action_preview(
            ROOT,
            "bar/media",
            "media.signal.doubleClickToggle",
            grammar,
            library,
        )
    )
    if result.get("status") != "preview" or candidate is None:
        fail("native W-A preview failed: " + repr(result))
    if source_path.read_bytes() != source_before:
        fail("W-A preview modified tracked source")
    if result.get("previewProof") != "reviewed-signal-action-preview-v1":
        fail("W-A preview proof token drifted")
    if result.get("commandKind") != "signal-action":
        fail("W-A command kind drifted")
    if result.get("previewMode") != "signal-action":
        fail("W-A preview mode drifted")
    if result.get("insertedSemanticKind") != "handler-candidate":
        fail("W-A inserted semantic kind drifted")
    if result.get("insertedValueKind") != "call_expression":
        fail("W-A inserted value kind drifted")
    if result.get("actionExpression") != "root.toggleExpanded()":
        fail("W-A action expression drifted")
    if result.get("signalResolution") != "reviewed-handler-name":
        fail("W-A signal resolution drifted")
    if result.get("actionResolution") != (
        "existing-function-anchor-resolved"
    ):
        fail("W-A existing action resolution drifted")
    if result.get("parentSemanticRebind", {}).get("status") != "resolved":
        fail("W-A parent semantic anchor did not survive")
    if result.get("existingActionSemanticRebind", {}).get(
        "status"
    ) != "resolved":
        fail("W-A existing action semantic anchor did not survive")
    if not result.get("existingActionSemanticAnchor"):
        fail("W-A existing action semantic anchor missing")
    if not result.get("insertedHandlerSemanticAnchor"):
        fail("W-A inserted handler semantic anchor missing")
    if result.get("applyEnabled") is not False:
        fail("W-A must keep Apply unavailable")
    if result.get("artifactsStaged") is not False:
        fail("W-A must not stage artifacts")
    if result.get("writeAuthorized") is not False:
        fail("W-A must not authorize writes")
    if result.get("productionIntegrated") is not False:
        fail("W-A must remain non-production")
    patch = result.get("patch") or {}
    if patch.get("oldText") != "":
        fail("W-A insertion must be zero-width")
    if patch.get("newText", "").strip() != (
        "onDoubleClicked: root.toggleExpanded()"
    ):
        fail("W-A patch text drifted")
    if candidate.count(
        b"onDoubleClicked: root.toggleExpanded()"
    ) != 1:
        fail("W-A candidate must contain exactly one reviewed handler")
    if candidate.count(b"function toggleExpanded(): void") != 1:
        fail("W-A candidate must preserve the existing action function")
    for forbidden in (
        "typeCompatibility",
        "cycleStatus",
        "qualificationProof",
        "typeCompatibilityProof",
        "cycleSafetyProof",
    ):
        if forbidden in result:
            fail(
                "W-A result inherited unrelated proof field: "
                + forbidden
            )


native_proof()
print(
    "ok - Code Workflow 2K-W-A reviewed signal-to-existing-action "
    "non-writing preview proof"
)
