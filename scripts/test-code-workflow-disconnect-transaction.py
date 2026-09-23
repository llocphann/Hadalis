#!/usr/bin/env python3
from hashlib import sha256
import importlib.util
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

import disconnect_commit
import disconnect_prepare
from native import Parser, verify_ranges
from semantics import extract
from transaction import digest, prepare_disconnect_binding_patch

SERVICE = (ROOT / "services/CodeWorkflowTransaction.qml").read_text(
    encoding="utf-8"
)
PAGE = (ROOT / "modules/settings/CodeWorkflow.qml").read_text(
    encoding="utf-8"
)
PHASE2 = (ROOT / "docs/CODE_WORKFLOW_PHASE2.md").read_text(
    encoding="utf-8"
)
EXCLUSIONS = json.loads(
    (ROOT / "sdata/runtime-exclusions.json").read_text(encoding="utf-8")
)


def fail(message: str) -> None:
    raise SystemExit("FAIL: " + message)


def mode(path: Path) -> int:
    return stat.S_IMODE(path.stat().st_mode)


def native_proof() -> None:
    grammar = os.environ.get("HADALIS_WORKFLOW_GRAMMAR", "")
    library = os.environ.get("HADALIS_TREE_SITTER_LIBRARY", "")
    if not grammar or not Path(grammar).is_file():
        print("note - native Disconnect artifact proof skipped: grammar unavailable")
        return

    reviewed = {
        "clock.data.time": "DateTime.timeDisplay",
        "clock.data.date": "DateTime.date",
    }
    source_path = ROOT / "modules/bar/ClockWidget.qml"
    source = source_path.read_bytes()
    base_sha = digest(source)

    parser = Parser(Path(grammar), library or None)
    try:
        with parser.parse(source) as (_, nodes):
            verify_ranges(source, nodes)
            semantic = extract(
                "modules/bar/ClockWidget.qml", source, nodes)
    finally:
        parser.close()

    entries = {}
    for edge_id, expected in reviewed.items():
        matches = []
        for entry in semantic["entries"]:
            if entry.get("kind") != "binding" or entry.get("name") != "text":
                continue
            value_range = entry.get("value_range")
            if not isinstance(value_range, list) or len(value_range) != 2:
                continue
            rendered = source[
                value_range[0]:value_range[1]
            ].decode("utf-8")
            if rendered == expected:
                matches.append(entry)
        if len(matches) != 1:
            fail(f"real reviewed Disconnect binding must resolve exactly once: {edge_id}")
        if not matches[0].get("anchor_unique", False):
            fail(f"real reviewed Disconnect semantic anchor must be unique: {edge_id}")
        entries[edge_id] = matches[0]

    for edge_id, expected in reviewed.items():
        entry = entries[edge_id]
        preview, candidate = prepare_disconnect_binding_patch(
            source,
            base_sha,
            entry,
            expected,
        )
        if preview.get("status") != "candidate" or candidate is None:
            fail(f"real reviewed Disconnect binding must produce candidate: {edge_id}")
        candidate_sha = digest(candidate)

        with tempfile.TemporaryDirectory(
            prefix="hadalis-disconnect-transaction-"
        ) as temporary:
            temp = Path(temporary)
            runtime = temp / "runtime"
            clock = runtime / "modules/bar/ClockWidget.qml"
            clock.parent.mkdir(parents=True)
            shutil.copy2(source_path, clock)
            state_dir = temp / "state"

            prepared = disconnect_prepare.prepare_reviewed_disconnect_artifacts(
                root=runtime,
                edge_id=edge_id,
                base_sha256=base_sha,
                expected_candidate_sha256=candidate_sha,
                semantic_anchor=str(entry["anchor"]),
                state_dir=state_dir,
                grammar_path=grammar,
                tree_sitter_library=library,
            )
            if prepared.get("status") != "prepared-disconnect-artifacts":
                fail("real reviewed Disconnect preparation failed: "
                     + repr(prepared))
            if clock.read_bytes() != source:
                fail("Disconnect preparation must not modify tracked source")
            if prepared.get("artifactProof") != (
                "prepared-reviewed-disconnect-artifacts-v1"
            ):
                fail("Disconnect artifact proof token drifted")
            if prepared.get("reviewedEdgeId") != edge_id:
                fail("Disconnect preparation escaped exact reviewed edge")
            if prepared.get("propertyName") != "text":
                fail("Disconnect property identity drifted")
            if prepared.get("expectedCurrent") != expected:
                fail("Disconnect expression identity drifted")
            if prepared.get("postcondition") != "semantic-anchor-missing":
                fail("Disconnect deletion postcondition drifted")
            if prepared.get("candidatePostcondition", {}).get("status") != "missing":
                fail("prepared Disconnect candidate must prove old anchor absent")
            for forbidden in (
                "qualificationProof",
                "typeCompatibilityProof",
                "cycleSafetyProof",
                "typeCompatibility",
                "cycleStatus",
            ):
                if forbidden in prepared:
                    fail("Disconnect artifacts must not inherit Connect proof: "
                         + forbidden)

            manifest_path = Path(prepared["manifestPath"])
            snapshot_path = Path(prepared["snapshotPath"])
            candidate_path = Path(prepared["candidatePath"])
            for artifact in (manifest_path, snapshot_path, candidate_path):
                if mode(artifact) != 0o600:
                    fail("Disconnect artifact must be mode 0600: "
                         + artifact.name)
            if sha256(manifest_path.read_bytes()).hexdigest() != (
                prepared["manifestSha256"]
            ):
                fail("Disconnect manifest SHA handoff drifted")
            if snapshot_path.read_bytes() != source:
                fail("Disconnect snapshot bytes drifted")
            if candidate_path.read_bytes() != candidate:
                fail("Disconnect candidate bytes drifted")

            committed = disconnect_commit.commit_disconnect(
                runtime,
                manifest_path,
                prepared["manifestSha256"],
            )
            if committed.get("status") != "written":
                fail("Disconnect atomic commit failed: " + repr(committed))
            if clock.read_bytes() != candidate:
                fail("Disconnect commit did not write exact candidate")

            verified = disconnect_commit.verify_disconnect(
                runtime,
                manifest_path,
                prepared["manifestSha256"],
            )
            if (
                verified.get("status") != "verified"
                or verified.get("sourceState") != "candidate-present"
            ):
                fail("Disconnect candidate verify failed: " + repr(verified))

            rolled_back = disconnect_commit.rollback_disconnect(
                runtime,
                manifest_path,
                prepared["manifestSha256"],
            )
            if rolled_back.get("status") != "rolled-back":
                fail("Disconnect rollback failed: " + repr(rolled_back))
            if clock.read_bytes() != source:
                fail("Disconnect rollback did not restore exact snapshot")

            manifest_before = manifest_path.read_bytes()
            manifest_path.write_bytes(manifest_before + b"\n")
            try:
                disconnect_commit.commit_disconnect(
                    runtime,
                    manifest_path,
                    prepared["manifestSha256"],
                )
            except ValueError as exc:
                if "manifest hash mismatch" not in str(exc):
                    raise
            else:
                fail("Disconnect manifest drift must fail before source write")
            if clock.read_bytes() != source:
                fail("manifest drift failure modified source")
            manifest_path.write_bytes(manifest_before)

            clock.write_bytes(source + b"\n// external edit\n")
            conflict = disconnect_commit.commit_disconnect(
                runtime,
                manifest_path,
                prepared["manifestSha256"],
            )
            if (
                conflict.get("status") != "conflict"
                or conflict.get("sourceWritten") is not False
            ):
                fail("Disconnect stale source must conflict before replacement")
            if not clock.read_bytes().endswith(b"// external edit\n"):
                fail("Disconnect conflict overwrote external source edit")


