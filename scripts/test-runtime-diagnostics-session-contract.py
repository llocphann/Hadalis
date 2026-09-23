#!/usr/bin/env python3
"""Regression contract for demand-driven Runtime Diagnostics sessions."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def require(text: str, token: str, message: str) -> None:
    if token not in text:
        raise SystemExit(f"FAIL: {message}: missing {token!r}")


diagnostics = read("services/RuntimeDiagnostics.qml")
session = read("services/RuntimeDiagnosticsSession.qml")
workflow_runtime = read("services/CodeWorkflowRuntime.qml")
shell = read("shell.qml")
page_host = read("modules/settings/SettingsPageHost.qml")
material_page = read("modules/settings/RuntimeDiagnosticsConfig.qml")
waffle_page = read("modules/waffle/settings/pages/WDiagnosticsPage.qml")
sampler = read("scripts/runtime-diagnostics-sampler.py")

for token in (
    "readonly property int leaseTtlMs: 6000",
    "readonly property int maxLeases: 16",
    "readonly property int sampleIntervalMs: 1000",
    "property var leases: ({})",
    "readonly property int leaseCount:",
    "readonly property bool sessionActive:",
    "readonly property bool samplingEnabled: root.sessionActive",
    "function acquire(clientId: string): bool",
    "function heartbeat(clientId: string): bool",
    "function release(clientId: string): bool",
    "function pruneExpired(): void",
    "function status(): var",
    "id: leasePruneTimer",
    "running: root.sessionActive",
    "function _consumeSample(rawLine): void",
    "function snapshot(): var",
    "id: diagnosticsSampler",
    "running: root.samplingEnabled",
    'Quickshell.shellPath("scripts/runtime-diagnostics-sampler.py")',
    '"--pid", String(Quickshell.processId)',
    '"--interval-ms", String(root.sampleIntervalMs)',
    "sampleIntervalMs: root.sampleIntervalMs",
    "stdout: SplitParser {",
):
    require(diagnostics, token, "RuntimeDiagnostics lease authority is incomplete")

require(
    diagnostics,
    'return id.length > 0 && id.length <= 128 ? id : ""',
    "Diagnostics client IDs must be bounded",
)
require(
    diagnostics,
    "root.leaseCount >= root.maxLeases",
    "Diagnostics lease table must be bounded",
)

heartbeat_start = diagnostics.index("function heartbeat(")
heartbeat_end = diagnostics.index("function release(", heartbeat_start)
heartbeat = diagnostics[heartbeat_start:heartbeat_end]
require(
    heartbeat,
    "id.length === 0 || root.leases[id] === undefined",
    "heartbeat must fail closed for missing leases",
)
if "root.acquire(" in heartbeat:
    raise SystemExit(
        "FAIL: heartbeat must renew an existing lease, not reuse acquire semantics"
    )

for token in (
    'readonly property string clientId:',
    '"settings:" + String(Quickshell.processId)',
    "readonly property bool localShell:",
    "property var activeOwners: ({})",
    'property string leaseTransport: ""',
    "readonly property bool pageCurrent:",
    "function setOwnerCurrent(ownerId: string, current: bool): void",
    "RuntimeDiagnostics.acquire(root.clientId)",
    "RuntimeDiagnostics.heartbeat(root.clientId)",
    "RuntimeDiagnostics.release(root.clientId)",
    "const transport = root.leaseTransport",
    'const desiredTransport = root.localShell ? "local" : "remote"',
    '"ipc", "runtimeDiagnostics"',
    "id: heartbeatTimer",
    "running: root.pageCurrent",
    "property string action: \"\"",
    "remotePulse.action = action",
    'remotePulse.action === "heartbeat"',
    'Qt.callLater(() => root._pulseRemote("acquire"))',
    "readonly property var evidence: root.localShell",
    "RuntimeDiagnostics.snapshot()",
    "CodeWorkflowRuntime.remoteSnapshot?.diagnostics",
):
    require(session, token, "Diagnostics current-page session client is incomplete")

for token in (
    'target: "runtimeDiagnostics"',
    "RuntimeDiagnostics.acquire(clientId)",
    "RuntimeDiagnostics.heartbeat(clientId)",
    "RuntimeDiagnostics.release(clientId)",
    "RuntimeDiagnostics.status()",
    "RuntimeDiagnostics.snapshot()",
    "payload.diagnostics = RuntimeDiagnostics.snapshot()",
):
    require(shell, token, "main-shell Runtime Diagnostics IPC contract is incomplete")

for token in (
    'SettingsPageRegistry.pageIndexForKey("diagnostics")',
    'root.workflowHostId + ":diagnostics"',
    "RuntimeDiagnosticsSession.setOwnerCurrent(",
    "DiagnosticsPageState.shouldLease(",
    "root.requestedIndex, root.currentIndex,",
    "onCurrentIndexChanged: root._syncDiagnosticsLease()",
    "onVisibleChanged: root._syncDiagnosticsLease()",
):
    require(page_host, token, "Settings current-page Diagnostics ownership regressed")

for source, text in (
    ("RuntimeDiagnosticsConfig.qml", material_page),
    ("WDiagnosticsPage.qml", waffle_page),
):
    require(
        text,
        "RuntimeDiagnosticsSession.pageCurrent",
        f"{source} must report the shared current-page session",
    )
    require(
        text,
        "if (value === null || value === undefined)",
        f"{source} must preserve unavailable metrics instead of coercing null to zero",
    )
    require(
        text,
        "function shellGpuBusy(): var",
        f"{source} must allow unavailable GPU utilization",
    )
    require(
        text,
        "return found ? total : null",
        f"{source} must allow unavailable GPU resident memory",
    )

# CodeWorkflowRuntime remains canonical identity/runtime evidence only. It must
# not grow a second Diagnostics lease table, heartbeat client or sampler.
for forbidden in (
    "diagnosticsLeases",
    "diagnosticsSessionActive",
    "diagnosticsConsumerActive",
    "acquireDiagnosticsLease",
    "heartbeatDiagnosticsLease",
    "releaseDiagnosticsLease",
    "diagnosticsLeaseProcess",
    "diagnosticsHeartbeatTimer",
    "diagnosticsLeasePruneTimer",
):
    if forbidden in workflow_runtime:
        raise SystemExit(
            "FAIL: CodeWorkflowRuntime contains duplicate Diagnostics session "
            f"authority: {forbidden!r}"
        )

code_workflow_ipc_start = shell.index('target: "codeWorkflowRuntime"')
runtime_diag_ipc_start = shell.index('target: "runtimeDiagnostics"', code_workflow_ipc_start)
code_workflow_ipc = shell[code_workflow_ipc_start:runtime_diag_ipc_start]
for forbidden in (
    "diagnosticsAcquire",
    "diagnosticsHeartbeat",
    "diagnosticsRelease",
    "diagnosticsStatus",
):
    if forbidden in code_workflow_ipc:
        raise SystemExit(
            "FAIL: codeWorkflowRuntime IPC must not duplicate Runtime Diagnostics "
            f"lease methods: {forbidden!r}"
        )

# Session status carries lifecycle facts only; canonical labels and component
# metadata remain Workflow-owned.
status_start = diagnostics.index("function status()")
status_end = diagnostics.index("// This is lease cleanup", status_start)
status = diagnostics[status_start:status_end]
for forbidden in ("clientId", "label:", "name:", "icon:", "title:"):
    if forbidden in status:
        raise SystemExit(
            "FAIL: Diagnostics status leaked client/presentation metadata: "
            + repr(forbidden)
        )

# No page/component may auto-acquire merely because it was constructed. The page
# host owns the explicit current-page transition.
for source, text in (
    ("RuntimeDiagnostics.qml", diagnostics),
    ("RuntimeDiagnosticsSession.qml", session),
    ("RuntimeDiagnosticsConfig.qml", material_page),
    ("WDiagnosticsPage.qml", waffle_page),
):
    if "Component.onCompleted: RuntimeDiagnostics.acquire" in text:
        raise SystemExit(
            f"FAIL: {source} must not acquire Diagnostics in Component.onCompleted"
        )

for token in (
    'parser.add_argument("--pid", type=int, required=True)',
    'read_sched_runtime_ns(pid)',
    'read_system_cpu_ticks()',
    'read_system_memory()',
    'read_drm(pid)',
    '"scope": "shell-process"',
    '"method": "schedstat"',
    '"method": "smaps-rollup"',
    '"method": "proc-net-dev"',
    '"method": "drm-fdinfo"',
    '"confidence": "kernel"',
):
    require(sampler, token, "kernel sampler provenance contract is incomplete")

for forbidden in (
    '"targetId"',
    '"componentCpu"',
    '"componentRam"',
):
    if forbidden in sampler:
        raise SystemExit(
            "FAIL: kernel sampler must not invent per-component attribution: "
            + repr(forbidden)
        )

for source, text in (
    ("RuntimeDiagnosticsConfig.qml", material_page),
    ("WDiagnosticsPage.qml", waffle_page),
):
    for forbidden in ("Process {", "FileView {"):
        if forbidden in text:
            raise SystemExit(
                f"FAIL: {source} must consume main-shell evidence, not sample locally: "
                + repr(forbidden)
            )

print("ok - single-authority demand-driven Runtime Diagnostics session contract")
