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
        : 280
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
        if (root.selectedTab === 1 && root.keyboardInteraction) {
            root.keyboardInteraction = false
            GlobalStates.closeNotificationCenter()
        }
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

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                    model: [
                        { icon: "notifications", label: Translation.tr("Notifications") },
                        { icon: "avg_pace", label: Translation.tr("Uptime") }
                    ]
                    delegate: Button {
                        id: tabButton
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        implicitHeight: 38
                        Accessible.name: modelData.label
                        onClicked: root.selectedTab = index
                        background: Rectangle {
                            radius: Appearance.rounding.normal
                            color: root.selectedTab === tabButton.index
                                ? Appearance.colors.colPrimaryContainer
                                : Appearance.colors.colLayer1
                        }
                        contentItem: RowLayout {
                            spacing: 6
                            MaterialSymbol {
                                text: tabButton.modelData.icon
                                iconSize: 18
                                color: Appearance.colors.colOnLayer1
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: tabButton.modelData.label
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                color: Appearance.colors.colOnLayer1
                                font.weight: root.selectedTab === tabButton.index
                                    ? Font.DemiBold : Font.Normal
                            }
                        }
                    }
                }
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
                    anchors.centerIn: parent
                    width: parent.width
                    visible: root.selectedTab === 1
                    spacing: 12

                    MaterialSymbol {
                        Layout.alignment: Qt.AlignHCenter
                        text: "avg_pace"
                        iconSize: 40
                        color: Appearance.colors.colPrimary
                    }
                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: Translation.tr("System uptime")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colSubtext
                    }
                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: DateTime.uptime || "--"
                        font.pixelSize: Appearance.font.pixelSize.huge
                        font.weight: Font.DemiBold
                        font.family: Appearance.font.family.numbers
                        color: Appearance.colors.colOnLayer1
                    }
                }
            }
        }
    }
}
