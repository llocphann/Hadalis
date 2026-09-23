#!/usr/bin/env python3
"""Regression contract for demand-driven Runtime Diagnostics sessions."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def require(text: str, token: str, message: str) -> None:
    if token not in text:
        raise SystemExit(f"FAIL: {message}: missing {token!r}")


runtime = read("services/CodeWorkflowRuntime.qml")
shell = read("shell.qml")

for token in (
    "property var diagnosticsLeases: ({})",
    "readonly property int diagnosticsLeaseTtlMs: 6000",
    "readonly property int diagnosticsMaxLeases: 16",
    "readonly property bool diagnosticsSessionActive:",
    "readonly property int diagnosticsActiveLeaseCount:",
    "function acquireDiagnosticsLease(rawClientId): var",
    "function heartbeatDiagnosticsLease(rawClientId): var",
    "function releaseDiagnosticsLease(rawClientId): var",
    "function _pruneDiagnosticsLeases(): void",
    "function diagnosticsSessionSnapshot(): var",
    "function setDiagnosticsConsumerActive(active: bool): void",
    "function _heartbeatDiagnosticsConsumer(): void",
    "id: diagnosticsLeasePruneTimer",
    "running: root.diagnosticsSessionActive",
    "id: diagnosticsHeartbeatTimer",
    "running: root.diagnosticsConsumerActive",
    "id: diagnosticsLeaseProcess",
    'nextAction === "acquire" ? "diagnosticsAcquire"',
    'nextAction === "heartbeat" ? "diagnosticsHeartbeat"',
    ': "diagnosticsRelease"',
    "diagnostics: root.diagnosticsSessionSnapshot()",
):
    require(runtime, token, "Runtime Diagnostics lease lifecycle is incomplete")

# Heartbeats are renewal only. A missing lease must fail so stale clients cannot
# resurrect sampler ownership without an explicit acquire.
heartbeat_start = runtime.index("function heartbeatDiagnosticsLease(")
heartbeat_end = runtime.index("function releaseDiagnosticsLease(", heartbeat_start)
heartbeat = runtime[heartbeat_start:heartbeat_end]
require(
    heartbeat,
    "clientId.length === 0 || !root.diagnosticsLeases[clientId]",
    "heartbeat must fail closed for missing leases",
)
if "next[clientId] =" not in heartbeat:
    raise SystemExit("FAIL: heartbeat must renew an existing lease expiry")

# The server-side lease table is bounded and TTL-pruned.
acquire_start = runtime.index("function acquireDiagnosticsLease(")
acquire_end = runtime.index("function heartbeatDiagnosticsLease(", acquire_start)
acquire = runtime[acquire_start:acquire_end]
require(
    acquire,
    "root.diagnosticsActiveLeaseCount >= root.diagnosticsMaxLeases",
    "diagnostics lease table must be bounded",
)
require(
    acquire,
    "Date.now() + root.diagnosticsLeaseTtlMs",
    "diagnostics acquire must set a TTL",
)

# Session snapshots expose state only. Canonical labels/names remain owned by
# Workflow descriptors and no opaque client ID is leaked into telemetry.
snapshot_start = runtime.index("function diagnosticsSessionSnapshot()")
snapshot_end = runtime.index("function _applyDiagnosticsLeaseReply(", snapshot_start)
snapshot = runtime[snapshot_start:snapshot_end]
for forbidden in ("clientId", "label:", "name:", "icon:", "title:"):
    if forbidden in snapshot:
        raise SystemExit(
            "FAIL: Diagnostics session snapshot leaked identity/presentation data: "
            + repr(forbidden)
        )

for token in (
    'target: "codeWorkflowRuntime"',
    "function diagnosticsAcquire(clientId: string): string",
    "CodeWorkflowRuntime.acquireDiagnosticsLease(clientId)",
    "function diagnosticsHeartbeat(clientId: string): string",
    "CodeWorkflowRuntime.heartbeatDiagnosticsLease(clientId)",
    "function diagnosticsRelease(clientId: string): string",
    "CodeWorkflowRuntime.releaseDiagnosticsLease(clientId)",
    "function diagnosticsStatus(): string",
    "CodeWorkflowRuntime.diagnosticsSessionSnapshot()",
):
    require(shell, token, "main-shell Diagnostics IPC contract is incomplete")

# Step 2 is intentionally sampler-free. Resource probes belong to a later
# passive sampler layer and must never be smuggled into the identity/runtime
# registry itself.
for forbidden in (
    "smaps_rollup",
    "drm-engine-",
    "drm-fdinfo",
    '"/proc/',
    "KnownDiagnosticsComponents",
    "diagnosticsCatalog",
):
    if forbidden in runtime:
        raise SystemExit(
            "FAIL: CodeWorkflowRuntime must remain sampler/catalog free: "
            + repr(forbidden)
        )

for forbidden in (
    "Component.onCompleted: root.setDiagnosticsConsumerActive(true)",
    "running: true // diagnostics",
):
    if forbidden in runtime:
        raise SystemExit(
            "FAIL: Diagnostics must not auto-start in the background: "
            + repr(forbidden)
        )

print("ok - demand-driven Runtime Diagnostics session contract")
