import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    property bool compactMode: false
    property bool centerMode: true
    property bool showTabBar: true
    property bool showPinButton: true
    property int currentTab: Persistent.states?.timer?.tab ?? 0
    property var tabButtonList: [
        {"name": Translation.tr("Pomodoro"), "icon": "search_activity"},
        {"name": Translation.tr("Timer"), "icon": "hourglass_empty"},
        {"name": Translation.tr("Stopwatch"), "icon": "timer"}
    ]

    onCurrentTabChanged: {
        if (Persistent?.states?.timer)
            Persistent.states.timer.tab = root.currentTab
    }

    // Style tokens
    readonly property color colText: Appearance.angelEverywhere ? Appearance.angel.colText
        : Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer1
    readonly property color colTextSecondary: Appearance.angelEverywhere ? Appearance.angel.colTextSecondary
        : Appearance.inirEverywhere ? Appearance.inir.colTextSecondary : Appearance.colors.colSubtext
    readonly property color colPrimary: Appearance.angelEverywhere ? Appearance.angel.colPrimary
        : Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary
    readonly property color colBorder: Appearance.angelEverywhere ? Appearance.angel.colCardBorder
        : Appearance.inirEverywhere ? Appearance.inir.colBorder 
        : Appearance.auroraEverywhere ? "transparent"
        : Appearance.colors.colOutlineVariant

    Keys.onPressed: (event) => {
        if ((event.key === Qt.Key_PageDown || event.key === Qt.Key_PageUp) && event.modifiers === Qt.NoModifier) {
            if (event.key === Qt.Key_PageDown) {
                currentTab = Math.min(currentTab + 1, root.tabButtonList.length - 1)
            } else if (event.key === Qt.Key_PageUp) {
                currentTab = Math.max(currentTab - 1, 0)
            }
            event.accepted = true
        } else if (event.key === Qt.Key_Space || event.key === Qt.Key_S) {
            if (currentTab === 0) TimerService.togglePomodoro()
            else if (currentTab === 1) TimerService.toggleCountdown()
            else TimerService.toggleStopwatch()
            event.accepted = true
        } else if (event.key === Qt.Key_R) {
            if (currentTab === 0) TimerService.resetPomodoro()
            else if (currentTab === 1) TimerService.resetCountdown()
            else TimerService.stopwatchReset()
            event.accepted = true
        } else if (event.key === Qt.Key_L) {
            TimerService.stopwatchRecordLap()
            event.accepted = true
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Tab bar row with pin button
        Item {
            Layout.fillWidth: true
            visible: root.showTabBar || root.showPinButton
            implicitHeight: visible
                ? Math.max(tabBar.implicitHeight, pinButton.implicitHeight)
                : 0

            PillTabBar {
                id: tabBar
                visible: root.showTabBar
                anchors.horizontalCenter: parent.horizontalCenter
                // Compact corner mode gets enough width for Pomodoro/Timer/
                // Stopwatch without changing the popup's outer dimensions.
                width: Math.max(root.compactMode ? 210 : 150, Math.min(
                    root.compactMode ? 296 : 260,
                    parent.width - (root.showPinButton
                        ? (pinButton.width + 6) * 2 : 0)))
                pillHeight: root.compactMode ? 28 : 30
                currentIndex: root.currentTab
                tabs: root.tabButtonList.map(item => ({
                    icon: item.icon, label: item.name
                }))
                onTabSelected: index => root.currentTab = index

                WheelHandler {
                    acceptedDevices:
                        PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: event => {
                        const step = event.angleDelta.y < 0 ? 1 : -1
                        root.currentTab = Math.max(0, Math.min(
                            root.tabButtonList.length - 1,
                            root.currentTab + step))
                    }
                }
            }

            IconToolbarButton {
                id: pinButton
                visible: root.showPinButton
                anchors.right: parent.right
                anchors.verticalCenter: tabBar.verticalCenter
                text: "push_pin"
                toggled: Persistent.states?.timer?.pinnedToBar ?? false
                onClicked: {
                    if (Persistent?.states?.timer) {
                        Persistent.states.timer.pinnedToBar = !toggled
                    }
                }

                StyledToolTip {
                    text: Translation.tr("Pin timer to bar\nKeeps the timer indicator visible in the bar even when no timer is running")
                }
            }
        }

        StackLayout {
            Layout.topMargin: (root.showTabBar || root.showPinButton) ? 6 : 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            currentIndex: root.currentTab

            PomodoroTimer {
                compactMode: root.compactMode
                centerMode: root.centerMode
            }
            CountdownTimer {
                compactMode: root.compactMode
                centerMode: root.centerMode
            }
            Stopwatch {
                compactMode: root.compactMode
                centerMode: root.centerMode
            }
        }
    }
}
