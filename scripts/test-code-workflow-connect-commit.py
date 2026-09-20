#!/usr/bin/env python3
from hashlib import sha256
import json
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SCRIPT_DIR = ROOT / "scripts/code-workflow"
sys.path.insert(0, str(SCRIPT_DIR))

import connect_commit
import connect_cycle
import connect_prepare
import connect_qualify
import connect_type


def fail(message: str) -> None:
    raise SystemExit("FAIL: " + message)


def digest(data: bytes) -> str:
    return sha256(data).hexdigest()


with tempfile.TemporaryDirectory(prefix="hadalis-connect-commit-") as directory:
    root = Path(directory) / "runtime"
    state = Path(directory) / "state" / "tx"
    source_path = root / "modules" / "Test.qml"
    config_path = root / "modules" / "Config.qml"
    source_path.parent.mkdir(parents=True)
    state.mkdir(parents=True)

    original = (
        b"import QtQuick\n"
        b"Item {\n"
        b"    id: root\n"
        b"    property bool flag: true\n"
        b"}\n"
    )
    candidate = (
        b"import QtQuick\n"
        b"Item {\n"
        b"    id: root\n"
        b"    property bool flag: true\n"
        b"    visible: root.flag\n"
        b"}\n"
    )
    config = b"pragma Singleton\nQtObject { property bool verbose: true }\n"
    source_path.write_bytes(original)
    config_path.write_bytes(config)

    snapshot_path = state / "snapshot.qml"
    candidate_path = state / "candidate.qml"
    manifest_path = state / "manifest.json"
    snapshot_path.write_bytes(original)
    candidate_path.write_bytes(candidate)

    manifest = {
        "version": 1,
        "commandKind": "connect-binding",
        "artifactProof": connect_prepare.ARTIFACT_PROOF,
        "qualificationProof": connect_qualify.QUALIFICATION_PROOF,
        "typeCompatibilityProof": connect_type.TYPE_PROOF,
        "cycleSafetyProof": connect_cycle.PROVEN_ACYCLIC_CROSS_FILE,
        "writeAuthorized": False,
        "applyEnabled": False,
        "artifactsStaged": True,
        "productionIntegrated": False,
        "sourcePath": "modules/Test.qml",
        "baseSha256": digest(original),
        "candidateSha256": digest(candidate),
        "parentSemanticAnchor": "parent-anchor",
        "insertedSemanticAnchor": "inserted-anchor",
        "bindingName": "visible",
        "expression": "root.flag",
        "externalSourcePath": "modules/Config.qml",
        "externalSourceSha256": digest(config),
        "snapshotPath": str(snapshot_path),
        "candidatePath": str(candidate_path),
    }
    manifest_path.write_text(
        json.dumps(manifest, indent=2) + "\n",
        encoding="utf-8",
    )

    committed = connect_commit.commit_connect_prepared(root, manifest_path)
    if committed.get("status") != "written":
        fail("qualified Connect manifest must commit source atomically")
    if committed.get("sourceWritten") is not True:
        fail("successful Connect commit must report sourceWritten=true")
    if committed.get("rollbackRequired") is not False:
        fail("fresh dependency must not require rollback")
    if committed.get("dependencyState") != "fresh":
        fail("successful Connect commit must retain fresh Config dependency")
    if source_path.read_bytes() != candidate:
        fail("Connect commit candidate bytes drifted")
    if config_path.read_bytes() != config:
        fail("Connect commit must never write external Config dependency")

    verified = connect_commit.verify_connect_prepared(root, manifest_path)
    if verified.get("status") != "verified":
        fail("Connect verify protocol status drifted")
    if verified.get("sourceState") != "candidate-present":
        fail("Connect verify must report candidate-present after commit")
    if verified.get("dependencyState") != "fresh":
        fail("Connect verify must retain fresh external dependency")

    rolled_back = connect_commit.rollback_connect_prepared(root, manifest_path)
    if rolled_back.get("status") != "rolled-back":
        fail("Connect rollback must restore exact snapshot")
    if source_path.read_bytes() != original:
        fail("Connect rollback snapshot bytes drifted")
    if config_path.read_bytes() != config:
        fail("Connect rollback must not touch Config")

    config_path.write_bytes(
        b"pragma Singleton\nQtObject { property bool verbose: false }\n"
    )
    blocked = connect_commit.commit_connect_prepared(root, manifest_path)
    if blocked.get("status") != "conflict":
        fail("stale external dependency must block Connect write")
    if blocked.get("reason") != "external-source-sha-mismatch-before-write":
        fail("pre-write external dependency conflict reason drifted")
    if blocked.get("sourceWritten") is not False:
        fail("pre-write Config conflict must not write source")
    if source_path.read_bytes() != original:
        fail("pre-write Config conflict changed source")

    config_path.write_bytes(config)
    post_write_config = (
        b"pragma Singleton\nQtObject { property bool verbose: false }\n"
    )

    def mutate_external_after_write():
        config_path.write_bytes(post_write_config)

    drifted = connect_commit.commit_connect_prepared(
        root,
        manifest_path,
        post_write_hook=mutate_external_after_write,
    )
    if drifted.get("status") != "dependency-drift-after-write":
        fail("post-write Config drift must be detected")
    if drifted.get("sourceWritten") is not True:
        fail("post-write dependency race must report source was written")
    if drifted.get("rollbackRequired") is not True:
        fail("post-write dependency race must require rollback")
    if source_path.read_bytes() != candidate:
        fail("post-write dependency race candidate state drifted")

    recovered = connect_commit.rollback_connect_prepared(root, manifest_path)
    if recovered.get("status") != "rolled-back":
        fail("dependency race must allow exact source rollback")
    if source_path.read_bytes() != original:
        fail("dependency race rollback failed to restore source")
    if config_path.read_bytes() != post_write_config:
        fail("rollback must preserve external Config edit")


