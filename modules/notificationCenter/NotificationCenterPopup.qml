pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import qs
import qs.modules.bar as Bar
import qs.modules.common
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
    property string cornerAttachmentEdge: "bottom"
    property real cornerAttachmentThickness: Math.max(1, Math.min(32,
        Math.round(Config.options?.appearance?.screenEdge?.width ?? 10)))

    readonly property bool explicitForThisOutput:
        GlobalStates.notificationCenterExplicitOpen
        && GlobalStates.notificationCenterPresentationOutput === root.outputName
    readonly property real requestedPopupWidth: Math.max(320, Math.min(760,
        Config.options?.notificationCenter?.popupWidth ?? 420))
    readonly property real requestedPopupHeight: Math.max(260, Math.min(900,
        Config.options?.notificationCenter?.popupHeight ?? 560))
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

        Loader {
            id: contentLoader
            anchors.fill: parent
            active: root.active
            sourceComponent: NotificationCenterContent {
                popupPresentation: true
                onSearchFocusRequested: root.enterKeyboardMode()
                onExternalNavigationRequested: root.dismissAndDisarm()
            }
        }
    }
}
