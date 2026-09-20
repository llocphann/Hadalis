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

import binding_commit
import binding_prepare
from native import Parser, verify_ranges
from semantics import extract
from transaction import digest, prepare_binding_patch

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
        print(
            "note - native binding replacement artifact proof skipped: "
            "grammar unavailable"
        )
        return

    source_path = ROOT / "modules/bar/ClockWidget.qml"
    source = source_path.read_bytes()
    base_sha = digest(source)

    parser = Parser(Path(grammar), library or None)
    try:
        with parser.parse(source) as (_, nodes):
            verify_ranges(source, nodes)
            semantic = extract(
                "modules/bar/ClockWidget.qml", source, nodes
            )
    finally:
        parser.close()

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
        if rendered == "DateTime.timeDisplay":
            matches.append(entry)
    if len(matches) != 1:
        fail("real Clock time binding must resolve exactly once")
    entry = matches[0]
    if not entry.get("anchor_unique", False):
        fail("real Clock time semantic anchor must be unique")

    preview, candidate = prepare_binding_patch(
        source,
        base_sha,
        entry,
        "DateTime.date",
    )
    if preview.get("status") != "candidate" or candidate is None:
        fail("real Clock time binding must produce replacement candidate")
    candidate_sha = digest(candidate)

    with tempfile.TemporaryDirectory(
        prefix="hadalis-binding-transaction-"
    ) as temporary:
        temp = Path(temporary)
        runtime = temp / "runtime"
        clock = runtime / "modules/bar/ClockWidget.qml"
        clock.parent.mkdir(parents=True)
        shutil.copy2(source_path, clock)
        state_dir = temp / "state"

        prepared = binding_prepare.prepare_reviewed_binding_artifacts(
            root=runtime,
            replacement_id="clock.text.time-to-date",
            base_sha256=base_sha,
            expected_candidate_sha256=candidate_sha,
            semantic_anchor=str(entry["anchor"]),
            state_dir=state_dir,
            grammar_path=grammar,
            tree_sitter_library=library,
        )
        if prepared.get("status") != (
            "prepared-binding-replacement-artifacts"
        ):
            fail(
                "real reviewed binding preparation failed: "
                + repr(prepared)
            )
        if clock.read_bytes() != source:
            fail("binding preparation must not modify tracked source")
        if prepared.get("artifactProof") != (
            "prepared-reviewed-binding-replacement-artifacts-v1"
        ):
            fail("binding artifact proof token drifted")
        if prepared.get("reviewedReplacementId") != (
            "clock.text.time-to-date"
        ):
            fail("binding preparation escaped first reviewed replacement")
        if prepared.get("propertyName") != "text":
            fail("binding property identity drifted")
        if prepared.get("expectedCurrent") != "DateTime.timeDisplay":
            fail("binding current expression identity drifted")
        if prepared.get("replacement") != "DateTime.date":
            fail("binding replacement expression identity drifted")
        if prepared.get("postcondition") != (
            "semantic-anchor-rebound-exact-expression"
        ):
            fail("binding replacement postcondition drifted")
        if prepared.get("candidatePostcondition", {}).get(
            "status"
        ) != "resolved":
            fail("prepared candidate must preserve semantic anchor")
        if prepared.get("candidateExpression") != "DateTime.date":
            fail("prepared candidate must prove exact replacement value")
        for forbidden in (
            "qualificationProof",
            "typeCompatibilityProof",
            "cycleSafetyProof",
            "typeCompatibility",
            "cycleStatus",
        ):
            if forbidden in prepared:
                fail(
                    "binding artifacts must not inherit Connect proof: "
                    + forbidden
                )

        manifest_path = Path(prepared["manifestPath"])
        snapshot_path = Path(prepared["snapshotPath"])
        candidate_path = Path(prepared["candidatePath"])
        for artifact in (manifest_path, snapshot_path, candidate_path):
            if mode(artifact) != 0o600:
                fail(
                    "binding artifact must be mode 0600: "
                    + artifact.name
                )
        if sha256(manifest_path.read_bytes()).hexdigest() != (
            prepared["manifestSha256"]
        ):
            fail("binding manifest SHA handoff drifted")
        if snapshot_path.read_bytes() != source:
            fail("binding snapshot bytes drifted")
        if candidate_path.read_bytes() != candidate:
            fail("binding candidate bytes drifted")

        committed = binding_commit.commit_binding(
            runtime,
            manifest_path,
            prepared["manifestSha256"],
        )
        if committed.get("status") != "written":
            fail("binding atomic commit failed: " + repr(committed))
        if clock.read_bytes() != candidate:
            fail("binding commit did not write exact candidate")

        verified = binding_commit.verify_binding(
            runtime,
            manifest_path,
            prepared["manifestSha256"],
        )
        if (
            verified.get("status") != "verified"
            or verified.get("sourceState") != "candidate-present"
        ):
            fail("binding candidate verify failed: " + repr(verified))

        rolled_back = binding_commit.rollback_binding(
            runtime,
            manifest_path,
            prepared["manifestSha256"],
        )
        if rolled_back.get("status") != "rolled-back":
            fail("binding rollback failed: " + repr(rolled_back))
        if clock.read_bytes() != source:
            fail("binding rollback did not restore exact snapshot")

        manifest_before = manifest_path.read_bytes()
        manifest_path.write_bytes(manifest_before + b"\n")
        try:
            binding_commit.commit_binding(
                runtime,
                manifest_path,
                prepared["manifestSha256"],
            )
        except ValueError as exc:
            if "manifest hash mismatch" not in str(exc):
                raise
        else:
            fail("binding manifest drift must fail before source write")
        if clock.read_bytes() != source:
            fail("manifest drift failure modified source")
        manifest_path.write_bytes(manifest_before)

        clock.write_bytes(source + b"\n// external edit\n")
        conflict = binding_commit.commit_binding(
            runtime,
            manifest_path,
            prepared["manifestSha256"],
        )
        if (
            conflict.get("status") != "conflict"
            or conflict.get("sourceWritten") is not False
        ):
            fail(
                "binding stale source must conflict before replacement"
            )
        if not clock.read_bytes().endswith(b"// external edit\n"):
            fail("binding conflict overwrote external source edit")


