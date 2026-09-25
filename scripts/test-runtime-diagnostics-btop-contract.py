#!/usr/bin/env python3
"""Regression contract for the btop-style Runtime Diagnostics settings page."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PAGE = ROOT / "modules" / "settings" / "RuntimeDiagnosticsConfig.qml"
WAFFLE_PAGE = ROOT / "modules" / "waffle" / "settings" / "pages" / "WDiagnosticsPage.qml"
CONTENT_PAGE = ROOT / "modules" / "common" / "widgets" / "ContentPage.qml"
WAFFLE_BASE_PAGE = ROOT / "modules" / "waffle" / "settings" / "WSettingsPage.qml"
BOARD = ROOT / "modules" / "settings" / "widgets" / "BtopDashboard.qml"
SPARKLINE = ROOT / "modules" / "settings" / "widgets" / "BtopSparkline.qml"
METRIC_PANEL = ROOT / "modules" / "settings" / "widgets" / "BtopMetricPanel.qml"
NETWORK_PANEL = ROOT / "modules" / "settings" / "widgets" / "BtopNetworkPanel.qml"
RUNTIME_PANEL = ROOT / "modules" / "settings" / "widgets" / "BtopRuntimePanel.qml"
CORE_GRID = ROOT / "modules" / "settings" / "widgets" / "BtopCoreGrid.qml"
PROCESS_TABLE = ROOT / "modules" / "settings" / "widgets" / "BtopProcessTable.qml"
ACTIVITY_TABLE = ROOT / "modules" / "settings" / "widgets" / "BtopActivityTable.qml"
INTERFACE_TABLE = ROOT / "modules" / "settings" / "widgets" / "BtopInterfaceTable.qml"
TARGET_TABLE = ROOT / "modules" / "settings" / "widgets" / "BtopTargetTable.qml"
TARGET_INSPECTOR = ROOT / "modules" / "settings" / "widgets" / "BtopTargetInspector.qml"
SESSION = ROOT / "services" / "RuntimeDiagnosticsSession.qml"
RUNTIME = ROOT / "services" / "RuntimeDiagnostics.qml"
TARGET_RUNTIME = ROOT / "services" / "CodeWorkflowRuntimeTarget.qml"
SAMPLER = ROOT / "scripts" / "runtime-diagnostics-sampler.py"
SETTINGS_WINDOW = ROOT / "settings.qml"
WIDGETS = ROOT / "modules" / "settings" / "widgets"
WIDGET_QMLDIR = WIDGETS / "qmldir"


def require(text: str, token: str, source: str) -> None:
    if token not in text:
        raise AssertionError(f"{source} is missing diagnostics token: {token!r}")


def forbid(text: str, token: str, source: str) -> None:
    if token in text:
        raise AssertionError(f"{source} contains forbidden diagnostics token: {token!r}")


def main() -> None:
    page = PAGE.read_text(encoding="utf-8")
    waffle_page = WAFFLE_PAGE.read_text(encoding="utf-8")
    content_page = CONTENT_PAGE.read_text(encoding="utf-8")
    waffle_base_page = WAFFLE_BASE_PAGE.read_text(encoding="utf-8")
    board = BOARD.read_text(encoding="utf-8")
    session = SESSION.read_text(encoding="utf-8")
    runtime = RUNTIME.read_text(encoding="utf-8")
    target_runtime = TARGET_RUNTIME.read_text(encoding="utf-8")
    sampler = SAMPLER.read_text(encoding="utf-8")
    settings_window = SETTINGS_WINDOW.read_text(encoding="utf-8")
    sparkline = SPARKLINE.read_text(encoding="utf-8")
    metric_panel = METRIC_PANEL.read_text(encoding="utf-8")
    network_panel = NETWORK_PANEL.read_text(encoding="utf-8")
    runtime_panel = RUNTIME_PANEL.read_text(encoding="utf-8")
    core_grid = CORE_GRID.read_text(encoding="utf-8")
    process_table = PROCESS_TABLE.read_text(encoding="utf-8")
    activity_table = ACTIVITY_TABLE.read_text(encoding="utf-8")
    interface_table = INTERFACE_TABLE.read_text(encoding="utf-8")
    target_table = TARGET_TABLE.read_text(encoding="utf-8")
    target_inspector = TARGET_INSPECTOR.read_text(encoding="utf-8")
    widget_qmldir = WIDGET_QMLDIR.read_text(encoding="utf-8")
    require(widget_qmldir, "module qs.modules.settings.widgets",
            "shared Diagnostics widgets module")

    for widget in (
        "BtopActivityTable.qml",
        "BtopMetricPanel.qml",
        "BtopSparkline.qml",
        "BtopCoreGrid.qml",
        "BtopNetworkPanel.qml",
        "BtopRuntimePanel.qml",
        "BtopTargetTable.qml",
        "BtopProcessTable.qml",
        "BtopCoveragePanel.qml",
        "BtopTargetInspector.qml",
        "BtopInterfaceTable.qml",
        "BtopDashboard.qml",
    ):
        path = WIDGETS / widget
        if not path.is_file():
            raise AssertionError(f"missing diagnostics widget: {path}")
        require(widget_qmldir, f"{path.stem} 1.0 {widget}",
                "shared Diagnostics widgets module")

    for token in (
        'settingsPageIndex: 31',
        'settingsPageName: Translation.tr("Diagnostics")',
        "bottomContentPadding: 8",
        "fillViewportHeight: true",
        "Layout.fillHeight: true",
        "Layout.minimumHeight: 360",
        "readonly property bool diagnosticsActive:",
        "RuntimeDiagnosticsSession.pageCurrent",
        "readonly property var runtimeCatalog: root.diagnosticsActive",
        "readonly property var runtimeSnapshot: root.diagnosticsActive",
        "? CodeWorkflowRuntime.snapshot() : ({ records: [], events: [] })",
        "compactMode: true",
        "targets: root.runtimeCatalog",
        "readonly property string primaryError:",
        'Translation.tr("Diagnostics live")',
        "id: compactObservability",
        "visible: root.compactMode",
        "Layout.fillHeight: root.compactMode",
        "Layout.minimumHeight: root.compactMode ? 300 : 0",
        "columns: width >= 720 ? 2 : 1",
        "height >= 540 ? 10",
        ": height >= 470 ? 8",
        ": height >= 400 ? 6 : 5",
        "id: resourceSuspects",
        "compactObservability.width * 0.68",
        'Translation.tr("Resource suspects")',
        '"Top components and processes by meaningful runtime signals"',
        "id: compactShellContext",
        "compactObservability.width * 0.32",
        'Translation.tr("Quickshell monitors")',
        "columns: width >= 260 ? 2 : 1",
        "BtopActivityTable {",
        "BtopProcessTable {",
        "compactMode: true",
        "events: root.events",
        "id: compactRuntimeStrip",
        "Layout.preferredHeight: 52",
        "Layout.minimumHeight: 52",
        "graphHeight: 18",
        'root.historyValues("shellCpuPercent")',
        'root.historyValues("shellMemoryPercent")',
        'root.historyValues("shellGpuPeakPercent")',
        'root.historyValues("shellReadBytesPerSec")',
        'root.historyValues("shellWriteBytesPerSec")',
        "result.push(null)",
        "function shellMemorySharePercent(): var {",
        "function shellMemoryDetail(): string {",
        "function shellGpuBusy(): var {",
        "function shellGpuMemoryKiB(): var {",
        "return found ? total : null",
        "textFormat: Text.PlainText",
    ):
        require(page + board, token, "compact Material Diagnostics and dashboard")

    # The shipped standalone Settings window is 1100x750. Keep the compact
    # Diagnostics composition in its two-column observability layout at the
    # current content width, and never add a nested scrolling surface to make
    # the dashboard fit.
    require(settings_window, "width: 1100",
            "standalone Settings viewport width contract")
    require(settings_window, "height: 750",
            "standalone Settings viewport height contract")
    require(board, "columns: width >= 720 ? 2 : 1",
            "Diagnostics default-width two-column breakpoint")
    require(board, "columns: width >= 500 ? 2 : 1",
            "Resource suspects default-width split")
    require(board, "columns: width >= 260 ? 2 : 1",
            "Secondary context default-width micro-card split")
    require(board, "Layout.fillHeight: root.compactMode",
            "Diagnostics body must consume spare viewport height")
    require(board, "localScroll: true",
            "Component hotspots must scroll locally instead of truncating rows")
    require(board, "maxRows: compactObservability.suspectRowLimit",
            "Helper process list must use available vertical space")
    require(board, "Layout.preferredHeight: 52",
            "Hadalis runtime strip must retain visible hierarchy")
    forbid(board, "Flickable {",
           "Diagnostics dashboard must not add nested scrolling")

    compact_start = board.index("id: compactObservability")
    compact_end = board.index("id: compactRuntimeStrip")
    compact = board[compact_start:compact_end]
    for token in (
        "root.shellEvidence?.cpu?.percent",
        "root.shellMemorySharePercent()",
        "root.shellGpuBusy()",
        "root.shellEvidence?.io?.rates?.readBytesPerSec",
        "root.shellEvidence?.io?.rates?.writeBytesPerSec",
        'Translation.tr("I/O")',
    ):
        require(compact, token,
                "compact Diagnostics Quickshell-only monitor scope")
    for forbidden in (
        "root.systemEvidence?.cpu?.percent",
        "root.systemRamPercent()",
        "root.networkEvidence",
        "aggregateNonLoopback",
        'Translation.tr("Network")',
    ):
        forbid(compact, forbidden,
               "compact Diagnostics must not present system-wide monitors")

    for source, text in (
        ("Material ContentPage", content_page),
        ("Waffle WSettingsPage", waffle_base_page),
    ):
        require(text, "property bool fillViewportHeight: false",
                f"{source} must expose opt-in viewport filling")
        require(text, "Math.max(root.height,",
                f"{source} must fill spare height without clipping tall content")
        require(text, "Math.max(implicitHeight,",
                f"{source} must preserve scrolling when content exceeds viewport")

    for retired in (
        'title: Translation.tr("Live diagnostics")',
        'property bool showSourceDetails: false',
        'visible: root.showSourceDetails',
        'root.sampleIntervalLabel()',
        "BtopCoveragePanel {",
        "BtopTargetInspector {",
        'SettingsPageRegistry.navigateToKey(',
    ):
        forbid(page, retired, "compact Material Diagnostics page")

    for source, text in (("Material", page), ("Waffle", waffle_page)):
        require(text, "fillViewportHeight: true",
                f"{source} Diagnostics must opt into viewport filling")
        require(text, "BtopDashboard {", f"{source} shared diagnostics dashboard")
        require(text, "Layout.fillHeight: true",
                f"{source} Diagnostics dashboard must stretch vertically")
        require(text, "Layout.minimumHeight: 360",
                f"{source} Diagnostics must fall back to scrolling below its safe minimum")
        require(text, "compactMode: true", f"{source} compact diagnostics viewport")
        require(text, "evidence: root.evidence", f"{source} shared diagnostics evidence")
        require(text, "targets: root.runtimeCatalog", f"{source} Workflow target catalog")
        require(text, "records: root.runtimeRecords", f"{source} Workflow runtime records")
        require(text, "events: root.runtimeSnapshot?.events ?? []",
                f"{source} Workflow lifecycle event evidence")
        require(text, "readonly property var shellEvidence:",
                f"{source} Diagnostics must health-check Quickshell evidence")
        require(text, '"PID " + String(root.shellEvidence.pid)',
                f"{source} status strip must identify the Quickshell PID")
        forbid(text, "readonly property var systemEvidence:",
               f"{source} page must not expose system evidence as page health")
        forbid(text, 'Translation.tr("Uptime")',
               f"{source} status strip must not show system uptime")
        forbid(text, 'buttonText: root.showSourceDetails',
               f"{source} must not expose source-details expansion")
        forbid(text, 'buttonText: root.showDetails',
               f"{source} must not expose live-sampling details expansion")
    require(waffle_page, "import qs.modules.settings.widgets",
            "Waffle must load the registered shared widgets module")
    require(board, "processes: root.shellEvidence?.children ?? []",
            "shared process table must contain shell descendants")
    require(board, "history: root.evidence?.history ?? []",
            "shared core grid must consume sampled histories")

    for token in (
        "function safeValues(): var {",
        "width: root.runtimeObject.width",
        "height: root.runtimeObject.height",
        "visible: root.runtimeObject.visible",
        "enabled: root.runtimeObject.enabled",
    ):
        require(target_runtime, token, "CodeWorkflowRuntimeTarget.qml")

    for token in (
        "readonly property bool pageCurrent:",
        "RuntimeDiagnostics.acquire(root.clientId)",
        "RuntimeDiagnostics.release(root.clientId)",
        'property string leaseTransport: ""',
        'const transport = root.leaseTransport',
        'const desiredTransport = root.localShell ? "local" : "remote"',
        "running: root.pageCurrent",
    ):
        require(session, token, "RuntimeDiagnosticsSession.qml")

    for token in (
        "Canvas {",
        "ctx.lineTo(",
        "ctx.strokeStyle = root.lineColor",
        "ctx.fillStyle = Qt.rgba(",
        "values.push(null)",
        "values.some(value => value !== null)",
        "while (lastIndex >= 0 && values[lastIndex] === null)",
    ):
        require(sparkline, token, "BtopSparkline.qml")

    for source, text in (
        ("BtopMetricPanel.qml", metric_panel),
        ("BtopNetworkPanel.qml", network_panel),
        ("BtopRuntimePanel.qml", runtime_panel),
        ("BtopCoreGrid.qml", core_grid),
        ("BtopProcessTable.qml", process_table),
        ("BtopInterfaceTable.qml", interface_table),
    ):
        require(
            text,
            "Appearance.font.family.monospace",
            f"{source} btop typography",
        )
        require(
            text,
            "Appearance.rounding.small",
            f"{source} compact btop geometry",
        )
        require(
            text,
            "textFormat: Text.PlainText",
            f"{source} plain diagnostics text",
        )

    for token in (
        "id: rateHeader",
        "columns: width >= 360 ? 2 : 1",
        "id: totalsGrid",
        "columns: root.compactMode ? 2 : (width >= 360 ? 2 : 1)",
        "horizontalAlignment: root.compactMode",
        "|| rateHeader.width >= 360",
        "horizontalAlignment: totalsGrid.width >= 360",
    ):
        require(
            network_panel, token,
            "BtopNetworkPanel.qml narrow responsive layout",
        )

    require(
        runtime_panel,
        "columns: width >= 520 ? 3 : 1",
        "BtopRuntimePanel.qml narrow responsive rate layout",
    )

    require(
        target_table,
        "readonly property bool showOutputColumn: width >= 520",
        "BtopTargetTable.qml narrow responsive layout",
    )

    for token in (
        "const selectedId = String(root.selectedTargetId ?? \"\")",
        "visible.some(target =>",
        "const selected = source.find(target =>",
    ):
        require(target_table, token, "BtopTargetTable.qml selected target visibility")

    for token in (
        "readonly property var recordIndex: root.buildRecordIndex()",
        "function buildRecordIndex(): var",
        "root.recordIndex.all[id] ?? []",
        "root.recordIndex.resident[id] ?? []",
    ):
        require(target_table, token, "BtopTargetTable.qml runtime record index")

    for token in (
        "readonly property var processRows:",
        "Array.isArray(root.processes) ? root.processes : []",
        "readonly property var processDepths: root.buildProcessDepths()",
        "function buildProcessDepths(): var",
        "readonly property int processDepth:",
        "property bool compactMode: false",
        "implicitHeight: 38",
        'Translation.tr("Top helper processes")',
        'Translation.tr("Kernel process CPU · RSS")',
        "function cpuFraction(process): real",
        "visible: !root.compactMode",
    ):
        require(process_table, token,
                "BtopProcessTable.qml compact real-process evidence")

    for token in (
        'text: Translation.tr("Component hotspots")',
        'Lifecycle activity — not CPU/RAM attribution',
        "function buildActivityRows(): var",
        "row.resident += 1",
        "row.visible += 1",
        "row.recentEvents += 1",
        "event?.atMs",
        "right.eventsPerMinute - left.eventsPerMinute",
        'Translation.tr("changes/min")',
        "property int maxRows: 5",
        "property bool localScroll: false",
        "readonly property var renderedRows:",
        "StyledListView {",
        "model: root.renderedRows",
        "interactive: root.localScroll && contentHeight > height",
        "visible: !root.localScroll",
        "RuntimeDiagnosticsSession.pageCurrent",
        "RuntimeDiagnosticsSession.heartbeatTick",
    ):
        require(activity_table, token,
                "BtopActivityTable.qml truthful lifecycle activity")

    for forbidden in (
        "formatPercent(",
        "valuesKiB",
        "cpuPercent",
        "memoryPercent",
    ):
        forbid(activity_table, forbidden,
               "QML activity must never masquerade as per-component resources")

    for source, text in (
        ("BtopProcessTable.qml", process_table),
        ("BtopInterfaceTable.qml", interface_table),
        ("BtopTargetTable.qml", target_table),
        ("BtopTargetInspector.qml", target_inspector),
    ):
        require(
            text,
            "textFormat: Text.PlainText",
            f"{source} literal diagnostics text",
        )

    for token in (
        "if (value === null || value === undefined)",
        "readonly property bool showSwapColumn:",
        "!root.compactMode && width >= 520",
        "Layout.preferredHeight: 24",
    ):
        require(process_table, token, "BtopProcessTable.qml")
    for token in (
        "if (value === null || value === undefined)",
        "readonly property bool showTotalColumn: width >= 520",
        "property int maxRows: 8",
        "readonly property var visibleRows:",
        "? null : Number(data.rxBytesPerSec)",
        "? null : Number(data.txBytesPerSec)",
    ):
        require(interface_table, token, "BtopInterfaceTable.qml")

    for token in (
        "systemSwapPercent:",
        "shellMemoryPercent:",
        "shellReadBytesPerSec:",
        "shellWriteBytesPerSec:",
        "if (used === null || used === undefined",
        "const raw = engines[key]",
        "slice(-root.historyLimit)",
        'running: root.samplingEnabled',
    ):
        require(runtime, token, "RuntimeDiagnostics.qml")

    for token in (
        "def read_system_cpu_ticks() -> dict[str, tuple[int, int]]:",
        '"Cached": values.get("Cached")',
        '"Buffers": values.get("Buffers")',
        "def _cpu_percent_from_ticks(",
        '"coresPercent": core_cpu_percent',
        '"coreNames": core_names',
        '"loadAverage": load_average',
        '"uptimeSeconds": uptime_seconds',
        "def read_load_average()",
        "def read_uptime_seconds()",
        "refresh_slow = (",
        "slow_elapsed_ns >= 2_000_000_000",
        '"slow": slow_state',
        '"children": child_rows',
        "def sample_children(",
        "def read_process_children(",
        "def read_process_start_ticks(",
        "cursor = 0",
        "while cursor < len(queue):",
        "read_process_start_ticks(child_pid) != start_ticks",
        "target_start_ticks = read_process_start_ticks(args.pid)",
        "if read_process_start_ticks(args.pid) != target_start_ticks:",
        '"startTicks": start_ticks',
        'task_dir = Path("/proc") / str(pid) / "task"',
        'text = _read_text(task / "children").strip()',
        "aggregate_interface_count = 0",
        "aggregate_has_rx_rate = True",
        "aggregate_has_tx_rate = True",
        "if rx_rate is None:",
        "if tx_rate is None:",
        'return comm or f"pid-{pid}"',
        r're.fullmatch(r"cpu(?:\d+)?"',
    ):
        require(sampler, token, "runtime-diagnostics-sampler.py")

    forbid(sampler, "cmdline", "runtime-diagnostics-sampler.py")
    forbid(sampler, "queue.pop(0)", "runtime-diagnostics-sampler.py")
    if sampler.count(
            "read_process_start_ticks(args.pid) != target_start_ticks") < 2:
        raise SystemExit(
            "FAIL: sampler must verify shell PID identity before and after sampling"
        )

    code = compile(sampler, str(SAMPLER), "exec")
    namespace = {"__name__": "runtime_diagnostics_contract"}
    exec(code, namespace)
    helper = namespace["_cpu_percent_from_ticks"]
    measured = helper((200, 100), (100, 50))
    if measured is None or abs(measured - 50.0) > 0.001:
        raise AssertionError(
            f"unexpected per-core CPU delta calculation: {measured!r}"
        )

    print("Runtime Diagnostics btop contract: PASS")


if __name__ == "__main__":
    main()
