import qs
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.perimeter
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris

MouseArea {
    id: root

    property var perimeterContext: null
    property var instanceConfig: ({})

    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    readonly property bool vertical:
        (root.perimeterContext?.orientation ?? "horizontal") === "vertical"
    readonly property string outputName: root.perimeterContext?.outputName ?? ""
    readonly property string instanceId: root.perimeterContext?.instanceId ?? ""
    readonly property string slotId: root.perimeterContext?.slotId ?? ""
    readonly property string cleanedTitle:
        StringUtils.cleanMusicTitle(root.activePlayer?.trackTitle) || Translation.tr("No media")

    implicitWidth: root.vertical
        ? Appearance.sizes.barHeight
        : Math.min(220 * Appearance.fontSizeScale,
            mediaRow.implicitWidth + 12)
    implicitHeight: root.vertical
        ? Appearance.sizes.barHeight
        : Appearance.sizes.barHeight
    clip: true

    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton

    function requestExpanded(): void {
        if (!(root.perimeterContext?.valid ?? false))
            return
        anchorPublisher.publish()
        const anchor = AnchorRegistry.lookup(root.outputName, root.instanceId, "media")
        if (!anchor)
            return
        SurfaceRouteController.toggle({
            output: root.outputName,
            family: "perimeter",
            surface: "media",
            sourceInstance: root.instanceId,
            slot: root.slotId,
            anchorRect: anchor.rect
        })
    }

    onClicked: root.requestExpanded()

    AnchorPublisher {
        id: anchorPublisher
        sourceItem: root
        outputName: root.outputName
        slotId: root.slotId
        instanceId: root.instanceId
        moduleId: "media"
        surfaceName: "media"
        preferredExtent: Qt.size(420, 420)
    }

    RowLayout {
        id: mediaRow
        anchors.centerIn: parent
        spacing: 5

        MaterialSymbol {
            text: root.activePlayer?.isPlaying ? "graphic_eq" : "music_note"
            iconSize: Appearance.font.pixelSize.large
            color: Appearance.inirEverywhere
                ? Appearance.inir.colText : Appearance.colors.colOnLayer1
            Layout.alignment: Qt.AlignVCenter
        }

        StyledText {
            visible: !root.vertical
            text: root.cleanedTitle
            elide: Text.ElideRight
            maximumLineCount: 1
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.inirEverywhere
                ? Appearance.inir.colText : Appearance.colors.colOnLayer1
            Layout.maximumWidth: 180 * Appearance.fontSizeScale
            Layout.alignment: Qt.AlignVCenter
        }
    }

    MediaConnectedSurface {
        perimeterContext: root.perimeterContext
        sourceScreen: root.QsWindow.window?.screen ?? null
    }
}
