#!/usr/bin/env python3
"""Guard adaptive Classic Bar packing around the Workspaces pivot."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def require(source: str, token: str, message: str) -> None:
    if token not in source:
        raise SystemExit(message)


def forbid(source: str, token: str, message: str) -> None:
    if token in source:
        raise SystemExit(message)


def main() -> None:
    bar = read("modules/bar/BarContent.qml")
    group = read("modules/bar/BarGroup.qml")
    util = read("modules/bar/UtilButtons.qml")
    vertical = read("modules/verticalBar/VerticalBarContent.qml")

    for token in (
        "readonly property real edgeInset:",
        "readonly property real moduleGap:",
        "readonly property real zoneGapNominal:",
        "readonly property real zoneGapMinimum:",
        "readonly property real pivotGapNominal:",
        "readonly property real pivotGapMinimum:",
        "readonly property real leftPressure:",
        "readonly property real rightPressure:",
        "readonly property real leftCenterMaxWidth:",
        "readonly property real rightCenterMaxWidth:",
        "property bool horizontalUtilitiesCompact: false",
        "compactRequested: root.horizontalUtilitiesCompact",
        "contentHorizontalAlignment: Qt.AlignRight",
        "contentHorizontalAlignment: Qt.AlignLeft",
        "z: root.horizontalUtilitiesCompact ? 2 : 0",
        'clipContent: !(root.horizontalUtilitiesCompact',
        "spacing: root.moduleGap",
    ):
        require(bar, token, f"adaptive horizontal Bar contract missing: {token}")

    forbid(bar, "centerPillMirrorSlack",
           "Center-side groups must not recover mirrored-width dead space.")
    forbid(bar, 'Layout.leftMargin: modelData === "weather" ? 4 : 0',
           "Weather must not carry a one-off spacing exception.")

    require(group, "property real moduleSpacing:",
            "BarGroup must expose semantic module spacing.")
    require(group, "property int contentHorizontalAlignment: Qt.AlignHCenter",
            "BarGroup must support pivot-facing content alignment.")

    for token in (
        "property bool compactRequested: false",
        "readonly property bool inlineExpanded:",
        "readonly property real expandedMainAxisLength:",
        "readonly property real compactMainAxisLength:",
        "id: compactTrigger",
        "id: controlsRevealer",
        "reveal: root.inlineExpanded",
    ):
        require(util, token, f"inline utility contract missing: {token}")
    forbid(util, "StyledPopup {",
           "Utilities must reveal on the Bar, not in a popup.")
    forbid(util, "PopupWindow {",
           "Utilities must not allocate a second native surface.")

    for token in (
        "readonly property real edgeInset:",
        "readonly property real moduleGap:",
        "readonly property real zoneGapNominal:",
        "readonly property real pivotGapNominal:",
        "readonly property real topPressure:",
        "readonly property real bottomPressure:",
        "property bool verticalUtilitiesCompact: false",
        "compactRequested: root.verticalUtilitiesCompact",
        "verticalCenter: parent.verticalCenter",
        "id: upperHalf",
        "id: lowerHalf",
        "interactive: contentHeight > height + 0.5",
    ):
        require(vertical, token, f"adaptive vertical Bar contract missing: {token}")

    forbid(vertical, "Flickable { // Middle section",
           "Vertical Workspaces must not drift inside one centered middle stack.")
    forbid(vertical, "moduleLoader.item.visible",
           "Adaptive vertical packing must not depend on effective child visibility.")
    forbid(vertical, "visible: implicitHeight > 0",
           "Vertical zones must bootstrap through natural size, not parent visibility.")
    require(vertical, "width: parent.width",
            "Vertical module Loader must constrain only the cross axis.")
    require(vertical, "anchors.horizontalCenter: parent.horizontalCenter",
            "Vertical module Loader must leave main-axis height natural.")

    print("Bar adaptive packing contract: OK")


if __name__ == "__main__":
    main()
