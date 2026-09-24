pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs
import qs.modules.bar as Bar
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.notificationCenter
import qs.services

Bar.StyledPopup {
    id: root

    required property Item anchorItem
    required property string outputName
    property bool hoverAllowed: true
    property bool entryBridgeHeld: false
    property bool exitGraceHeld: false
    property bool keyboardInteraction: false
    property bool hoverSessionArmed: true
    property int selectedTab: 0
    property int _screenTimeRevision: 0
    property string cornerAttachmentEdge: "bottom"
    property real cornerAttachmentThickness: Math.max(1, Math.min(32,
        Math.round(Config.options?.appearance?.screenEdge?.width ?? 10)))

    readonly property bool explicitForThisOutput:
        GlobalStates.notificationCenterExplicitOpen
        && GlobalStates.notificationCenterPresentationOutput === root.outputName
    readonly property real requestedPopupWidth: Math.max(320, Math.min(760,
        Config.options?.notificationCenter?.popupWidth ?? 420))
    readonly property real requestedPopupHeight: root.selectedTab === 0
        ? Math.max(260, Math.min(900,
            Config.options?.notificationCenter?.popupHeight ?? 560))
        : 310
    readonly property var todayUsage: {
        const revision = root._screenTimeRevision
        return ScreenTime.getToday()
    }
    readonly property var todayApps: {
        const revision = root._screenTimeRevision
        return ScreenTime.getAppList(1)
    }
    readonly property var visibleApps: root.todayApps.slice(0, 6)
    readonly property int hiddenAppCount:
        Math.max(0, root.todayApps.length - root.visibleApps.length)
    readonly property real maxAppSeconds: {
        let maximum = 1
        const apps = root.todayApps
        for (let i = 0; i < apps.length; ++i)
            maximum = Math.max(maximum, Number(apps[i]?.seconds ?? 0))
        return maximum
    }
    readonly property bool _anchorHovered: root.anchorItem
        && (root.anchorItem.containsMouse ?? false)
    readonly property bool hoverLeaseRequested:
        root.hoverAllowed
        && !root.explicitForThisOutput
        && root.active
        && (root._anchorHovered
            || root.popupHovered
            || root.entryBridgeHeld
            || (contentLoader.item?.dragActive ?? false))

    hoverTarget: root.anchorItem
    barAutoHideHoldEnabled: false
    // ScreenCorners owns this anchor in a tiny bottom-right layer surface.
    // Its local x/y are therefore near zero; pin the popup to the trailing
    // tangent edge of the full output instead of interpreting those locals as
    // output coordinates (which incorrectly placed the body bottom-left).
    tangentEdgeOverride: "end"
    attachmentEdgeOverride: root.cornerAttachmentEdge
    attachmentThicknessOverride: root.cornerAttachmentThickness
    hoverActivates: root.hoverAllowed && root.hoverSessionArmed
    alternativeVisibleCondition: root.explicitForThisOutput
        || root.entryBridgeHeld
        || root.exitGraceHeld
        || root.keyboardInteraction
        || (contentLoader.item?.dragActive ?? false)
    keyboardFocus: root.keyboardInteraction
    closeOnOutsideClick: root.explicitForThisOutput || root.keyboardInteraction
    popupBackgroundMargin: 0

    function enterKeyboardMode(): void {
        if (!root.active)
            return
        if (!GlobalStates.openNotificationCenter(root.outputName))
            return
        root.keyboardInteraction = true
        Qt.callLater(() => {
            if (contentLoader.item)
                contentLoader.item.focusSearch()
        })
    }

    onSelectedTabChanged: {
        if (root.selectedTab === 1 && root.keyboardInteraction)
            root.keyboardInteraction = false
    }

    Connections {
        target: ScreenTime

        function onDataChanged(): void {
            root._screenTimeRevision++
        }

        function onReadyChanged(): void {
            root._screenTimeRevision++
        }

        function onEnabledChanged(): void {
            root._screenTimeRevision++
        }
    }

    function isCurrentApp(app): bool {
        const current = String(ScreenTime.currentAppId ?? "").toLowerCase()
        const original = String(app?.originalId ?? "").toLowerCase()
        const id = String(app?.id ?? "").toLowerCase()
        return current.length > 0
            && (current === original || current === id)
    }

    function dismissAndDisarm(): void {
        entryBridgeTimer.stop()
        exitGraceTimer.stop()
        root.entryBridgeHeld = false
        root.exitGraceHeld = false
        root.keyboardInteraction = false
        root.hoverSessionArmed = false
        if (contentLoader.item)
            contentLoader.item.clearSearchFocus()
        GlobalStates.setNotificationCenterHoverOutput(root.outputName, false)
        GlobalStates.closeNotificationCenter()
    }

    function rearmHoverIfIdle(): void {
        if (!root.active && !root._anchorHovered)
            root.hoverSessionArmed = true
    }

    onRequestClose: root.dismissAndDisarm()

    onHoverAllowedChanged: {
        if (!hoverAllowed && !explicitForThisOutput) {
            entryBridgeTimer.stop()
            entryBridgeHeld = false
        }
    }

    onHoverLeaseRequestedChanged: {
        if (root.hoverLeaseRequested) {
            exitGraceTimer.stop()
            root.exitGraceHeld = false
            GlobalStates.setNotificationCenterHoverOutput(root.outputName, true)
            return
        }

        if (root.active && !root.explicitForThisOutput) {
            root.exitGraceHeld = true
            exitGraceTimer.restart()
            return
        }

        GlobalStates.setNotificationCenterHoverOutput(root.outputName, false)
    }

    onActiveChanged: {
        if (active) {
            if (!root.explicitForThisOutput) {
                root.entryBridgeHeld = true
                entryBridgeTimer.restart()
            }
            return
        }

        entryBridgeTimer.stop()
        exitGraceTimer.stop()
        root.entryBridgeHeld = false
        root.exitGraceHeld = false
        root.keyboardInteraction = false
        if (contentLoader.item)
            contentLoader.item.clearSearchFocus()
        GlobalStates.setNotificationCenterHoverOutput(root.outputName, false)
        if (!root._anchorHovered)
            root.hoverSessionArmed = true
    }

    Component.onDestruction:
        GlobalStates.setNotificationCenterHoverOutput(root.outputName, false)

    property QtObject _entryBridgeTimer: Timer {
        id: entryBridgeTimer
        // Use the public transfer-grace setting for both directions. A separate
        // hard-coded entry delay made Settings only partially authoritative.
        interval: Math.max(0,
            Config.options?.notificationCenter?.closeGraceMs ?? 280)
        repeat: false
        onTriggered: root.entryBridgeHeld = false
    }

    property QtObject _exitGraceTimer: Timer {
        id: exitGraceTimer
        interval: Math.max(0,
            Config.options?.notificationCenter?.closeGraceMs ?? 280)
        repeat: false
        onTriggered: {
            if (root.hoverLeaseRequested)
                return
            root.exitGraceHeld = false
            GlobalStates.setNotificationCenterHoverOutput(root.outputName, false)
        }
    }

    Item {
        id: contentRoot

        Shortcut {
            sequences: [StandardKey.Cancel]
            context: Qt.WindowShortcut
            enabled: root.active
                && (root.explicitForThisOutput || root.keyboardInteraction)
            onActivated: root.dismissAndDisarm()
        }

        implicitWidth: Math.max(1,
            root.requestedPopupWidth - root._contentPadding * 2)
        implicitHeight: Math.max(1,
            root.requestedPopupHeight - root._contentPadding * 2)
        width: parent ? parent.width : implicitWidth
        height: parent ? parent.height : implicitHeight

        ColumnLayout {
            anchors.fill: parent
            spacing: 10

            PillTabBar {
                Layout.fillWidth: true
                currentIndex: root.selectedTab
                pillHeight: 36
                tabs: [
                    {
                        icon: "notifications",
                        label: Translation.tr("Notifications"),
                        count: Notifications.list.length
                    },
                    {
                        icon: "monitoring",
                        label: Translation.tr("Activity")
                    }
                ]
                onTabSelected: index => root.selectedTab = index
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Loader {
                    id: contentLoader
                    anchors.fill: parent
                    active: root.active && root.selectedTab === 0
                    sourceComponent: NotificationCenterContent {
                        popupPresentation: true
                        onSearchFocusRequested: root.enterKeyboardMode()
                        onExternalNavigationRequested: root.dismissAndDisarm()
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    visible: root.selectedTab === 1
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 48
                        spacing: 8

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: height / 2
                            color: Appearance.colors.colLayer2

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 7

                                MaterialSymbol {
                                    text: "avg_pace"
                                    iconSize: 17
                                    color: Appearance.colors.colPrimary
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: -1

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: Translation.tr("System uptime")
                                        font.pixelSize:
                                            Appearance.font.pixelSize.smallest
                                        color: Appearance.colors.colSubtext
                                        elide: Text.ElideRight
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: DateTime.uptime || "--"
                                        font.pixelSize:
                                            Appearance.font.pixelSize.small
                                        font.weight: Font.DemiBold
                                        font.family:
                                            Appearance.font.family.numbers
                                        color: Appearance.colors.colOnLayer2
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: height / 2
                            color: Appearance.colors.colLayer2

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                spacing: 7

                                MaterialSymbol {
                                    text: "schedule"
                                    iconSize: 17
                                    color: Appearance.colors.colPrimary
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: -1

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: Translation.tr("Today")
                                        font.pixelSize:
                                            Appearance.font.pixelSize.smallest
                                        color: Appearance.colors.colSubtext
                                        elide: Text.ElideRight
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: ScreenTime.formatDuration(
                                            Number(root.todayUsage?.totalSeconds ?? 0))
                                        font.pixelSize:
                                            Appearance.font.pixelSize.small
                                        font.weight: Font.DemiBold
                                        font.family:
                                            Appearance.font.family.numbers
                                        color: Appearance.colors.colOnLayer2
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 18
                        spacing: 6

                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("App usage")
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            font.weight: Font.Medium
                            color: Appearance.colors.colSubtext
                            elide: Text.ElideRight
                        }

                        StyledText {
                            visible: root.hiddenAppCount > 0
                            text: "+" + root.hiddenAppCount
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            color: Appearance.colors.colSubtext
                        }
                    }

                    GridLayout {
                        visible: root.visibleApps.length > 0
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        columns: 2
                        uniformCellWidths: true
                        columnSpacing: 6
                        rowSpacing: 6

                        Repeater {
                            model: root.visibleApps

                            delegate: Rectangle {
                                id: usageCell
                                required property var modelData

                                Layout.fillWidth: true
                                Layout.preferredHeight: 34
                                radius: height / 2
                                clip: true

                                readonly property bool active:
                                    root.isCurrentApp(modelData)
                                color: active
                                    ? Appearance.colors.colPrimaryContainer
                                    : Appearance.colors.colLayer2

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.bottom: parent.bottom
                                    height: 2
                                    width: parent.width * Math.max(0, Math.min(1,
                                        Number(usageCell.modelData?.seconds ?? 0)
                                            / root.maxAppSeconds))
                                    color: usageCell.active
                                        ? Appearance.colors.colPrimary
                                        : Appearance.colors.colPrimary
                                    opacity: usageCell.active ? 0.72 : 0.26
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    spacing: 6

                                    SmartAppIcon {
                                        Layout.preferredWidth: 19
                                        Layout.preferredHeight: 19
                                        iconSize: 19
                                        icon: AppSearch.guessIcon(
                                            String(usageCell.modelData?.name ?? "")
                                                .toLowerCase()
                                            || String(
                                                usageCell.modelData?.originalId
                                                    ?? usageCell.modelData?.id
                                                    ?? ""))
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        Layout.minimumWidth: 0
                                        text: usageCell.modelData?.name
                                            || usageCell.modelData?.id || ""
                                        font.pixelSize:
                                            Appearance.font.pixelSize.smallest
                                        font.weight: usageCell.active
                                            ? Font.DemiBold : Font.Medium
                                        color: usageCell.active
                                            ? Appearance.colors
                                                .colOnPrimaryContainer
                                            : Appearance.colors.colOnLayer2
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                    }

                                    StyledText {
                                        text: ScreenTime.formatDuration(
                                            Number(usageCell.modelData?.seconds ?? 0))
                                        font.pixelSize:
                                            Appearance.font.pixelSize.smallest
                                        font.weight: Font.DemiBold
                                        font.family:
                                            Appearance.font.family.numbers
                                        color: usageCell.active
                                            ? Appearance.colors
                                                .colOnPrimaryContainer
                                            : Appearance.colors.colSubtext
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        visible: root.visibleApps.length === 0
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        RowLayout {
                            anchors.centerIn: parent
                            width: Math.min(parent.width - 16, 250)
                            spacing: 8

                            MaterialSymbol {
                                text: "monitoring"
                                iconSize: 20
                                color: Appearance.colors.colSubtext
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: ScreenTime.enabled
                                    ? Translation.tr("No activity recorded yet")
                                    : Translation.tr("Activity tracking is starting…")
                                font.pixelSize:
                                    Appearance.font.pixelSize.smallest
                                color: Appearance.colors.colSubtext
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }
            }
        }
    }
}
