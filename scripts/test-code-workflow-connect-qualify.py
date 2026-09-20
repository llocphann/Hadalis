#!/usr/bin/env python3
from hashlib import sha256
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SCRIPT_DIR = ROOT / "scripts/code-workflow"
sys.path.insert(0, str(SCRIPT_DIR))

import connect_cycle
import connect_qualify
import connect_type


def fail(message: str) -> None:
    raise SystemExit("FAIL: " + message)


manifest = json.loads(
    (ROOT / "defaults/code-workflow-ir.json").read_text(encoding="utf-8")
)
target = manifest["graphs"]["bar/clock"]["connectTargets"][0]
clock_path = target["sourcePath"]
config_path = "modules/common/Config.qml"
clock_sha = sha256((ROOT / clock_path).read_bytes()).hexdigest()
config_sha = sha256((ROOT / config_path).read_bytes()).hexdigest()
candidate_sha = "c" * 64
parent_anchor = "qml-semantic:object:clock-root"
source_anchor = "qml-semantic:property:clock-root:showDate"
terminal_anchor = "qml-semantic:property:config-bar:verbose"


def type_payload(
    source_path: str = clock_path,
    base_sha: str = clock_sha,
) -> dict:
    return {
        "status": "proof",
        "targetId": "bar/clock",
        "connectTargetId": target["id"],
        "sourcePath": source_path,
        "baseSha256": base_sha,
        "candidateSha256": candidate_sha,
        "parentSemanticAnchor": parent_anchor,
        "targetProperty": target["bindingName"],
        "sourceExpression": target["sourceExpression"],
        "sourcePropertySemanticAnchor": source_anchor,
        "sourceDeclaredType": "bool",
        "typeCompatibilityProof": connect_type.TYPE_PROOF,
        "oracle": {
            "tool": "qmllint",
            "version": "qmllint 6.11.2",
        },
        "typeCompatibility": "unknown-unresolved",
        "cycleStatus": "unknown-incomplete-projection",
        "applyEnabled": False,
        "artifactsStaged": False,
        "productionIntegrated": False,
    }


def cycle_payload(
    source_path: str = clock_path,
    base_sha: str = clock_sha,
    external_path: str = config_path,
    external_sha: str = config_sha,
) -> dict:
    return {
        "status": "analysis",
        "targetId": "bar/clock",
        "connectTargetId": target["id"],
        "sourcePath": source_path,
        "baseSha256": base_sha,
        "candidateSha256": candidate_sha,
        "parentSemanticAnchor": parent_anchor,
        "targetProperty": target["bindingName"],
        "sourceExpression": target["sourceExpression"],
        "cycleAnalysisStatus": "proven-acyclic",
        "cycleSafetyProof": connect_cycle.PROVEN_ACYCLIC_CROSS_FILE,
        "cycleAnalysisReason":
            "source-backed-cross-file-chain-ends-in-literal",
        "dependencyPath": [
            "showDate",
            "Config",
            "options",
            "bar",
            "verbose",
        ],
        "externalModuleUri": "qs.modules.common",
        "externalSourcePath": external_path,
        "externalSourceSha256": external_sha,
        "aliasTargetId": "configOptionsJsonAdapter",
        "terminalPropertySemanticAnchor": terminal_anchor,
        "terminalDeclaredType": "bool",
        "terminalValueKind": "true",
        "terminalValueText": "true",
        "fallbackLiteral": "true",
        "typeCompatibility": "unknown-unresolved",
        "cycleStatus": "unknown-incomplete-projection",
        "applyEnabled": False,
        "artifactsStaged": False,
        "productionIntegrated": False,
    }


def good_type_runner(
    root,
    target_id,
    connect_target_id,
    grammar="",
    library="",
    qmllint="",
):
    return type_payload()


def good_cycle_runner(
    root,
    target_id,
    connect_target_id,
    grammar="",
    library="",
):
    return cycle_payload()


