// Synthetic-owned, exact-production AbyssField.frag.qsb + AbyssCompanion.
// No host screen, wallpaper, live Bar modules, pointer, or backend mutation.
// Four representative fixed inset cases qualify shader feasibility only.
import QtQuick
import Quickshell
import qs.modules.abyss.looks
import qs.modules.abyss.companion

ShellRoot {
    id: root
    property bool finished: false
    property bool captureAttempted: false
    readonly property var cells: [top, right, bottom, left]
    function fail(code): void {
        if (finished) return
        finished = true
        console.log("WULL_FIELD_CANARY_FAILURE=" + code)
        Qt.quit()
    }
    function capture(): void {
        if (finished || captureAttempted) return
        captureAttempted = true
        if (!privateWindow.backingWindowVisible) {
            fail("WINDOW_NOT_BACKING"); return
        }
        if (Math.abs(sheet.width - 512) > .1 ||
                Math.abs(sheet.height - 512) > .1) {
            fail("SHEET_DIMENSIONS_INVALID"); return
        }
        if (cells.length !== 4 || cells.some(cell => !cell)) {
            fail("FOUR_CELLS_UNAVAILABLE"); return
        }
        for (const cell of cells) {
            if (!cell.shaderReady) {
                fail("REAL_SHADER_NOT_READY"); return
            }
            if (!cell.host.valid || cell.host.edge !== cell.edgeName ||
                    cell.host.reveal !== 1 || cell.host.scale !== 1) {
                fail("PRODUCTION_HOST_INVALID"); return
            }
            const bodies = cell.host.children.filter(item =>
                item.width === 76 && item.height === 92)
            if (bodies.length !== 1) {
                fail("PRODUCTION_BODY_UNVERIFIED"); return
            }
            const body = bodies[0]
            body.motionEnabled = false
            body.bob = 0
            body.sway = 0
            body.shimmer = 0
            body.squash = 0
            if (!body.visible) {
                fail("PRODUCTION_BODY_HIDDEN"); return
            }
        }
        console.log("WULL_FIELD_CANARY_STAGE=REAL_FIELD_FOUR_HOSTS_READY")
        const file = Quickshell.env("WULL_FIELD_CANARY_PRIVATE_PNG")
        if (!file || file.length < 10) {
            fail("PRIVATE_OUTPUT_MISSING"); return
        }
        Qt.callLater(() => {
            const ok = sheet.grabToImage(function(result) {
                if (finished) return
                if (!result || !result.saveToFile(file)) {
                    fail("PRIVATE_GRAB_OR_SAVE_FAILED"); return
                }
                finished = true
                console.log("WULL_FIELD_CANARY_STAGE=PNG_SAVED")
                Qt.quit()
            }, Qt.size(512, 512))
            if (!ok) fail("PRIVATE_GRAB_UNAVAILABLE")
        })
    }
    component FieldCase: Item {
        id: cell
        required property string edgeName
        width: 224; height: 224
        readonly property int innerDepth: 66
        readonly property var syntheticInsets: ({
            left: edgeName === "left" ? innerDepth : 14,
            right: edgeName === "right" ? innerDepth : 14,
            top: edgeName === "top" ? innerDepth : 14,
            bottom: edgeName === "bottom" ? innerDepth : 14
        })
        readonly property bool shaderReady: realField.ready
        property alias host: actualCompanion
        AbyssField {
            id: realField
            anchors.fill: parent
            outputName: ""
            renderScale: 1
            edgeInsets: cell.syntheticInsets
            records: []
            waveTexture: null
        }
        AbyssCompanion {
            id: actualCompanion
            edge: cell.edgeName
            scale: 1
            reveal: 1
            interactive: false
            energy: 0
            eyeOpen: 1
            pulse: cell.edgeName === "bottom" ? .7 : 0
            mouthCurve: cell.edgeName === "bottom" ? .8 : .12
            x: (edge === "top" || edge === "bottom")
                ? (cell.width - implicitWidth) / 2
                : edge === "left" ? cell.innerDepth - 5
                : cell.width - cell.innerDepth - implicitWidth + 5
            y: (edge === "left" || edge === "right")
                ? (cell.height - implicitHeight) / 2
                : edge === "top" ? cell.innerDepth - 5
                : cell.height - cell.innerDepth - implicitHeight + 5
            readonly property bool valid:
                Number.isFinite(x) && Number.isFinite(y)
                && (edge === "top" || edge === "bottom"
                    ? Math.abs(x - (cell.width - implicitWidth) / 2) < .1
                    : true)
                && x >= 0 && y >= 0
                && x + implicitWidth <= cell.width + .1
                && y + implicitHeight <= cell.height + .1
        }
    }
    FloatingWindow {
        id: privateWindow
        // Match the existing real-shader lifecycle fixture: create backing
        // immediately; a delayed hidden first frame is not a valid probe.
        visible: true
        color: "transparent"
        implicitWidth: 512
        implicitHeight: 512
        title: "Private synthetic real AbyssField shader canary"
        Item {
            id: sheet
            anchors.fill: parent
            FieldCase { id: top; x: 8; y: 8; edgeName: "top" }
            FieldCase { id: right; x: 280; y: 8; edgeName: "right" }
            FieldCase { id: bottom; x: 8; y: 280; edgeName: "bottom" }
            FieldCase { id: left; x: 280; y: 280; edgeName: "left" }
        }
    }
    Component.onCompleted: console.log("WULL_FIELD_CANARY_STAGE=BOOT")
    Timer {
        interval: 2750; running: true; repeat: false
        onTriggered: root.capture()
    }
    Timer {
        interval: 10500; running: true; repeat: false
        onTriggered: root.fail("PRIVATE_FIELD_TIMEOUT")
    }
}
