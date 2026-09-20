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

import connect_snapshot


def fail(message: str) -> None:
    raise SystemExit("FAIL: " + message)


with tempfile.TemporaryDirectory(prefix="hadalis-connect-snapshot-") as directory:
    root = Path(directory)
    clock = root / "Clock.qml"
    config = root / "Config.qml"
    clock.write_text("Item { property bool flag: true }\n", encoding="utf-8")
    config.write_text("Singleton { property bool verbose: true }\n", encoding="utf-8")
    clock_sha = sha256(clock.read_bytes()).hexdigest()
    config_sha = sha256(config.read_bytes()).hexdigest()
    candidate_sha = "c" * 64

    fresh = connect_snapshot.verify_connect_safety_snapshot(
        root,
        "Clock.qml",
        clock_sha,
        candidate_sha,
        "Config.qml",
        config_sha,
    )
    if fresh.get("status") != "fresh":
        fail("matching promoted source hashes must reverify as fresh")
    if fresh.get("sourceFresh") is not True:
        fail("primary source freshness evidence missing")
    if fresh.get("externalSourceFresh") is not True:
        fail("external source freshness evidence missing")
    if fresh.get("writeAuthorized") is not False:
        fail("freshness helper must never authorize writes")

    config.write_text(
        "Singleton { property bool verbose: false }\n",
        encoding="utf-8",
    )
    stale = connect_snapshot.verify_connect_safety_snapshot(
        root,
        "Clock.qml",
        clock_sha,
        candidate_sha,
        "Config.qml",
        config_sha,
    )
    if stale.get("status") != "stale":
        fail("external dependency mutation must invalidate promoted safety")
    if stale.get("reason") != "external-source-sha-drift":
        fail("external dependency stale reason drifted")

    invalid = connect_snapshot.verify_connect_safety_snapshot(
        root,
        "Clock.qml",
        clock_sha,
        "not-a-sha",
        "Config.qml",
        config_sha,
    )
    if invalid.get("status") != "invalid-request":
        fail("invalid candidate SHA must fail closed")


helper = (SCRIPT_DIR / "connect_snapshot.py").read_text(encoding="utf-8")
transaction = (
    ROOT / "services/CodeWorkflowTransaction.qml"
).read_text(encoding="utf-8")
page = (ROOT / "modules/settings/CodeWorkflow.qml").read_text(encoding="utf-8")
phase2 = (ROOT / "docs/CODE_WORKFLOW_PHASE2.md").read_text(encoding="utf-8")
exclusions = json.loads(
    (ROOT / "sdata/runtime-exclusions.json").read_text(encoding="utf-8")
)

for token in (
    "def verify_connect_safety_snapshot(",
    '"candidateSha256": candidate_sha256',
    '"status": "fresh"',
    '"source-sha-drift"',
    '"external-source-sha-drift"',
    '"writeAuthorized": False',
    '"applyEnabled": False',
    '"artifactsStaged": False',
):
    if token not in helper:
        fail("Connect safety freshness helper missing " + token)

for forbidden in (
    "write_text(",
    "write_bytes(",
    "os.replace(",
    "setText(",
):
    if forbidden in helper:
        fail("freshness helper must never write source: " + forbidden)

for token in (
    "property var connectSafetyDiagnostics:",
    "readonly property bool connectSafetyBusy:",
    "readonly property var activeConnectSafety:",
    "readonly property bool connectSafetySnapshotReady:",
    "function _connectSafetyMatchesCommand(",
    "function _sanitizeConnectQualification(payload): var",
    "function promoteConnectQualification(payload): bool",
    "function _markConnectSafetyStale(path: string): void",
    "function _startConnectSafetyFreshnessCheck(command): bool",
    "function reverifyActiveConnectSafety(): bool",
    "function finishConnectSafetyFreshness(exitCode: int): void",
    'Quickshell.shellPath(',
    '"scripts/code-workflow/connect_snapshot.py"',
    '"qualified-reviewed-connect-research-v1"',
    '"compatible-qmllint-proof"',
    '"acyclic-source-backed-cross-file-closure"',
    'String(safety.candidateSha256 ?? "")',
    'String(command.candidateSha256 ?? "")',
    'payload?.writeAuthorized !== false',
    'safety.writeAuthorized !== false',
    'freshness: "pending"',
    'freshness: "stale"',
    'Qt.callLater(root.reverifyActiveConnectSafety)',
    "id: connectSafetySourceWatch",
    "id: connectSafetyExternalWatch",
):
    if token not in transaction:
        fail("2K-L transaction promotion boundary missing " + token)

if 'Quickshell.shellPath("scripts/code-workflow/connect_qualify.py")' in transaction:
    fail("research qualification generator must remain outside production transaction")
if "promoteConnectQualification(" in page:
    fail("2K-L must not expose a product Qualify control yet")

for token in (
    'String(root.activeCommand?.kind ?? "") === "literal-property"',
    'if (String(command.kind ?? "") !== "literal-property")',
    'blockers.push("write-subset-not-authorized")',
    "if (!root.applyEnabled)",
):
    if token not in transaction:
        fail("2K-L must preserve literal-only Apply isolation: " + token)

commit_start = transaction.index("function _commitConnectPreviewCommand(")
commit_end = transaction.index("function finish(", commit_start)
if commit_start < 0 or commit_end < 0:
    fail("Connect preview commit function boundary missing")
connect_commit = transaction[commit_start:commit_end]
if "connectSafety:" in connect_commit:
    fail("regenerated/new Connect preview must not inherit old safety snapshot")

for path in (
    "scripts/code-workflow/connect_type.py",
    "scripts/code-workflow/connect_cycle.py",
    "scripts/code-workflow/connect_qualify.py",
):
    if path not in exclusions.get("excludedPaths", []):
        fail("research proof generator must remain excluded: " + path)

if "scripts/code-workflow/connect_snapshot.py" in exclusions.get(
        "excludedPaths", []):
    fail("read-only promoted-snapshot verifier must ship in runtime payload")

runtime_payload = subprocess.run(
    [sys.executable, str(ROOT / "sdata/lib/runtime-payload.py"),
     "list", "--root", str(ROOT)],
    cwd=ROOT,
    text=True,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    check=True,
).stdout.splitlines()
runtime_set = set(runtime_payload)
if "scripts/code-workflow/connect_snapshot.py" not in runtime_set:
    fail("Connect safety snapshot verifier must ship in runtime payload")
for path in (
    "scripts/code-workflow/connect_type.py",
    "scripts/code-workflow/connect_cycle.py",
    "scripts/code-workflow/connect_qualify.py",
):
    if path in runtime_set:
        fail("research proof generator leaked into runtime payload: " + path)

for token in (
    "Milestone 2K-L — Connect safety snapshot promotion boundary",
    "candidateSha256",
    "PENDING",
    "FRESH",
    "STALE",
    "literal-property remains the only",
):
    if token not in phase2:
        fail("2K-L documentation missing " + token)

print("ok - Code Workflow 2K-L Connect safety snapshot promotion boundary")