qualified = connect_qualify.qualify_reviewed_connect(
    ROOT,
    "bar/clock",
    target["id"],
    type_runner=good_type_runner,
    cycle_runner=good_cycle_runner,
)
if qualified.get("status") != "proof":
    fail("matching isolated proofs must compose into research qualification")
if qualified.get("qualificationProof") != connect_qualify.QUALIFICATION_PROOF:
    fail("qualification proof token drifted")
if qualified.get("typeCompatibilityProof") != connect_type.TYPE_PROOF:
    fail("qualified type proof token drifted")
if qualified.get("candidateSha256") != candidate_sha:
    fail("qualification must bind to exact preview candidate SHA")
if qualified.get("cycleSafetyProof") != (
    connect_cycle.PROVEN_ACYCLIC_CROSS_FILE
):
    fail("qualified cycle proof token drifted")
if qualified.get("sourceReverified") is not True:
    fail("Clock source must be reverified after proof composition")
if qualified.get("externalSourceReverified") is not True:
    fail("Config source must be reverified after proof composition")
if qualified.get("writeAuthorized") is not False:
    fail("research qualification must never authorize writes")
if qualified.get("applyEnabled") is not False:
    fail("research qualification must never enable Apply")
if qualified.get("artifactsStaged") is not False:
    fail("research qualification must never stage artifacts")
if qualified.get("productionIntegrated") is not False:
    fail("research qualification must stay outside production")
if qualified.get("typeCompatibility") != "unknown-unresolved":
    fail("production TYPE must remain UNKNOWN after composition")
if qualified.get("cycleStatus") != "unknown-incomplete-projection":
    fail("production CYCLE must remain UNKNOWN after composition")


def mismatched_candidate_cycle_runner(
    root,
    target_id,
    connect_target_id,
    grammar="",
    library="",
):
    payload = cycle_payload()
    payload["candidateSha256"] = "d" * 64
    return payload


blocked = connect_qualify.qualify_reviewed_connect(
    ROOT,
    "bar/clock",
    target["id"],
    type_runner=good_type_runner,
    cycle_runner=mismatched_candidate_cycle_runner,
)
if blocked.get("reason") != "proof-identity-mismatch":
    fail("type/cycle candidate SHA mismatch must fail closed")
if blocked.get("mismatchField") != "candidateSha256":
    fail("candidate SHA mismatch field evidence drifted")


def mismatched_cycle_runner(
    root,
    target_id,
    connect_target_id,
    grammar="",
    library="",
):
    return cycle_payload(base_sha="0" * 64)


blocked = connect_qualify.qualify_reviewed_connect(
    ROOT,
    "bar/clock",
    target["id"],
    type_runner=good_type_runner,
    cycle_runner=mismatched_cycle_runner,
)
if blocked.get("reason") != "proof-identity-mismatch":
    fail("type/cycle source SHA mismatch must fail closed")
if blocked.get("mismatchField") != "baseSha256":
    fail("source SHA mismatch field evidence drifted")
if blocked.get("writeAuthorized") is not False:
    fail("mismatched proofs must not authorize writes")


def unsafe_type_runner(
    root,
    target_id,
    connect_target_id,
    grammar="",
    library="",
    qmllint="",
):
    payload = type_payload()
    payload["applyEnabled"] = True
    return payload


blocked = connect_qualify.qualify_reviewed_connect(
    ROOT,
    "bar/clock",
    target["id"],
    type_runner=unsafe_type_runner,
    cycle_runner=good_cycle_runner,
)
if blocked.get("reason") != "type-proof-production-blockers-drifted":
    fail("research type proof with Apply enabled must fail closed")


def local_only_cycle_runner(
    root,
    target_id,
    connect_target_id,
    grammar="",
    library="",
):
    payload = cycle_payload()
    payload["cycleSafetyProof"] = connect_cycle.PROVEN_ACYCLIC
    return payload


