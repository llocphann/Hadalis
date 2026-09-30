pragma ComponentBehavior: Bound

import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import Quickshell
import QtQuick
import QtQuick.Layouts

MouseArea {
    id: root
    // A pointer click can retain activeFocus after hover ends. Keep popup
    // keyboard focus affordance without treating pointer focus as hover.
    property bool _pointerFocused: false
    onPressed: root._pointerFocused = true
    onActiveFocusChanged: {
        if (!root.activeFocus)
            root._pointerFocused = false
    }
    property bool vertical: false
    property color foregroundColor: root.vertical
        ? Appearance.colors.colOnLayer0
        : Appearance.colors.colOnLayer1

    implicitWidth: root.vertical ? 34 * Appearance.sizes.barModuleScale : rowLayout.implicitWidth + 20 * Appearance.sizes.barModuleScale
    implicitHeight: root.vertical ? 34 * Appearance.sizes.barModuleScale : Appearance.sizes.barHeight

    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    activeFocusOnTab: true

    Accessible.role: Accessible.Button
    Accessible.name: Translation.tr("Weather")
    Accessible.focusable: true

    function activatePrimary(): void {
        GlobalStates.sidebarRightRequestedWidget = "weather"
        GlobalStates.openSidebarRight(root.QsWindow.window?.screen?.name ?? "")
    }

    Keys.onPressed: event => {
        if (event.isAutoRepeat
                || (event.key !== Qt.Key_Return
                    && event.key !== Qt.Key_Enter
                    && event.key !== Qt.Key_Space))
            return
        root.activatePrimary()
        event.accepted = true
    }

    // Left-click opens the right sidebar's Weather tab; right-click refreshes.
    onClicked: (mouse) => {
        if (mouse.button === Qt.RightButton) {
            Weather.forceRefresh();
            Quickshell.execDetached(["/usr/bin/notify-send",
                Translation.tr("Weather"),
                Translation.tr("Refreshing (manually triggered)")
                , "-a", "Shell"
            ])
            return
        }
        root.activatePrimary()
    }

    KeyboardFocusRing {
        anchors.fill: parent
        focusVisible: root.activeFocus
    }

    RowLayout {
        id: rowLayout
        anchors.centerIn: parent

        MaterialSymbol {
            fill: 0
            text: Icons.getWeatherIcon(Weather.data?.wCode, Weather.isNightNow()) ?? "cloud"
            iconSize: Math.round(Appearance.font.pixelSize.large * Appearance.sizes.barModuleScale)
            color: root.foregroundColor
            Layout.alignment: Qt.AlignVCenter
        }

        StyledText {
            visible: !root.vertical
            font.pixelSize: Math.round(Appearance.font.pixelSize.small * Appearance.sizes.barModuleScale)
            color: root.foregroundColor
            text: Weather.data?.temp ?? "--°"
            Layout.alignment: Qt.AlignVCenter
        }
    }

    WeatherPopup {
        id: weatherPopup
        hoverTarget: root
        alternativeVisibleCondition: root.activeFocus && !root._pointerFocused
    }
}
