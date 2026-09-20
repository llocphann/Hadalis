#!/usr/bin/env python3
from hashlib import sha256
import json
import os
from pathlib import Path
import shutil
import stat
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SCRIPT_DIR = ROOT / "scripts/code-workflow"
sys.path.insert(0, str(SCRIPT_DIR))

import signal_action
import signal_action_commit
import signal_action_prepare

SERVICE = (ROOT / "services/CodeWorkflowTransaction.qml").read_text(encoding="utf-8")
PAGE = (ROOT / "modules/settings/CodeWorkflow.qml").read_text(encoding="utf-8")
PHASE2 = (ROOT / "docs/CODE_WORKFLOW_PHASE2.md").read_text(encoding="utf-8")
EXCLUSIONS = json.loads(
    (ROOT / "sdata/runtime-exclusions.json").read_text(encoding="utf-8")
)


def fail(message: str) -> None:
    raise SystemExit("FAIL: " + message)


def mode(path: Path) -> int:
    return stat.S_IMODE(path.stat().st_mode)


for path in (
    "scripts/code-workflow/signal_action.py",
    "scripts/code-workflow/signal_action_prepare.py",
    "scripts/code-workflow/signal_action_commit.py",
):
    if path in set(EXCLUSIONS.get("excludedPaths", [])):
        fail("2K-W-C promoted helper is still runtime-excluded: " + path)
    if path not in SERVICE:
        fail("2K-W-C transaction service must reference helper: " + path)
    if path in PAGE:
        fail("Settings must never invoke signal/action Python helper directly: " + path)

for token in (
    'ARTIFACT_PROOF = "prepared-reviewed-signal-action-artifacts-v1"',
    'POSTCONDITION = "inserted-handler-rebound-exact-action"',
    "def prepare_reviewed_signal_action_artifacts(",
    '"writeAuthorized": False',
    '"applyEnabled": False',
    '"artifactsStaged": True',
    '"productionIntegrated": False',
):
    if token not in (SCRIPT_DIR / "signal_action_prepare.py").read_text(encoding="utf-8"):
        fail("2K-W-B preparation missing " + token)

for token in (
    "def load_signal_action_manifest(",
    "def commit_signal_action(",
    "def verify_signal_action(",
    "def rollback_signal_action(",
    "atomic_replace_if_hash(",
    '"candidate-present"',
    '"base-present"',
):
    if token not in (SCRIPT_DIR / "signal_action_commit.py").read_text(encoding="utf-8"):
        fail("2K-W-B atomic engine missing " + token)

for source in (
    (SCRIPT_DIR / "signal_action_prepare.py").read_text(encoding="utf-8"),
    (SCRIPT_DIR / "signal_action_commit.py").read_text(encoding="utf-8"),
):
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
        if forbidden in source:
            fail("W-B inherited unrelated data-binding proof: " + forbidden)

for token in (
    "Milestone 2K-W-B — isolated reviewed signal/action transaction",
    "prepared-reviewed-signal-action-artifacts-v1",
    "inserted-handler-rebound-exact-action",
    "Apply remains unavailable",
):
    if token not in PHASE2:
        fail("2K-W-B documentation missing " + token)