blocked = connect_qualify.qualify_reviewed_connect(
    ROOT,
    "bar/clock",
    target["id"],
    type_runner=good_type_runner,
    cycle_runner=local_only_cycle_runner,
)
if blocked.get("phase") != "cycle-proof":
    fail("2K-K must require the qualified cross-file cycle proof")


with tempfile.TemporaryDirectory(prefix="hadalis-connect-qualify-") as directory:
    temp_root = Path(directory)
    (temp_root / "Clock.qml").write_text(
        "Item { property bool showDate: true }\n",
        encoding="utf-8",
    )
    (temp_root / "Config.qml").write_text(
        "Singleton { property bool verbose: true }\n",
        encoding="utf-8",
    )
    temp_clock_sha = sha256((temp_root / "Clock.qml").read_bytes()).hexdigest()
    temp_config_sha = sha256((temp_root / "Config.qml").read_bytes()).hexdigest()

    def temp_type_runner(
        root,
        target_id,
        connect_target_id,
        grammar="",
        library="",
        qmllint="",
    ):
        return type_payload(
            source_path="Clock.qml",
            base_sha=temp_clock_sha,
        )

    def mutating_cycle_runner(
        root,
        target_id,
        connect_target_id,
        grammar="",
        library="",
    ):
        payload = cycle_payload(
            source_path="Clock.qml",
            base_sha=temp_clock_sha,
            external_path="Config.qml",
            external_sha=temp_config_sha,
        )
        (root / "Config.qml").write_text(
            "Singleton { property bool verbose: false }\n",
            encoding="utf-8",
        )
        return payload

    blocked = connect_qualify.qualify_reviewed_connect(
        temp_root,
        "bar/clock",
        target["id"],
        type_runner=temp_type_runner,
        cycle_runner=mutating_cycle_runner,
    )
    if blocked.get("reason") != "qualified-external-source-became-stale":
        fail("external Config edit after proof must invalidate qualification")
    if blocked.get("writeAuthorized") is not False:
        fail("stale external evidence must not authorize writes")


helper = (SCRIPT_DIR / "connect_qualify.py").read_text(encoding="utf-8")
transaction = (
    ROOT / "services/CodeWorkflowTransaction.qml"
).read_text(encoding="utf-8")
phase2 = (ROOT / "docs/CODE_WORKFLOW_PHASE2.md").read_text(encoding="utf-8")
exclusions = json.loads(
    (ROOT / "sdata/runtime-exclusions.json").read_text(encoding="utf-8")
)

for token in (
    'QUALIFICATION_PROOF = "qualified-reviewed-connect-research-v1"',
    "def qualify_reviewed_connect(",
    '"proof-identity-mismatch"',
    '"candidateSha256"',
    '"proof-candidate-sha-invalid"',
    '"qualified-source-became-stale"',
    '"qualified-external-source-became-stale"',
    '"proofsComposed": True',
    '"sourceReverified": True',
    '"externalSourceReverified": True',
    '"typeCompatibility": TYPE_UNKNOWN',
    '"cycleStatus": CYCLE_UNKNOWN',
    '"applyEnabled": False',
    '"artifactsStaged": False',
    '"productionIntegrated": False',
    '"writeAuthorized": False',
):
    if token not in helper:
        fail("2K-K qualification helper missing " + token)

for forbidden in (
    "write_text(",
    "write_bytes(",
    "os.replace(",
    "setText(",
):
    if forbidden in helper:
        fail("qualification helper must never write source: " + forbidden)

if 'Quickshell.shellPath("scripts/code-workflow/connect_qualify.py")' in transaction:
    fail("2K-K research qualification generator must not be wired into transaction")
if 'function promoteConnectQualification(payload): bool' not in transaction:
    fail("2K-L must define the transaction-side qualification acceptance boundary")
if 'payload?.writeAuthorized !== false' not in transaction:
    fail("promoted qualification must retain writeAuthorized=false")

