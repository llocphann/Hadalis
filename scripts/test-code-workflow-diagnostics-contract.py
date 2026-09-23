#!/usr/bin/env python3
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]

def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")

def require(text: str, token: str, message: str) -> None:
    if token not in text:
        raise SystemExit(f"FAIL: {message}: missing {token!r}")

registry = read("modules/settings/SettingsPageRegistryData.qml")
arrangement = read("modules/settings/SettingsArrangement.qml")
material_page = read("modules/settings/RuntimeDiagnosticsConfig.qml")
host = read("modules/settings/SettingsPageHost.qml")
waffle_root = read("waffleSettings.qml")
waffle_content = read("modules/waffle/settings/WSettingsContent.qml")
waffle_page = read("modules/waffle/settings/pages/WDiagnosticsPage.qml")
server = read("services/RuntimeDiagnostics.qml")
client = read("services/RuntimeDiagnosticsSession.qml")
shell = read("shell.qml")
qmldir = read("services/qmldir")
sampler = read("scripts/runtime-diagnostics-sampler.py")
workflow_runtime = read("services/CodeWorkflowRuntime.qml")

# Material keeps historical page indices and appends Diagnostics at 31.
require(registry, 'key: "diagnostics"', "Material Diagnostics page missing")
require(registry, 'component: "modules/settings/RuntimeDiagnosticsConfig.qml"',
        "Material Diagnostics component route missing")
require(registry, 'pages: [20, 30, 31, 9, 13]',
        "Diagnostics must sit beside Workflow without shifting old routes")
require(material_page, "settingsPageIndex: 31",
        "Material Diagnostics page index drifted")
require(arrangement, "readonly property int layoutSchemaVersion: 9",
        "Settings layout schema must migrate appended Diagnostics page")
require(arrangement, "readonly property int diagnosticsPageIndex: 31",
        "Settings migration must know Diagnostics index")
require(arrangement, "sourceVersion < 9",
        "saved layouts need a v9 Diagnostics placement migration")

# Waffle keeps its own independent positional route and appends Diagnostics at 19.
power_pos = waffle_root.index('key: "power"')
diagnostics_pos = waffle_root.index('key: "diagnostics"')
if diagnostics_pos <= power_pos:
    raise SystemExit("FAIL: Waffle Diagnostics must append after existing page 18")
require(waffle_root, 'component: Qt.resolvedUrl("modules/waffle/settings/pages/WDiagnosticsPage.qml")',
        "Waffle Diagnostics page route missing")
require(waffle_page, "settingsPageIndex: 19",
        "Waffle Diagnostics page index must remain 19")
require(waffle_content, 'keys: ["diagnostics", "shortcuts", "about"]',
        "Waffle navigation must group Diagnostics with Advanced & Help")
require(waffle_content, 'pageIndex: 19, pageName: "Diagnostics"',
        "Waffle search must index Diagnostics")

# Server remains passive by default. The sampler exists now, but its Process is
# bound strictly to the leased samplingEnabled state and measures Quickshell's
# main PID rather than whichever Settings process is displaying the page.
for token in (
    "readonly property int leaseTtlMs: 6000",
    "readonly property int maxLeases: 16",
    "property var leases: ({})",
    "readonly property bool sessionActive:",
    "readonly property bool samplingEnabled: root.sessionActive",
    "function acquire(clientId: string): bool",
    "function heartbeat(clientId: string): bool",
    "function release(clientId: string): bool",
    "function pruneExpired(): void",
    "function _consumeSample(rawLine): void",
    "function snapshot(): var",
    "id: diagnosticsSampler",
    "running: root.samplingEnabled",
    'Quickshell.shellPath("scripts/runtime-diagnostics-sampler.py")',
    '"--pid", String(Quickshell.processId)',
    "id: leasePruneTimer",
    "running: root.sessionActive",
):
    require(server, token, "Diagnostics lease/sampler contract incomplete")
if server.count("Timer {") != 1:
    raise SystemExit("FAIL: Diagnostics owns only the TTL cleanup timer")
if server.count("Process {") != 1:
    raise SystemExit("FAIL: Diagnostics must own exactly one on-demand sampler process")

for forbidden in (
    "diagnosticsLeases",
    "acquireDiagnosticsLease",
    "heartbeatDiagnosticsLease",
    "releaseDiagnosticsLease",
    "diagnosticsLeaseProcess",
):
    if forbidden in workflow_runtime:
        raise SystemExit(
            "FAIL: CodeWorkflowRuntime must not own a second Diagnostics lease path: "
            + forbidden
        )

# Standalone settings must lease the shell-side server over IPC, not measure its
# own process. Local overlay/focus hosts can call the same shell singleton.
for token in (
    '"settings:" + String(Quickshell.processId)',
    "property var activeOwners: ({})",
    "readonly property bool pageCurrent:",
    "function setOwnerCurrent(ownerId: string, current: bool): void",
    "function _remoteCommand(action: string): var",
    '"ipc", "runtimeDiagnostics"',
    'root._pulseRemote("acquire")',
    'root._pulseRemote("heartbeat")',
    'root._remoteCommand("release")',
    "running: root.pageCurrent",
):
    require(client, token, "Diagnostics settings lease client incomplete")

