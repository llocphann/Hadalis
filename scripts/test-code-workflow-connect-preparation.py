#!/usr/bin/env python3
from hashlib import sha256
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

import connect_cycle
import connect_prepare
import connect_qualify
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

for token in (
    'ARTIFACT_PROOF = "prepared-qualified-connect-artifacts-v1"',
    "def prepare_qualified_connect_artifacts(",
    "qualification_runner: QualificationRunner = qualify_reviewed_connect",
    "qualification = qualification_runner(",
    "prepare_connect_binding_patch(",
    '"qualified-candidate-sha-drift"',
    '"prepared-candidate-has-parser-diagnostics"',
    '"prepared-inserted-binding-not-unique"',
    '"source-changed-before-artifact-staging"',
    '"external-source-changed-before-artifact-staging"',
    '"source-changed-during-artifact-staging"',
    '"external-source-changed-during-artifact-staging"',
    "shutil.rmtree(artifact_root, ignore_errors=True)",
    "atomic_state_write(snapshot_path, source)",
    "atomic_state_write(candidate_path, candidate)",
    '"writeAuthorized": False',
    '"applyEnabled": False',
    '"artifactsStaged": True',
    '"productionIntegrated": False',
):
    if token not in helper:
        fail("2K-M Connect artifact preparation helper missing " + token)

for forbidden in (
    "source_path.write_text(",
    "source_path.write_bytes(",
    "os.replace(source_path",
    "setText(",
):
    if forbidden in helper:
        fail("Connect artifact preparation must never write tracked source: " + forbidden)

for token in (
    'String(root.activeCommand?.kind ?? "") === "literal-property"',
    'if (String(command.kind ?? "") !== "literal-property")',
    'blockers.push("write-subset-not-authorized")',
    "if (!root.applyEnabled)",
):
    if token not in transaction:
        fail("2K-M must preserve literal-only Apply isolation: " + token)

if 'Quickshell.shellPath(' not in transaction or (
        '"scripts/code-workflow/connect_prepare.py"' not in transaction):
    fail("2K-N must wire the single production Connect preparation coordinator")
for forbidden_path in (
    "scripts/code-workflow/connect_type.py",
    "scripts/code-workflow/connect_cycle.py",
    "scripts/code-workflow/connect_qualify.py",
):
    if ('Quickshell.shellPath("' + forbidden_path + '")') in transaction:
        fail("transaction must not invoke low-level Connect proof support directly")
if "Prepare Connect Apply" in page:
    fail("Connect source Apply must remain unavailable")

if "scripts/code-workflow/connect_prepare.py" in exclusions.get(
        "excludedPaths", []):
    fail("2K-N production Connect preparation coordinator must ship")

runtime_payload = subprocess.run(
    [sys.executable, str(ROOT / "sdata/lib/runtime-payload.py"),
     "list", "--root", str(ROOT)],
    cwd=ROOT,
    text=True,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    check=True,
).stdout.splitlines()
if "scripts/code-workflow/connect_prepare.py" not in set(runtime_payload):
    fail("production Connect preparation coordinator missing from runtime payload")

try:
    connect_prepare._state_root_outside_runtime(
        ROOT, ROOT / ".connect-artifacts")
except ValueError:
    pass
else:
    fail("Connect artifacts must never be staged inside runtime source tree")

for token in (
    "Milestone 2K-M — qualified Connect artifact preparation proof",
    "prepared-qualified-connect-artifacts-v1",
    "artifactsStaged=true",
    "writeAuthorized=false",
    "source QML remains unchanged",
    "only source-writing command",
):
    if token not in phase2:
        fail("2K-M documentation missing " + token)


