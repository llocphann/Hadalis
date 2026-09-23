#!/usr/bin/env python3
"""Regression contract for the btop-style Runtime Diagnostics settings page."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PAGE = ROOT / "modules" / "settings" / "RuntimeDiagnosticsConfig.qml"
SESSION = ROOT / "services" / "RuntimeDiagnosticsSession.qml"
RUNTIME = ROOT / "services" / "RuntimeDiagnostics.qml"
SAMPLER = ROOT / "scripts" / "runtime-diagnostics-sampler.py"
WIDGETS = ROOT / "modules" / "settings" / "widgets"


def require(text: str, token: str, source: str) -> None:
    if token not in text:
        raise AssertionError(f"{source} is missing diagnostics token: {token!r}")


def main() -> None:
    page = PAGE.read_text(encoding="utf-8")
    session = SESSION.read_text(encoding="utf-8")
    runtime = RUNTIME.read_text(encoding="utf-8")
    sampler = SAMPLER.read_text(encoding="utf-8")

    for widget in (
        "BtopMetricPanel.qml",
        "BtopSparkline.qml",
        "BtopCoreGrid.qml",
        "BtopNetworkPanel.qml",
        "BtopRuntimePanel.qml",
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
        'root.historyValues("systemCpuPercent")',
        'root.historyValues("systemSwapPercent")',
        'root.historyValues("shellGpuPeakPercent")',
        'root.historyValues("shellReadBytesPerSec")',
        'root.historyValues("shellWriteBytesPerSec")',
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
        "systemSwapPercent:",
        "shellReadBytesPerSec:",
        "shellWriteBytesPerSec:",
        "slice(-60)",
        'running: root.samplingEnabled',
    ):
        require(runtime, token, "RuntimeDiagnostics.qml")

    for token in (
        "def read_system_cpu_ticks() -> dict[str, tuple[int, int]]:",
        "def cpu_percent(",
        '"coresPercent": core_cpu_percent',
        're.fullmatch(r"cpu(?:\\d+)?"',
    ):
        require(sampler, token, "runtime-diagnostics-sampler.py")

    compile(sampler, str(SAMPLER), "exec")
    print("Runtime Diagnostics btop contract: PASS")


if __name__ == "__main__":
    main()
