pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.bar
import qs.modules.bar.weather
import qs.modules.mediaControls
import qs.modules.abyss.looks

// Rehost the mature popup contents, including Events, ThinkFan and Equalizer.
FocusScope {
    id: root
    property string kind: "media"
    property string outputName: ""
    property var participant: null
    // Wi-Fi, Bluetooth and Utilities share one hover/focus lease. This keeps
    // icon→popup hand-off timing consistent and avoids a second dismissal timer.
    property bool autoDismissOnIdle: true
    property int idleDismissDelay: 650
    readonly property bool hoverDismissEnabled: root.autoDismissOnIdle
        && ["wifi","bluetooth","utilities","launcher","dockAppMenu"].includes(root.kind)
    readonly property bool triggerHovered: root.participant?.triggerHovered ?? false
    signal closeRequested()

    function refreshIdleDismiss(): void {
        if (!root.hoverDismissEnabled || !root.enabled) {
            idleDismiss.stop()
            return
        }
        if (root.triggerHovered || popupHover.hovered || root.activeFocus)
            idleDismiss.stop()
        else
            idleDismiss.restart()
    }

    Component.onCompleted: Qt.callLater(root.refreshIdleDismiss)
    onKindChanged: root.refreshIdleDismiss()
    onEnabledChanged: root.refreshIdleDismiss()
    onTriggerHoveredChanged: root.refreshIdleDismiss()
    onActiveFocusChanged: root.refreshIdleDismiss()

    HoverHandler {
        id: popupHover
        enabled: root.hoverDismissEnabled
        onHoveredChanged: root.refreshIdleDismiss()
    }

    Timer {
        id: idleDismiss
        interval: root.idleDismissDelay
        repeat: false
        onTriggered: {
            if (root.hoverDismissEnabled && root.enabled
                    && !root.triggerHovered && !popupHover.hovered && !root.activeFocus)
                root.closeRequested()
        }
    }
    readonly property var feature: content.item
    readonly property var featureContent: feature?.contentItem ?? feature
    readonly property real desiredWidth: featureContent?.implicitWidth || 390
    readonly property real desiredHeight: featureContent?.implicitHeight || 300
    readonly property bool keyboardFocus: kind === "clock" && (feature?.keyboardFocus ?? false)
    Loader {
        id: content
        anchors.fill: parent
        sourceComponent: root.kind === "clock" ? calendar : root.kind === "battery" ? battery
            : root.kind === "resources" ? resources : root.kind === "weather" ? weather
            : root.kind === "utilities" ? utilities
            : root.kind === "launcher" ? launcher
            : root.kind === "dockAppMenu" ? dockAppMenu
            : ["wifi","bluetooth"].includes(root.kind) ? network
            : root.kind === "audio" ? audio : media
    }
    Component { id: calendar; ClockCalendarPopup { embeddedHost: root } }
    Component { id: battery; BatteryPopup { embeddedHost: root } }
    Component { id: resources; ResourcesPopup { embeddedHost: root } }
    Component { id: weather; WeatherPopupContent { compact: (root.participant?.width ?? 1920)<compactBreakpoint } }
    Component { id: media; BarMediaPopup { onCloseRequested: root.closeRequested() } }
    Component { id: utilities; AbyssUtilitiesPopup { outputName: root.outputName; onCloseRequested: root.closeRequested() } }
    Component { id: launcher; AbyssLauncherControlsPopup {} }
    Component { id: dockAppMenu; AbyssDockAppMenuPopup {} }
    Component {
        id: network
        AbyssNetworkPopup {
            kind: root.kind
            // AbyssPopupContent owns the shared Wi-Fi/Bluetooth/Utilities lease.
            autoDismissOnIdle: false
            triggerHovered: root.triggerHovered
            onCloseRequested: root.closeRequested()
        }
    }
    Component {
        id: audio
        ColumnLayout {
            implicitWidth: 350
            AbyssLabel { text: "Volume" }
            AbyssSlider { Layout.fillWidth: true;value:Audio.value;onMoved:Audio.setSinkVolume(value) }
            AbyssButton { text:"Mute";onClicked:Audio.toggleMute() }
        }
    }
}