grammar = os.environ.get("HADALIS_WORKFLOW_GRAMMAR", "")
library = os.environ.get("HADALIS_TREE_SITTER_LIBRARY", "")
if grammar and Path(grammar).is_file():
    tool = connect_type._find_qmllint("")
    if tool is None:
        fail("native 2K-M acceptance has grammar but qmllint is unavailable")

    source_path = ROOT / target["sourcePath"]
    config_path = ROOT / "modules/common/Config.qml"
    source_before = source_path.read_bytes()
    config_before = config_path.read_bytes()

    with tempfile.TemporaryDirectory(
        prefix="hadalis-connect-prepare-"
    ) as state_directory:
        prepared = connect_prepare.prepare_qualified_connect_artifacts(
            ROOT,
            "bar/clock",
            target["id"],
            Path(state_directory),
            grammar,
            library,
            tool,
        )

        if prepared.get("status") != "prepared-connect-artifacts":
            fail(
                "native 2K-M artifact preparation failed: "
                + json.dumps(prepared, sort_keys=True)
            )
        if prepared.get("artifactProof") != connect_prepare.ARTIFACT_PROOF:
            fail("native 2K-M artifact proof token drifted")
        if prepared.get("qualificationProof") != (
            connect_qualify.QUALIFICATION_PROOF
        ):
            fail("native 2K-M qualification token drifted")
        if prepared.get("typeCompatibilityProof") != connect_type.TYPE_PROOF:
            fail("native 2K-M type proof drifted")
        if prepared.get("cycleSafetyProof") != (
            connect_cycle.PROVEN_ACYCLIC_CROSS_FILE
        ):
            fail("native 2K-M cycle proof drifted")
        if prepared.get("sourceUnchanged") is not True:
            fail("native 2K-M must leave tracked source unchanged")
        if prepared.get("externalSourceReverifiedAtStage") is not True:
            fail("native 2K-M must reverify external dependency before staging")
        if prepared.get("writeAuthorized") is not False:
            fail("2K-M artifacts must not authorize source writes")
        if prepared.get("applyEnabled") is not False:
            fail("2K-M artifacts must not enable Apply")
        if prepared.get("artifactsStaged") is not True:
            fail("2K-M must explicitly report isolated state artifacts staged")
        if prepared.get("productionIntegrated") is not False:
            fail("2K-M must remain outside production transaction integration")

        snapshot = Path(prepared["snapshotPath"])
        candidate = Path(prepared["candidatePath"])
        manifest_path = Path(prepared["manifestPath"])
        for artifact in (snapshot, candidate, manifest_path):
            if not artifact.is_file():
                fail("2K-M prepared artifact missing: " + str(artifact))
            if stat.S_IMODE(artifact.stat().st_mode) != 0o600:
                fail("2K-M prepared artifacts must be mode 0600")

        if snapshot.read_bytes() != source_before:
            fail("2K-M rollback snapshot must equal exact current source bytes")
        candidate_bytes = candidate.read_bytes()
        if sha256(candidate_bytes).hexdigest() != prepared["candidateSha256"]:
            fail("2K-M candidate artifact hash drifted")
        if b"    visible: root.showDate\n" not in candidate_bytes:
            fail("2K-M candidate artifact must contain reviewed Connect binding")

        artifact_manifest = json.loads(
            manifest_path.read_text(encoding="utf-8")
        )
        for key in (
            "sourcePath",
            "baseSha256",
            "candidateSha256",
            "parentSemanticAnchor",
            "insertedSemanticAnchor",
            "externalSourcePath",
            "externalSourceSha256",
        ):
            if artifact_manifest.get(key) != prepared.get(key):
                fail("2K-M manifest identity drifted: " + key)
        if artifact_manifest.get("writeAuthorized") is not False:
            fail("2K-M manifest must retain writeAuthorized=false")
        if artifact_manifest.get("applyEnabled") is not False:
            fail("2K-M manifest must retain applyEnabled=false")
        if artifact_manifest.get("artifactsStaged") is not True:
            fail("2K-M manifest must record isolated artifact staging")

        # Candidate-hash mismatch must fail before any state artifacts are made.
        mismatch_qualification = {
            "status": "proof",
            "qualificationProof": connect_qualify.QUALIFICATION_PROOF,
            "targetId": "bar/clock",
            "connectTargetId": target["id"],
            "sourcePath": prepared["sourcePath"],
            "baseSha256": prepared["baseSha256"],
            "candidateSha256": "d" * 64,
            "parentSemanticAnchor": prepared["parentSemanticAnchor"],
            "targetProperty": prepared["bindingName"],
            "sourceExpression": prepared["expression"],
            "sourcePropertySemanticAnchor":
                prepared["sourcePropertySemanticAnchor"],
            "typeCompatibilityProof": connect_type.TYPE_PROOF,
            "cycleSafetyProof": connect_cycle.PROVEN_ACYCLIC_CROSS_FILE,
            "dependencyPath": prepared["dependencyPath"],
            "externalSourcePath": prepared["externalSourcePath"],
            "externalSourceSha256": prepared["externalSourceSha256"],
            "terminalPropertySemanticAnchor":
                prepared["terminalPropertySemanticAnchor"],
            "proofsComposed": True,
            "sourceReverified": True,
            "externalSourceReverified": True,
            "typeCompatibility": "unknown-unresolved",
            "cycleStatus": "unknown-incomplete-projection",
            "writeAuthorized": False,
            "applyEnabled": False,
            "artifactsStaged": False,
            "productionIntegrated": False,
        }

        def mismatched_runner(*_args, **_kwargs):
            return dict(mismatch_qualification)

        with tempfile.TemporaryDirectory(
            prefix="hadalis-connect-prepare-mismatch-"
        ) as mismatch_directory:
            blocked = connect_prepare.prepare_qualified_connect_artifacts(
                ROOT,
                "bar/clock",
                target["id"],
                Path(mismatch_directory),
                grammar,
                library,
                tool,
                qualification_runner=mismatched_runner,
            )
            if blocked.get("reason") != "qualified-candidate-sha-drift":
                fail("2K-M candidate SHA mismatch must fail closed")
            if blocked.get("artifactsStaged") is not False:
                fail("mismatched qualification must not stage artifacts")
            if any(Path(mismatch_directory).iterdir()):
                fail("mismatched qualification must leave state dir empty")

    if source_path.read_bytes() != source_before:
        fail("2K-M native proof modified tracked Clock source")
    if config_path.read_bytes() != config_before:
        fail("2K-M native proof modified retained Config dependency")

print("ok - Code Workflow 2K-M qualified Connect artifact preparation proof")