PREPARE_SOURCE = (
    SCRIPT_DIR / "binding_prepare.py"
).read_text(encoding="utf-8")
for token in (
    'ARTIFACT_PROOF = "prepared-reviewed-binding-replacement-artifacts-v1"',
    'POSTCONDITION = "semantic-anchor-rebound-exact-expression"',
    '"clock.text.time-to-date": {',
    '"sourcePath": "modules/bar/ClockWidget.qml"',
    '"propertyName": "text"',
    '"expectedCurrent": "DateTime.timeDisplay"',
    '"replacement": "DateTime.date"',
    "prepare_reviewed_binding_artifacts(",
    "prepare_binding_patch(",
    '"replacement-semantic-anchor-did-not-rebind"',
    "candidatePostcondition",
    "source-changed-after-artifact-preparation",
):
    if token not in PREPARE_SOURCE:
        fail("2K-U-A binding preparation missing " + token)

COMMIT_SOURCE = (
    SCRIPT_DIR / "binding_commit.py"
).read_text(encoding="utf-8")
for token in (
    "def load_binding_manifest(",
    '"prepared binding manifest hash mismatch"',
    "def commit_binding(",
    "def verify_binding(",
    "def rollback_binding(",
    "atomic_replace_if_hash(",
    '"candidate-present"',
    '"base-present"',
):
    if token not in COMMIT_SOURCE:
        fail("2K-U-A binding atomic engine missing " + token)

for forbidden in (
    "qualificationProof",
    "typeCompatibilityProof",
    "cycleSafetyProof",
    "connect_type",
    "connect_cycle",
    "connect_qualify",
):
    if forbidden in COMMIT_SOURCE:
        fail(
            "binding engine must not inherit Connect proof stack: "
            + forbidden
        )

# 2K-U-A proves the isolated engine semantics independently of the later U-B
# runtime promotion. Runtime inclusion/wiring is owned by the U-B contract.

if "Milestone 2K-U-A — isolated reviewed direct-binding replacement" not in PHASE2:
    fail("Phase 2 status must document 2K-U-A")
if "clock.text.time-to-date" not in PHASE2:
    fail("Phase 2 status must identify reviewed replacement")
native_proof()
print(
    "ok - Code Workflow 2K-U-A isolated reviewed "
    "direct-binding replacement transaction proof"
)