helper = (SCRIPT_DIR / "connect_commit.py").read_text(encoding="utf-8")
transaction = (
    ROOT / "services/CodeWorkflowTransaction.qml"
).read_text(encoding="utf-8")
page = (ROOT / "modules/settings/CodeWorkflow.qml").read_text(encoding="utf-8")
phase2 = (ROOT / "docs/CODE_WORKFLOW_PHASE2.md").read_text(encoding="utf-8")
exclusions = json.loads(
    (ROOT / "sdata/runtime-exclusions.json").read_text(encoding="utf-8")
)

for token in (
    "def load_connect_manifest(",
    "def commit_connect_prepared(",
    "def verify_connect_prepared(",
    "def rollback_connect_prepared(",
    '"external-source-sha-mismatch-before-write"',
    '"dependency-drift-after-write"',
    '"external-source-changed-after-source-write"',
    '"rollbackRequired": True',
    "atomic_replace_if_hash(",
    '"candidate-present"',
    '"base-present"',
    '"diverged"',
):
    if token not in helper:
        fail("2K-O Connect lifecycle proof helper missing " + token)

for forbidden in (
    "external_path.write_text(",
    "external_path.write_bytes(",
    "atomic_replace_if_hash(external",
    "os.replace(external",
):
    if forbidden in helper:
        fail("2K-O must never write the retained Config dependency: " + forbidden)

if 'Quickshell.shellPath("scripts/code-workflow/connect_commit.py")' in transaction:
    fail("2K-O lifecycle proof must remain outside production transaction")
if "Connect Apply" in page or "Apply Connect" in page:
    fail("2K-O must not expose user-facing Connect Apply")

for token in (
    'String(root.activeCommand?.kind ?? "") === "literal-property"',
    'if (String(command.kind ?? "") !== "literal-property")',
    "if (!root.applyEnabled)",
):
    if token not in transaction:
        fail("2K-O must preserve literal-only production Apply")

if "scripts/code-workflow/connect_commit.py" not in exclusions.get(
        "excludedPaths", []):
    fail("2K-O lifecycle proof helper must remain outside runtime payload")

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
if "scripts/code-workflow/connect_commit.py" in set(runtime_payload):
    fail("2K-O lifecycle proof helper leaked into runtime payload")

for token in (
    "Milestone 2K-O — isolated Connect commit/rollback engine",
    "dependency-drift-after-write",
    "Config",
    "rollback",
    "user-facing Connect Apply remains unavailable",
):
    if token not in phase2:
        fail("2K-O documentation missing " + token)

print("ok - Code Workflow 2K-O isolated Connect commit/rollback engine")
