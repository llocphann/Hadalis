#!/usr/bin/env python3
"""Regression contract for the btop-style Runtime Diagnostics settings page."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PAGE = ROOT / "modules" / "settings" / "RuntimeDiagnosticsConfig.qml"
SPARKLINE = ROOT / "modules" / "settings" / "widgets" / "BtopSparkline.qml"
METRIC_PANEL = ROOT / "modules" / "settings" / "widgets" / "BtopMetricPanel.qml"
NETWORK_PANEL = ROOT / "modules" / "settings" / "widgets" / "BtopNetworkPanel.qml"
RUNTIME_PANEL = ROOT / "modules" / "settings" / "widgets" / "BtopRuntimePanel.qml"
CORE_GRID = ROOT / "modules" / "settings" / "widgets" / "BtopCoreGrid.qml"
PROCESS_TABLE = ROOT / "modules" / "settings" / "widgets" / "BtopProcessTable.qml"
INTERFACE_TABLE = ROOT / "modules" / "settings" / "widgets" / "BtopInterfaceTable.qml"
SESSION = ROOT / "services" / "RuntimeDiagnosticsSession.qml"
RUNTIME = ROOT / "services" / "RuntimeDiagnostics.qml"
TARGET_RUNTIME = ROOT / "services" / "CodeWorkflowRuntimeTarget.qml"
SAMPLER = ROOT / "scripts" / "runtime-diagnostics-sampler.py"
WIDGETS = ROOT / "modules" / "settings" / "widgets"


def require(text: str, token: str, source: str) -> None:
    if token not in text:
        raise AssertionError(f"{source} is missing diagnostics token: {token!r}")


def forbid(text: str, token: str, source: str) -> None:
    if token in text:
        raise AssertionError(f"{source} contains forbidden diagnostics token: {token!r}")


def main() -> None:
    page = PAGE.read_text(encoding="utf-8")
    session = SESSION.read_text(encoding="utf-8")
    runtime = RUNTIME.read_text(encoding="utf-8")
    target_runtime = TARGET_RUNTIME.read_text(encoding="utf-8")
    sampler = SAMPLER.read_text(encoding="utf-8")
    sparkline = SPARKLINE.read_text(encoding="utf-8")
    metric_panel = METRIC_PANEL.read_text(encoding="utf-8")
    network_panel = NETWORK_PANEL.read_text(encoding="utf-8")
    runtime_panel = RUNTIME_PANEL.read_text(encoding="utf-8")
    core_grid = CORE_GRID.read_text(encoding="utf-8")
    process_table = PROCESS_TABLE.read_text(encoding="utf-8")
    interface_table = INTERFACE_TABLE.read_text(encoding="utf-8")

    for widget in (
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
    ):
        path = WIDGETS / widget
        if not path.is_file():
            raise AssertionError(f"missing diagnostics widget: {path}")

    for token in (
        'settingsPageIndex: 31',
        'settingsPageName: Translation.tr("Diagnostics")',
        "BtopMetricPanel {",
        "BtopNetworkPanel {",
        "BtopCoreGrid {",
        "coreNames: root.cpuCoreNames",
        "BtopRuntimePanel {",
        "swap: root.formatKiB(",
        "BtopTargetTable {",
        "BtopProcessTable {",
        "BtopCoveragePanel {",
        "BtopTargetInspector {",
        "BtopInterfaceTable {",
        "selectedTargetId: CodeWorkflowSession.selectedTargetId",
        "CodeWorkflowSession.selectTarget(",
        'SettingsPageRegistry.navigateToKey(',
        'root.historyValues("systemCpuPercent")',
        'root.historyValues("systemSwapPercent")',
        'root.historyValues("shellGpuPeakPercent")',
        'root.historyValues("shellReadBytesPerSec")',
        'root.historyValues("shellWriteBytesPerSec")',
        "result.push(null)",
        "root.formatLoadAverage(",
        "root.formatUptime(",
        "root.sampleIntervalLabel()",
        "function shellGpuBusy(): var {",
        "function shellGpuMemoryKiB(): var {",
        "return found ? total : null",
    ):
        require(page, token, "RuntimeDiagnosticsConfig.qml")

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

    for token in (
        "if (value === null || value === undefined)",
        "readonly property bool showSwapColumn: width >= 520",
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
        "shellReadBytesPerSec:",
        "shellWriteBytesPerSec:",
        "if (used === null || used === undefined",
        "const raw = engines[key]",
        "slice(-60)",
        'running: root.samplingEnabled',
    ):
        require(runtime, token, "RuntimeDiagnostics.qml")

    for token in (
        "def read_system_cpu_ticks() -> dict[str, tuple[int, int]]:",
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
        're.fullmatch(r"cpu(?:\d+)?"',
    ):
        require(sampler, token, "runtime-diagnostics-sampler.py")

    forbid(sampler, '/ "cmdline"', "runtime-diagnostics-sampler.py")

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
