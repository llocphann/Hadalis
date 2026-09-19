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
    property bool vertical: false
    property color foregroundColor: root.vertical
        ? Appearance.colors.colOnLayer0
        : Appearance.colors.colOnLayer1

    implicitWidth: root.vertical ? 34 : rowLayout.implicitWidth + 10 * 2
    implicitHeight: root.vertical ? 34 : Appearance.sizes.barHeight

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
            iconSize: Appearance.font.pixelSize.large
            color: root.foregroundColor
            Layout.alignment: Qt.AlignVCenter
        }

        StyledText {
            visible: !root.vertical
            font.pixelSize: Appearance.font.pixelSize.small
            color: root.foregroundColor
            text: Weather.data?.temp ?? "--°"
            Layout.alignment: Qt.AlignVCenter
        }
    }

    WeatherPopup {
        id: weatherPopup
        hoverTarget: root
        alternativeVisibleCondition: root.activeFocus
    }
}
