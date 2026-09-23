#!/usr/bin/env python3
"""Regression contract for the btop-style Runtime Diagnostics settings page."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PAGE = ROOT / "modules" / "settings" / "RuntimeDiagnosticsConfig.qml"
SPARKLINE = ROOT / "modules" / "settings" / "widgets" / "BtopSparkline.qml"
SESSION = ROOT / "services" / "RuntimeDiagnosticsSession.qml"
RUNTIME = ROOT / "services" / "RuntimeDiagnostics.qml"
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
    sampler = SAMPLER.read_text(encoding="utf-8")
    sparkline = SPARKLINE.read_text(encoding="utf-8")

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
        "BtopRuntimePanel {",
        "BtopTargetTable {",
        "BtopProcessTable {",
        "BtopCoveragePanel {",
        "BtopTargetInspector {",
        "selectedTargetId: CodeWorkflowSession.selectedTargetId",
        "CodeWorkflowSession.selectTarget(",
        'SettingsPageRegistry.navigateToKey(',
        'root.historyValues("systemCpuPercent")',
        'root.historyValues("systemSwapPercent")',
        'root.historyValues("shellGpuPeakPercent")',
        'root.historyValues("shellReadBytesPerSec")',
        'root.historyValues("shellWriteBytesPerSec")',
        "root.formatLoadAverage(",
        "root.formatUptime(",
    ):
        require(page, token, "RuntimeDiagnosticsConfig.qml")

    for token in (
        "readonly property bool pageCurrent:",
        "RuntimeDiagnostics.acquire(root.clientId)",
        "RuntimeDiagnostics.release(root.clientId)",
        "running: root.pageCurrent",
    ):
        require(session, token, "RuntimeDiagnosticsSession.qml")

    for token in (
        "Canvas {",
        "ctx.lineTo(",
        "ctx.strokeStyle = root.lineColor",
        "ctx.fillStyle = Qt.rgba(",
    ):
        require(sparkline, token, "BtopSparkline.qml")

    for token in (
        "systemSwapPercent:",
        "shellReadBytesPerSec:",
        "shellWriteBytesPerSec:",
        "slice(-60)",
        'running: root.samplingEnabled',
    ):
        require(runtime, token, "RuntimeDiagnostics.qml")

    for token in (
        "def read_system_cpu_ticks() -> dict[str, tuple[int, int]]:",
        "def _cpu_percent_from_ticks(",
        '"coresPercent": core_cpu_percent',
        '"loadAverage": load_average',
        '"uptimeSeconds": uptime_seconds',
        "def read_load_average()",
        "def read_uptime_seconds()",
        '"children": child_rows',
        "def sample_children(",
        'task_dir = Path("/proc") / str(pid) / "task"',
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