if "scripts/code-workflow/connect_qualify.py" not in exclusions.get(
        "excludedPaths", []):
    fail("research-only qualification helper must stay outside runtime payload")

runtime_payload = subprocess.run(
    [sys.executable, str(ROOT / "sdata/lib/runtime-payload.py"),
     "list", "--root", str(ROOT)],
    cwd=ROOT,
    text=True,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    check=True,
).stdout.splitlines()
if "scripts/code-workflow/connect_qualify.py" in set(runtime_payload):
    fail("research-only qualification helper leaked into runtime payload")

for token in (
    "Milestone 2K-K — composed Connect research qualification",
    "qualified-reviewed-connect-research-v1",
    "same Clock source SHA",
    "Config",
    "source SHA",
    "writeAuthorized=false",
    "production TYPE and CYCLE remain UNKNOWN",
):
    if token not in phase2:
        fail("2K-K documentation missing " + token)


grammar = os.environ.get("HADALIS_WORKFLOW_GRAMMAR", "")
library = os.environ.get("HADALIS_TREE_SITTER_LIBRARY", "")
if grammar and Path(grammar).is_file():
    tool = connect_type._find_qmllint("")
    if tool is None:
        fail("native 2K-K acceptance has grammar but qmllint is unavailable")

    proofs = []
    for _ in range(2):
        payload = connect_qualify.qualify_reviewed_connect(
            ROOT,
            "bar/clock",
            target["id"],
            grammar,
            library,
            tool,
        )
        if payload.get("status") != "proof":
            fail(
                "native 2K-K qualification failed: "
                + json.dumps(payload, sort_keys=True)
            )
        if payload.get("qualificationProof") != (
            connect_qualify.QUALIFICATION_PROOF
        ):
            fail("native 2K-K qualification token drifted")
        if payload.get("typeCompatibilityProof") != connect_type.TYPE_PROOF:
            fail("native 2K-K type proof drifted")
        if payload.get("cycleSafetyProof") != (
            connect_cycle.PROVEN_ACYCLIC_CROSS_FILE
        ):
            fail("native 2K-K cycle proof drifted")
        if payload.get("sourceReverified") is not True:
            fail("native 2K-K must reverify Clock source")
        if payload.get("externalSourceReverified") is not True:
            fail("native 2K-K must reverify Config source")
        if payload.get("typeCompatibility") != "unknown-unresolved":
            fail("native 2K-K production TYPE must stay UNKNOWN")
        if payload.get("cycleStatus") != "unknown-incomplete-projection":
            fail("native 2K-K production CYCLE must stay UNKNOWN")
        if payload.get("writeAuthorized") is not False:
            fail("native 2K-K must not authorize writes")
        if payload.get("applyEnabled") is not False:
            fail("native 2K-K must not enable Apply")
        if payload.get("artifactsStaged") is not False:
            fail("native 2K-K must not stage artifacts")
        if payload.get("productionIntegrated") is not False:
            fail("native 2K-K must stay outside production")
        proofs.append(payload)

    stable_fields = (
        "sourcePath",
        "baseSha256",
        "candidateSha256",
        "parentSemanticAnchor",
        "targetProperty",
        "sourceExpression",
        "sourcePropertySemanticAnchor",
        "sourceDeclaredType",
        "typeCompatibilityProof",
        "cycleSafetyProof",
        "dependencyPath",
        "externalModuleUri",
        "externalSourcePath",
        "externalSourceSha256",
        "aliasTargetId",
        "terminalPropertySemanticAnchor",
        "terminalDeclaredType",
        "terminalValueKind",
        "terminalValueText",
        "fallbackLiteral",
        "qualificationProof",
        "typeCompatibility",
        "cycleStatus",
    )
    first = {key: proofs[0].get(key) for key in stable_fields}
    second = {key: proofs[1].get(key) for key in stable_fields}
    if first != second:
        fail("repeated native 2K-K qualification must be deterministic")

print("ok - Code Workflow 2K-K composed Connect research qualification")
