#!/usr/bin/env python3
"""Regression contract for compact tabbed media sources in Bar Media Popup."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "modules/mediaControls/BarMediaPopup.qml"


def main() -> None:
    source = SOURCE.read_text(encoding="utf-8")

    required = (
        "property int currentTab: 0",
        "readonly property int tabCount: root._visiblePlayers.length",
        "function syncCurrentTabToActivePlayer(): void",
        "function selectTab(index): void",
        "MprisController.setActivePlayer(player)",
        "id: playerViewport",
        "clip: true",
        "id: playerRepeater",
        "y: (playerDelegate.index - root.currentTab)",
        "Behavior on y",
        "duration: root.tabSlideDuration",
        "id: tabIndicator",
        "anchors.right: parent.right",
        "anchors.verticalCenter: parent.verticalCenter",
        "model: root.tabCount",
        "width: 7",
        "height: 7",
        "radius: width / 2",
        "indicatorDot.index === root.currentTab",
        "Translation.tr(\"Switch media source\")",
        "WheelHandler {",
        "orientation: Qt.Vertical",
        "EqualizerPanel {",
    )
    for token in required:
        if token not in source:
            raise AssertionError(
                f"Bar Media Popup missing tabbed-source contract token: {token!r}"
            )

    forbidden = (
        "width: 3\n                    radius: 2",
        "visible: !isActive && root._visiblePlayers.length > 1",
        "implicitHeight: root.widgetHeight + (isActive",
    )
    for token in forbidden:
        if token in source:
            raise AssertionError(
                f"Bar Media Popup still contains stacked source selector: {token!r}"
            )

    if source.count("EqualizerPanel {") != 1:
        raise AssertionError("Equalizer must remain one shared section below media tabs")

    print("Bar Media Popup tabbed media-source contract: OK")


if __name__ == "__main__":
    main()
