import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs.services.deferred
import qs.modules.common.functions
import Qt5Compat.GraphicalEffects
import QtQuick
import Quickshell
import Quickshell.Io

Rectangle {
    id: root
    property string entry
    property real maxWidth
    property real maxHeight
    property bool blur: false
    property string blurText: "Image hidden"

    property string imageDecodePath: Directories.cliphistDecode
    property string imageDecodeFileName: Cliphist.entryId(root.entry)
    property string imageDecodeFilePath: `${imageDecodePath}/${imageDecodeFileName}`
    property string source

    property int entryNumber: {
        if (!root.entry)
            return 0;
        const match = root.entry.match(/^\s*(\d+)(?:\t|\s+)/);
        return match ? parseInt(match[1]) : 0;
    }
    readonly property var dimensions: String(root.entry).match(/(\d+)\s*[x×]\s*(\d+)/)
    readonly property real imageWidth: image.implicitWidth > 0 ? image.implicitWidth
        : dimensions ? Number(dimensions[1]) : Math.max(1,root.maxWidth)
    readonly property real imageHeight: image.implicitHeight > 0 ? image.implicitHeight
        : dimensions ? Number(dimensions[2]) : Math.max(1,root.maxHeight)
    readonly property real previewScale: Math.max(0,Math.min(
        Math.max(1,root.maxWidth)/Math.max(1,imageWidth),
        Math.max(1,root.maxHeight)/Math.max(1,imageHeight),1))

    color: Appearance.colors.colLayer1
    radius: Appearance.rounding.small
    implicitHeight: imageHeight * previewScale
    implicitWidth: imageWidth * previewScale

    // Lazy decode: only start when visible (avoids mass-spawning processes)
    property bool _decoded: false
    property string _decodingEntry: ""
    property string _decodingPath: ""
    property var _decodeCommand: []
    function startDecode(): void {
        if (!visible || _decoded || !imageDecodeFileName || decodeImageProcess.running) return
        _decodingEntry=entry;_decodingPath=imageDecodeFilePath;_decoded=true
        const quote=value=>"'"+StringUtils.shellSingleQuoteEscape(String(value))+"'"
        // Metadata may omit dimensions; decode independently of preview size.
        // mkdir and private temporary publication also cover a cold startup.
        _decodeCommand=["/usr/bin/bash","-c",
            "set -o pipefail; mkdir -p "+quote(imageDecodePath)+" || exit 1; "
            +"if [ -s "+quote(_decodingPath)+" ]; then exit 0; fi; "
            +"_tmp=$(mktemp "+quote(imageDecodePath+"/.decode.XXXXXX")+") || exit 1; "
            +"trap 'rm -f -- \"$_tmp\"' EXIT; "
            +"if "+Cliphist.decodeCommand(_decodingEntry)+" > \"$_tmp\" && [ -s \"$_tmp\" ]; then "
            +"mv -f -- \"$_tmp\" "+quote(_decodingPath)+"; else exit 1; fi"]
        decodeImageProcess.running=true
    }
    onVisibleChanged: if (visible) root.startDecode()
    onEntryChanged: {
        root._decoded=false;root.source=""
        if (decodeImageProcess.running) decodeImageProcess.signal(15)
        else Qt.callLater(root.startDecode)
    }
    Component.onCompleted: root.startDecode()

    Process {
        id: decodeImageProcess
        // Multiple clipboard surfaces can render the same entry concurrently.
        // Decode through a per-process temporary file and publish it atomically;
        // the shared session cache is cleaned once by Directories on shell start.
        command: root._decodeCommand
        onExited: (exitCode, exitStatus) => {
            if (root.entry!==root._decodingEntry) {Qt.callLater(root.startDecode);return}
            root.source = exitCode === 0 ? root._decodingPath : ""
        }
    }

    layer.enabled: true
    layer.effect: OpacityMask {
        maskSource: Rectangle {
            width: image.width
            height: image.height
            radius: root.radius
        }
    }

    StyledImage {
        id: image
        objectName: "clipboardDecodedImage"
        anchors.fill: parent

        source: Qt.resolvedUrl(root.source)
        fillMode: Image.PreserveAspectFit
        antialiasing: true
        asynchronous: true

        // Read intrinsic size after decode; requesting a zero-sized texture
        // before metadata is known can make the preview permanently empty.
    }

    Loader {
        id: blurLoader
        active: root.blur
        anchors.fill: image
        sourceComponent: GaussianBlur {
            source: image
            radius: 35
            // See #159 — cap samples to bound fragment shader cost
            samples: Math.min(33, radius * 2 + 1)

            Rectangle {
                anchors.fill: parent
                color: ColorUtils.transparentize(Appearance.colors.colLayer0, 0.5)

                Column {
                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                    }
                    MaterialSymbol {
                        visible: width <= image.width
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "visibility_off"
                        font.pixelSize: Appearance.font.pixelSize.huge
                    }
                    StyledText {
                        visible: width <= image.width
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.blurText
                        color: Appearance.colors.colOnSurface
                        font.pixelSize: Appearance.font.pixelSize.smallie
                    }
                }
            }
        }
    }
}
