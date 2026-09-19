#!/usr/bin/env python3
from pathlib import Path
import stat
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SCRIPT_DIR = ROOT / "scripts/code-workflow"
sys.path.insert(0, str(SCRIPT_DIR))

import apply as workflow_apply
import commit as workflow_commit


def fail(message: str) -> None:
    raise SystemExit("FAIL: " + message)


with tempfile.TemporaryDirectory() as directory:
    root = Path(directory) / "runtime"
    state = Path(directory) / "state"
    source_path = root / "modules" / "Test.qml"
    source_path.parent.mkdir(parents=True)
    original = b"Item { property bool flag: false }\n"
    candidate = b"Item { property bool flag: true }\n"
    source_path.write_bytes(original)
    source_path.chmod(0o640)

    artifacts = workflow_apply.write_prepared_artifacts(
        state,
        "modules/Test.qml",
        workflow_apply.sha256(original).hexdigest(),
        workflow_apply.sha256(candidate).hexdigest(),
        "semantic-flag",
        "true",
        original,
        candidate,
    )
    manifest = Path(artifacts["manifestPath"])

    committed = workflow_commit.commit_prepared(root, manifest)
    if committed.get("status") != "written":
        fail("prepared fixture must commit atomically")
    if source_path.read_bytes() != candidate:
        fail("commit engine candidate bytes drifted")
    if stat.S_IMODE(source_path.stat().st_mode) != 0o640:
        fail("atomic commit must preserve source mode")

    verified = workflow_commit.verify_prepared(root, manifest)
    if verified.get("state") != "candidate-present":
        fail("verify must report candidate-present after commit")

    rolled_back = workflow_commit.rollback_prepared(root, manifest)
    if rolled_back.get("status") != "rolled-back":
        fail("prepared fixture must rollback atomically")
    if source_path.read_bytes() != original:
        fail("rollback snapshot bytes drifted")

    source_path.write_bytes(b"Item { property bool flag: true } // external\n")
    conflict = workflow_commit.commit_prepared(root, manifest)
    if conflict.get("status") != "conflict":
        fail("external edit before commit must fail closed")
    external = source_path.read_bytes()
    if b"external" not in external:
        fail("commit conflict must preserve external edit")

    source_path.write_bytes(candidate)
    source_path.write_bytes(
        b"Item { property bool flag: false } // after-apply external\n")
    rollback_conflict = workflow_commit.rollback_prepared(root, manifest)
    if rollback_conflict.get("status") != "conflict":
        fail("rollback must refuse to overwrite a post-Apply external edit")
    if b"after-apply external" not in source_path.read_bytes():
        fail("rollback conflict must preserve post-Apply external edit")

commit_source = (SCRIPT_DIR / "commit.py").read_text(encoding="utf-8")
service = (ROOT / "services/CodeWorkflowTransaction.qml").read_text(
    encoding="utf-8"
)
page = (ROOT / "modules/settings/CodeWorkflow.qml").read_text(
    encoding="utf-8"
)

for token in (
    "def atomic_replace_if_hash(",
    '"source-changed-before-replace"',
    "os.replace(temp_path, source_path)",
    "os.fsync(directory_fd)",
    "def commit_prepared(",
    "def rollback_prepared(",
    "def verify_prepared(",
    '"candidate-present"',
    '"base-present"',
    '"diverged"',
):
    if token not in commit_source:
        fail("atomic commit engine missing " + token)

if "scripts/code-workflow/commit.py" in service:
    fail("isolated commit engine must not be wired to production service yet")
if "readonly property bool applyEnabled: false" not in service:
    fail("Apply must remain disabled while commit engine is isolated")
if "Apply workflow" in page:
    fail("Settings must not expose Apply before lifecycle wiring")

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
if "scripts/code-workflow/commit.py" not in set(payload):
    fail("atomic commit engine must ship in runtime payload before wiring")

print("ok - Code Workflow isolated atomic commit engine contract")