def native_proof() -> None:
    grammar = os.environ.get("HADALIS_WORKFLOW_GRAMMAR", "")
    library = os.environ.get("HADALIS_TREE_SITTER_LIBRARY", "")
    if not grammar or not Path(grammar).is_file():
        print("note - native W-B signal/action transaction skipped: grammar unavailable")
        return

    source_path = ROOT / "modules/bar/Media.qml"
    source = source_path.read_bytes()
    preview, candidate = signal_action.build_reviewed_signal_action_preview(
        ROOT,
        "bar/media",
        signal_action.REVIEWED_TARGET_ID,
        grammar,
        library,
    )
    if preview.get("status") != "preview" or candidate is None:
        fail("W-B prerequisite W-A preview failed: " + repr(preview))

    with tempfile.TemporaryDirectory(prefix="hadalis-signal-action-transaction-") as temporary:
        temp = Path(temporary)
        runtime = temp / "runtime"
        media = runtime / "modules/bar/Media.qml"
        manifest = runtime / "defaults/code-workflow-ir.json"
        media.parent.mkdir(parents=True)
        manifest.parent.mkdir(parents=True)
        shutil.copy2(source_path, media)
        shutil.copy2(ROOT / "defaults/code-workflow-ir.json", manifest)
        state_dir = temp / "state"

        prepared = signal_action_prepare.prepare_reviewed_signal_action_artifacts(
            runtime,
            "bar/media",
            signal_action.REVIEWED_TARGET_ID,
            preview["baseSha256"],
            preview["candidateSha256"],
            preview["parentSemanticAnchor"],
            preview["existingActionSemanticAnchor"],
            preview["insertedHandlerSemanticAnchor"],
            state_dir,
            grammar,
            library,
        )
        if prepared.get("status") != "prepared-signal-action-artifacts":
            fail("W-B preparation failed: " + repr(prepared))
        if media.read_bytes() != source:
            fail("W-B preparation modified source")
        if prepared.get("artifactProof") != "prepared-reviewed-signal-action-artifacts-v1":
            fail("W-B artifact proof drifted")
        if prepared.get("postcondition") != "inserted-handler-rebound-exact-action":
            fail("W-B postcondition drifted")
        if prepared.get("writeAuthorized") is not False:
            fail("W-B artifacts unexpectedly authorize writes")
        if prepared.get("applyEnabled") is not False:
            fail("W-B artifacts unexpectedly enable Apply")
        if prepared.get("productionIntegrated") is not False:
            fail("W-B artifacts unexpectedly claim production integration")

        manifest_path = Path(prepared["manifestPath"])
        snapshot_path = Path(prepared["snapshotPath"])
        candidate_path = Path(prepared["candidatePath"])
        for artifact in (manifest_path, snapshot_path, candidate_path):
            if mode(artifact) != 0o600:
                fail("W-B artifact must be mode 0600: " + artifact.name)
        if snapshot_path.read_bytes() != source:
            fail("W-B snapshot bytes drifted")
        if candidate_path.read_bytes() != candidate:
            fail("W-B candidate bytes drifted")
        if sha256(manifest_path.read_bytes()).hexdigest() != prepared["manifestSha256"]:
            fail("W-B manifest SHA drifted")

        committed = signal_action_commit.commit_signal_action(
            runtime, manifest_path, prepared["manifestSha256"]
        )
        if committed.get("status") != "written":
            fail("W-B atomic commit failed: " + repr(committed))
        if media.read_bytes() != candidate:
            fail("W-B commit did not write exact candidate")

        verified = signal_action_commit.verify_signal_action(
            runtime, manifest_path, prepared["manifestSha256"]
        )
        if verified.get("status") != "verified" or verified.get("sourceState") != "candidate-present":
            fail("W-B candidate verify failed: " + repr(verified))

        rolled_back = signal_action_commit.rollback_signal_action(
            runtime, manifest_path, prepared["manifestSha256"]
        )
        if rolled_back.get("status") != "rolled-back":
            fail("W-B rollback failed: " + repr(rolled_back))
        if media.read_bytes() != source:
            fail("W-B rollback did not restore exact snapshot")

        manifest_before = manifest_path.read_bytes()
        manifest_path.write_bytes(manifest_before + b"\n")
        try:
            signal_action_commit.commit_signal_action(
                runtime, manifest_path, prepared["manifestSha256"]
            )
        except ValueError as exc:
            if "manifest hash mismatch" not in str(exc):
                raise
        else:
            fail("W-B manifest drift must fail before source write")
        if media.read_bytes() != source:
            fail("W-B manifest drift modified source")
        manifest_path.write_bytes(manifest_before)

        media.write_bytes(source + b"\n// external edit\n")
        conflict = signal_action_commit.commit_signal_action(
            runtime, manifest_path, prepared["manifestSha256"]
        )
        if conflict.get("status") != "conflict" or conflict.get("sourceWritten") is not False:
            fail("W-B external source edit must conflict")
        if not media.read_bytes().endswith(b"// external edit\n"):
            fail("W-B conflict overwrote external source edit")


native_proof()
print("ok - Code Workflow 2K-W-B isolated reviewed signal/action transaction proof")