for token in (
    'ARTIFACT_PROOF = "prepared-reviewed-disconnect-artifacts-v1"',
    'POSTCONDITION = "semantic-anchor-missing"',
    '"clock.data.time": {',
    '"clock.data.date": {',
    '"sourcePath": "modules/bar/ClockWidget.qml"',
    '"propertyName": "text"',
    '"expectedCurrent": "DateTime.timeDisplay"',
    '"expectedCurrent": "DateTime.date"',
    "prepare_reviewed_disconnect_artifacts(",
    "prepare_disconnect_binding_patch(",
    '"disconnected-semantic-anchor-still-resolves"',
    "candidatePostcondition",
    "source-changed-after-artifact-preparation",
):
    if token not in Path(
        SCRIPT_DIR / "disconnect_prepare.py"
    ).read_text(encoding="utf-8"):
        fail("2K-T-A Disconnect preparation missing " + token)

COMMIT_SOURCE = Path(
    SCRIPT_DIR / "disconnect_commit.py"
).read_text(encoding="utf-8")
for token in (
    "def load_disconnect_manifest(",
    '"prepared Disconnect manifest hash mismatch"',
    "def commit_disconnect(",
    "def verify_disconnect(",
    "def rollback_disconnect(",
    "atomic_replace_if_hash(",
    '"candidate-present"',
    '"base-present"',
):
    if token not in COMMIT_SOURCE:
        fail("2K-T-A Disconnect atomic engine missing " + token)

for forbidden in (
    "qualificationProof",
    "typeCompatibilityProof",
    "cycleSafetyProof",
    "connect_type",
    "connect_cycle",
    "connect_qualify",
):
    if forbidden in COMMIT_SOURCE:
        fail("Disconnect engine must not inherit Connect proof stack: "
             + forbidden)

for helper in (
    "scripts/code-workflow/disconnect_prepare.py",
    "scripts/code-workflow/disconnect_commit.py",
):
    if helper in PAGE:
        fail("Settings must never invoke Disconnect helper directly: " + helper)

# 2K-T-A proves the engine semantics independently of the later T-B runtime
# promotion. Runtime inclusion/wiring is owned by the T-B contract.

if "Milestone 2K-T-A — isolated reviewed Disconnect transaction proof" not in PHASE2:
    fail("Phase 2 status must document 2K-T-A")
if "clock.data.time" not in PHASE2:
    fail("Phase 2 status must identify the first reviewed Disconnect edge")
if "Milestone 2K-T-C — second exact reviewed Disconnect target" not in PHASE2:
    fail("Phase 2 status must document 2K-T-C")
if "clock.data.date" not in PHASE2:
    fail("Phase 2 status must identify the second exact reviewed Disconnect edge")
if "Disconnect Apply remains unavailable" not in PHASE2:
    fail("2K-T-A must keep user-facing Disconnect Apply unavailable")

native_proof()
print("ok - Code Workflow 2K-T-A isolated reviewed Disconnect transaction proof")
