import qs
import qs.services
import qs.modules.common
import qs.modules.common.perimeter
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell

Item {
    id: root

    property var perimeterContext: null
    property var instanceConfig: ({})

    readonly property bool presented: PerimeterPresentationPolicy.barPresented
    readonly property bool vertical:
        (root.perimeterContext?.orientation ?? "horizontal") === "vertical"
    readonly property string outputName: root.perimeterContext?.outputName ?? ""
    readonly property string instanceId: root.perimeterContext?.instanceId ?? ""
    readonly property string slotId: root.perimeterContext?.slotId ?? ""
    readonly property string statusText: {
        if (ThinkFanService.busy)
            return "…"
        if (!ThinkFanService.stateKnown || !ThinkFanService.available)
            return "—"
        if (ThinkFanService.fanRpm >= 0)
            return String(ThinkFanService.fanRpm)
        return ThinkFanService.active ? "ON" : "FW"
    }

    implicitWidth: root.presented ? (statusLoader.item?.implicitWidth ?? 0) : 0
    implicitHeight: root.presented ? (statusLoader.item?.implicitHeight ?? 0) : 0
    visible: root.presented
    enabled: root.presented
    activeFocusOnTab: root.presented

    Accessible.role: Accessible.Button
    Accessible.name: Translation.tr("ThinkFan")
    Accessible.focusable: true

    Keys.onPressed: event => {
        if (event.isAutoRepeat
                || (event.key !== Qt.Key_Return
                    && event.key !== Qt.Key_Enter
                    && event.key !== Qt.Key_Space))
            return
        root.requestExpanded()
        event.accepted = true
    }

    function requestExpanded(): void {
        if (!root.presented || !(root.perimeterContext?.valid ?? false))
            return
        if (!anchorPublisher.publish())
            return
        SurfaceRouteController.toggle({
            output: root.outputName,
            family: "perimeter",
            surface: "thinkfan",
            sourceInstance: root.instanceId,
            slot: root.slotId
        })
    }

    AnchorPublisher {
        id: anchorPublisher
        sourceItem: root
        outputName: root.outputName
        slotId: root.slotId
        instanceId: root.instanceId
        moduleId: "thinkfan"
        surfaceName: "thinkfan"
        preferredExtent: Qt.size(344, 300)
    }

    Loader {
        id: statusLoader
        anchors.centerIn: parent
        sourceComponent: root.vertical ? verticalStatus : horizontalStatus
    }

    KeyboardFocusRing {
        anchors.fill: parent
        focusVisible: root.activeFocus
    }

    Component {
        id: horizontalStatus

        RowLayout {
            spacing: 3

            MaterialSymbol {
                Layout.alignment: Qt.AlignVCenter
                text: "mode_fan"
                fill: ThinkFanService.active ? 1 : 0
                iconSize: Appearance.font.pixelSize.normal
                color: ThinkFanService.active
                    ? Appearance.colors.colPrimary
                    : Appearance.colors.colOnSurfaceVariant
            }

            StyledText {
                Layout.alignment: Qt.AlignVCenter
                text: root.statusText
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnLayer1
            }
        }
    }

    Component {
        id: verticalStatus

        ColumnLayout {
            spacing: 1

            MaterialSymbol {
                Layout.alignment: Qt.AlignHCenter
                text: "mode_fan"
                fill: ThinkFanService.active ? 1 : 0
                iconSize: Appearance.font.pixelSize.normal
                color: ThinkFanService.active
                    ? Appearance.colors.colPrimary
                    : Appearance.colors.colOnSurfaceVariant
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: root.statusText
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnLayer1
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (!root.presented)
                return
            if (mouse.button === Qt.RightButton) {
                ThinkFanService.refresh()
                return
            }
            root.requestExpanded()
        }
    }

    ThinkFanConnectedSurface {
        perimeterContext: root.perimeterContext
        sourceScreen: root.QsWindow.window?.screen ?? null
    }
}