for token in (
    'target: "runtimeDiagnostics"',
    "RuntimeDiagnostics.acquire(clientId)",
    "RuntimeDiagnostics.heartbeat(clientId)",
    "RuntimeDiagnostics.release(clientId)",
    "RuntimeDiagnostics.status()",
):
    require(shell, token, "main-shell Diagnostics IPC missing " + token)

# Material LRU pages can remain instantiated; lease ownership must follow the
# route that is actually current, plus host visibility and load state.
for token in (
    'SettingsPageRegistry.pageIndexForKey("diagnostics")',
    'root.workflowHostId + ":diagnostics"',
    "function _syncDiagnosticsLease()",
    "RuntimeDiagnosticsSession.setOwnerCurrent(",
    'DiagnosticsPageState.shouldLease(',
    "root.loadEnabled",
    "root.requestedIndex, root.currentIndex,",
    "onRequestedIndexChanged:",
    "onCurrentIndexChanged: root._syncDiagnosticsLease()",
    "onVisibleChanged: root._syncDiagnosticsLease()",
    "onLoadEnabledChanged:",
):
    require(host, token, "Material current-page Diagnostics lease missing")
sync_start = host.index("function _syncDiagnosticsLease()")
sync_end = host.index("function _sourceFor(", sync_start)
sync_block = host[sync_start:sync_end]
for forbidden in ("currentItem.visible", "pageLoader.visible", "Loader.Ready"):
    if forbidden in sync_block:
        raise SystemExit(
            "FAIL: Diagnostics lease must not depend on cached page visibility: "
            + forbidden
        )

# Waffle has no LRU, but it uses the same explicit semantic-key/current-page
# ownership contract rather than page construction/destruction.
for token in (
    'root.pages.findIndex(page => page.key === "diagnostics")',
    '"waffle-settings:diagnostics"',
    "function syncDiagnosticsLease(): void",
    "RuntimeDiagnosticsSession.setOwnerCurrent(",
    "root.currentPage === root.diagnosticsPageIndex",
    "onCurrentPageChanged:",
    "onLoadEnabledChanged:",
):
    require(waffle_content, token, "Waffle current-page Diagnostics lease missing")

for token in (
    "singleton RuntimeDiagnostics 1.0 RuntimeDiagnostics.qml",
    "singleton RuntimeDiagnosticsSession 1.0 RuntimeDiagnosticsSession.qml",
):
    require(qmldir, token, "Diagnostics singleton export missing")

# Exact shell/system sampling now has explicit provenance. It still must not claim
# per-QML CPU/RAM/GPU/network attribution.
for token in (
    '"scope": "system"',
    '"scope": "shell-process"',
    '"confidence": "kernel"',
    '"method": "proc-stat"',
    '"method": "proc-meminfo"',
    '"method": "schedstat"',
    '"method": "smaps-rollup"',
    '"method": "proc-io"',
    '"method": "proc-net-dev"',
    '"method": "drm-fdinfo"',
):
    require(sampler, token, "Diagnostics sampler provenance incomplete")

for forbidden in ('"targetId"', '"componentCpu"', '"componentRam"', '"componentGpu"'):
    if forbidden in sampler:
        raise SystemExit(
            "FAIL: kernel sampler must not fabricate per-component attribution: "
            + forbidden
        )

for page in (material_page, waffle_page):
    require(page, "CPU · RAM · Swap · GPU · Network",
            "Diagnostics page must preserve required resource scope")
    for token in (
        "RuntimeDiagnosticsSession.evidence",
        "root.evidence?.system ?? null",
        "root.evidence?.shell ?? null",
        "root.evidence?.network ?? null",
        "function formatPercent(value): string",
        "function formatKiB(value): string",
        "function formatRate(value): string",
        "root.systemEvidence?.cpu?.percent",
        "root.shellEvidence?.cpu?.percent",
        "root.systemEvidence?.memory?.valuesKiB?.MemUsed",
        "root.systemEvidence?.memory?.valuesKiB?.SwapUsed",
        "root.shellEvidence?.memory?.valuesKiB?.Pss",
        "root.shellEvidence?.memory?.valuesKiB?.Swap",
        "root.shellEvidence?.gpu?.available === true",
        "root.networkEvidence?.aggregateNonLoopback",
        "Per-component CPU, RAM, Swap, GPU and Network",
    ):
        require(page, token, "Diagnostics UI must render exact shell evidence: " + token)
    # Provenance paths are presentation text; Settings must not open its own
    # sampler process or direct /proc FileView. The shell-owned sampler remains
    # the sole measurement authority.
    for forbidden in ("Process {", "FileView {", "Quickshell.Io"):
        if forbidden in page:
            raise SystemExit(
                "FAIL: Settings pages must consume shell evidence, not sample locally: "
                + forbidden
            )

require(material_page, "function shellGpuMemoryKiB(): real",
        "Material Diagnostics should expose exact resident DRM memory when available")
require(material_page, "Main shell PID",
        "Material Diagnostics must identify the sampled shell process")
require(waffle_page, "Main shell PID",
        "Waffle Diagnostics must identify the sampled shell process")

print("ok - Runtime Diagnostics identity/session/sampler/UI contract")
