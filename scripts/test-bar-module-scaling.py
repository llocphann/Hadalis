#!/usr/bin/env python3
"""Guard responsive Classic Bar sizing without scaling detached popup contents."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCALE = "Appearance.sizes.barModuleScale"


def source(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def check(path: str, *contracts: str) -> None:
    content = source(path)
    missing = [part for part in contracts if part not in content]
    if missing:
        raise SystemExit(f"{path}: missing responsive sizing contracts: {missing!r}")


def main() -> None:
    appearance = source("modules/common/Appearance.qml")
    check("modules/common/Appearance.qml",
          "property real barModuleScale:",
          "baseBarHeight: Math.round(40 * barModuleScale * root.fontSizeScale)",
          "baseVerticalBarWidth: Math.round(46 * root.fontSizeScale * barModuleScale)")

    # The configured 24..80px range preserves the original 40px baseline.
    assert [max(24, min(80, n)) / 40 for n in (24, 40, 80)] == [0.6, 1.0, 2.0]
    assert [round(46 * n / 40) for n in (24, 40, 80)] == [28, 46, 92]
    assert "property real barModuleScale:" in appearance

    for path, contracts in {
        "modules/bar/BarContent.qml": ("moduleGap:", "buttonPadding: 5 * " + SCALE),
        "modules/bar/BarGroup.qml": ("property real padding: 8 * " + SCALE, "moduleSpacing: (root.vertical ? 12 : 4) * " + SCALE),
        "modules/bar/Workspaces.qml": ("workspaceButtonWidth: Math.round(26 * " + SCALE + ")",),
        "modules/bar/ClockWidget.qml": ("_timePixelSize * " + SCALE, "_datePixelSize * " + SCALE),
        "modules/bar/Media.qml": ("implicitSize: Math.round(22 * " + SCALE + ")",),
        "modules/bar/Resource.qml": ("implicitSize: Math.round(20 * " + SCALE + ")",),
        "modules/bar/BatteryIndicator.qml": ("valueBarWidth: Math.round(30 * " + SCALE + ")",),
        "modules/bar/UtilButtons.qml": ("iconSize: Math.round(Appearance.font.pixelSize.large * " + SCALE + ")",),
        "modules/bar/SysTrayItem.qml": ("property real sizeScale: " + SCALE, "implicitWidth: 18 * root.sizeScale", "implicitHeight: 18 * root.sizeScale"),
        "modules/bar/SysTray.qml": ("sizeScale: 1",),
        "modules/bar/ActiveWindow.qml": ("rowOverlap: root.showTitle ? 2 * " + SCALE, "font.pixelSize: Math.round(Appearance.font.pixelSize.smaller * " + SCALE + ")"),
        "modules/bar/TimerIndicator.qml": ("34 * " + SCALE, "30 * " + SCALE),
        "modules/bar/ShellUpdateIndicator.qml": ("34 * " + SCALE, "30 * " + SCALE),
        "modules/bar/weather/WeatherBar.qml": ("34 * " + SCALE,),
        "modules/bar/BarTaskbar.qml": ("contentInset: 8 * " + SCALE, "barSize: vertical"),
        "modules/bar/BarTaskbarButton.qml": ("buttonSize: barSize - 4 * " + SCALE,),
        "modules/verticalBar/VerticalBarContent.qml": ("Math.max(34 * " + SCALE, "moduleGap:"),
        "modules/verticalBar/VerticalClockWidget.qml": ("Math.round(Appearance.font.pixelSize.large * " + SCALE + ")",),
        "modules/verticalBar/VerticalDateWidget.qml": ("implicitWidth: 24 * " + SCALE,),
        "modules/verticalBar/VerticalMedia.qml": ("implicitSize: Math.round(20 * " + SCALE + ")",),
        "modules/verticalBar/Resource.qml": ("implicitSize: Math.round(24 * Appearance.fontSizeScale * " + SCALE + ")",),
    }.items():
        check(path, *contracts)

    # The update popup is not an inline Bar child and must retain global font sizing.
    inline, popup = source("modules/bar/ShellUpdateIndicator.qml").split("    // Hover popup", 1)
    assert SCALE in inline
    assert "iconSize: Appearance.font.pixelSize.large" in popup
    print("Classic Bar responsive module sizing contract: OK")


if __name__ == "__main__":
    main()
