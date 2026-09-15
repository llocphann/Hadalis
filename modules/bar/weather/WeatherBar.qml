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
    property bool hovered: false
    implicitWidth: rowLayout.implicitWidth + 10 * 2
    implicitHeight: Appearance.sizes.barHeight

    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    activeFocusOnTab: true

    Accessible.role: Accessible.Button
    Accessible.name: Translation.tr("Weather")
    Accessible.focusable: true

    // Easter egg: 5 rapid taps summon her with the umbrella
    property int _eggTaps: 0
    Timer { id: eggTapWindow; interval: 3000; onTriggered: root._eggTaps = 0 }

    function activatePrimary(): void {
        root._eggTaps++
        eggTapWindow.restart()
        if (root._eggTaps >= 5 && (Config.options?.mascot?.enable ?? false)) {
            root._eggTaps = 0
            Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "mascot", "appear", "weather-umbrella", "top"])
        }
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

    RowLayout {
        id: rowLayout
        anchors.centerIn: parent

        MaterialSymbol {
            fill: 0
            text: Icons.getWeatherIcon(Weather.data?.wCode, Weather.isNightNow()) ?? "cloud"
            iconSize: Appearance.font.pixelSize.large
            color: Appearance.angelEverywhere ? Appearance.angel.colText
                : Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer1
            Layout.alignment: Qt.AlignVCenter
        }

        StyledText {
            visible: true
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.angelEverywhere ? Appearance.angel.colText
                : Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer1
            text: Weather.data?.temp ?? "--°"
            Layout.alignment: Qt.AlignVCenter
        }
    }

    WeatherPopup {
        id: weatherPopup
        hoverTarget: root
    }
}
