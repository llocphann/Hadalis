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

# Server is passive: no resource sampler is allowed to start merely because
# singleton construction happened. The only timer is lease cleanup and it runs
# only while at least one consumer owns a live lease.
for token in (
    "readonly property int leaseTtlMs: 6000",
    "property var leases: ({})",
    "readonly property bool sessionActive:",
    "readonly property bool samplingEnabled: root.sessionActive",
    "function acquire(clientId: string): bool",
    "function heartbeat(clientId: string): bool",
    "function release(clientId: string): bool",
    "function pruneExpired(): void",
    "id: leasePruneTimer",
    "running: root.sessionActive",
):
    require(server, token, "Diagnostics lease server contract incomplete")
if server.count("Timer {") != 1:
    raise SystemExit("FAIL: Diagnostics foundation must have only the TTL cleanup timer")
if "Process {" in server:
    raise SystemExit("FAIL: passive Diagnostics server must not spawn sampler processes yet")

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

# Resource claims are intentionally not implemented in this foundation. Keep the
# UI honest until exact samplers with provenance land.
for page in (material_page, waffle_page):
    if re.search(r"\b\d+(?:\.\d+)?\s*%\b", page):
        raise SystemExit("FAIL: Diagnostics foundation must not fabricate resource percentages")
require(material_page, "CPU · RAM · Swap · GPU · Network",
        "Material page must preserve required resource scope")
require(waffle_page, "CPU · RAM · Swap · GPU · Network",
        "Waffle page must preserve required resource scope")

print("ok - Runtime Diagnostics identity/session foundation contract")
