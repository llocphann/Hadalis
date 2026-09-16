import qs.modules.common
import qs.modules.common.perimeter
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell

MouseArea {
    id: root

    property var perimeterContext: null
    property var instanceConfig: ({})

    readonly property bool vertical:
        (root.perimeterContext?.orientation ?? "horizontal") === "vertical"
    readonly property string outputName: root.perimeterContext?.outputName ?? ""
    readonly property bool presented:
        PerimeterPresentationPolicy.barPresentedForOutput(root.outputName)
    readonly property string instanceId: root.perimeterContext?.instanceId ?? ""
    readonly property string slotId: root.perimeterContext?.slotId ?? ""

    implicitWidth: !root.presented ? 0 : root.vertical
        ? Math.max(content.implicitWidth, Appearance.sizes.barHeight)
        : content.implicitWidth + 12
    implicitHeight: !root.presented ? 0 : root.vertical
        ? content.implicitHeight + 12
        : Appearance.sizes.barHeight
    visible: root.presented
    enabled: root.presented

    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    activeFocusOnTab: root.presented

    Accessible.role: Accessible.Button
    Accessible.name: Translation.tr("Weather")
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
        anchorPublisher.publish()
        const anchor = AnchorRegistry.lookup(root.outputName, root.instanceId, "weather")
        if (!anchor)
            return
        SurfaceRouteController.toggle({
            output: root.outputName,
            family: "perimeter",
            surface: "weather",
            sourceInstance: root.instanceId,
            slot: root.slotId,
            anchorRect: anchor.rect
        })
    }

    onClicked: mouse => {
        if (!root.presented)
            return
        if (mouse.button === Qt.RightButton) {
            Weather.forceRefresh()
            return
        }
        root.requestExpanded()
    }

    AnchorPublisher {
        id: anchorPublisher
        sourceItem: root
        outputName: root.outputName
        slotId: root.slotId
        instanceId: root.instanceId
        moduleId: "weather"
        surfaceName: "weather"
        preferredExtent: Qt.size(360, 520)
    }

    KeyboardFocusRing {
        anchors.fill: parent
        focusVisible: root.activeFocus
    }

    RowLayout {
        id: content
        anchors.centerIn: parent
        spacing: 4

        MaterialSymbol {
            text: Icons.getWeatherIcon(Weather.data?.wCode, Weather.isNightNow()) ?? "cloud"
            iconSize: Appearance.font.pixelSize.large
            color: Appearance.inirEverywhere
                ? Appearance.inir.colText : Appearance.colors.colOnLayer1
            Layout.alignment: Qt.AlignVCenter
        }

        StyledText {
            visible: !root.vertical
            text: Weather.data?.temp ?? "--°"
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.inirEverywhere
                ? Appearance.inir.colText : Appearance.colors.colOnLayer1
            Layout.alignment: Qt.AlignVCenter
        }
    }

    WeatherConnectedSurface {
        perimeterContext: root.perimeterContext
        sourceScreen: root.QsWindow.window?.screen ?? null
    }
}
