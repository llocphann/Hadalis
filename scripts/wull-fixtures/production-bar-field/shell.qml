// Private synthetic output with the ACTUAL production AbyssBar module tree,
// production ModuleLayout geometry, current real AbyssField.frag.qsb,
// WullSurfacePlacement and actual AbyssCompanion. NOT full AbyssPerimeter,
// live modules on the host or a native input-mask acceptance test.
import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.abyss.bar
import qs.modules.abyss.looks
import qs.modules.abyss.companion
import "modules/abyss/looks/AbyssLayout.js" as Layout
import "modules/abyss/companion/WullSurfacePlacement.js" as Placement
import "modules/abyss/companion/WullHostPolicy.js" as HostPolicy

ShellRoot {
    id: root
    readonly property string edgeName: Quickshell.env("WULL_PANEL_SIDE") || ""
    property bool finished: false
    property bool attempted: false
    function fail(code): void {
        if (finished) return
        finished = true
        console.log("WULL_PANEL_REAL_FAIL=" + code)
        Qt.quit()
    }
    readonly property var realInsets: Layout.edgeInsetsForModules(
        bar.placements, bar.layoutOptions, Appearance.fontSizeScale,
        AbyssStyle.perimeterThickness, AbyssStyle.barThickness, false)
    readonly property var slot: Placement.slot({
        edge: root.edgeName, extent: sheet.height,
        footprint: companion.implicitHeight + 16,
        desired: HostPolicy.alongPosition(sheet.height,
            companion.implicitHeight, 0.72),
        clearance: 18, sideGuard: 16,
        cornerStart: root.realInsets.top + 32,
        cornerEnd: root.realInsets.bottom + 32,
        maxShift: Math.min(360, sheet.height * .28),
        records: bar.layoutRecords.map(rec => ({
            edge: rec.edge, along: rec.along, span: rec.span
        })), reservations: []
    })
    function localDepth(): real {
        const span = companion.implicitHeight
        const along = root.slot.center - span * .5
        const insets = Layout.clearanceInsets(
            root.realInsets, bar.deformations, root.edgeName, along, span)
        return Math.max(AbyssStyle.perimeterThickness,
            Number(insets[root.edgeName]))
    }
    function capture(): void {
        if (finished || attempted) return
        attempted = true
        if (!(root.edgeName === "left" || root.edgeName === "right")) {
            fail("PANEL_SIDE_INVALID"); return
        }
        if (!window.backingWindowVisible ||
                Math.abs(sheet.width-512)>.1 ||
                Math.abs(sheet.height-512)>.1) {
            fail("PANEL_WINDOW_UNQUALIFIED"); return
        }
        if (!field.ready) {
            fail("PANEL_SHADER_UNQUALIFIED"); return
        }
        // The shipped AbyssBar must instantiate its real clock module and
        // measure it; source-only mock records are not accepted.
        const recs = bar.layoutRecords
        const actual = bar.itemForId("clock")
        if (bar.placements.length !== 1 || recs.length !== 1 ||
                recs[0].kind !== "clock" ||
                recs[0].edge !== root.edgeName ||
                !actual || !Number.isFinite(actual.naturalSpan) ||
                actual.naturalSpan <= 0 ||
                !Array.isArray(bar.deformations) ||
                bar.deformations.length !== 1) {
            fail("PANEL_BAR_MODULE_UNQUALIFIED"); return
        }
        if (!root.slot.qualified ||
                !Number.isFinite(root.slot.center) ||
                root.slot.occupiedOnEdge !== 1) {
            fail("PANEL_SLOT_UNQUALIFIED"); return
        }
        const depth=root.localDepth()
        if (!Number.isFinite(depth) || depth < 16 ||
                !(Math.abs(companion.x -
                    (root.edgeName === "left" ? depth - 5
                        : sheet.width-depth-companion.implicitWidth+5)) < .1) ||
                Math.abs(companion.y -
                    (root.slot.center - companion.implicitHeight*.5)) > .1 ||
                companion.edge !== root.edgeName ||
                !companion.visible) {
            fail("PANEL_WULL_HOST_UNQUALIFIED"); return
        }
        const bodies=companion.children.filter(item =>
            item.width === 76 && item.height === 92)
        if (bodies.length !== 1 || !bodies[0].visible) {
            fail("PANEL_WULL_BODY_UNQUALIFIED"); return
        }
        bodies[0].motionEnabled = false
        bodies[0].bob = 0
        bodies[0].sway = 0
        bodies[0].shimmer = 0
        bodies[0].squash = 0
        console.log("WULL_PANEL_REAL_STAGE=BAR_LAYOUT_FIELD_AND_WULL_READY")
        const target=Quickshell.env("WULL_PANEL_REAL_PRIVATE_PNG")
        if (!target || target.length < 10) {
            fail("PANEL_PRIVATE_PATH_MISSING"); return
        }
        Qt.callLater(() => {
            const ok=sheet.grabToImage(result => {
                if (finished) return
                if (!result || !result.saveToFile(target)) {
                    fail("PANEL_GRAB_FAILED"); return
                }
                finished=true
                console.log("WULL_PANEL_REAL_STAGE=PNG_SAVED")
                Qt.quit()
            }, Qt.size(512,512))
            if (!ok) fail("PANEL_GRAB_UNAVAILABLE")
        })
    }
    FloatingWindow {
        id: window
        visible: true
        color: "transparent"
        implicitWidth: 512; implicitHeight: 512
        title: "Private synthetic output: actual AbyssBar module and field"
        Item {
            id: sheet
            width: 512; height: 512; x:0; y:0
            AbyssField {
                id: field
                anchors.fill: parent
                z: 0
                outputName: ""
                renderScale: 1
                edgeInsets: root.realInsets
                records: bar.deformations
                waveTexture: null
            }
            AbyssBar {
                id: bar
                anchors.fill: parent
                z: 1
                visible: field.ready
                outputName: "synthetic-output"
                edge: root.edgeName
                liquidController: null
                editing: false
            }
            AbyssCompanion {
                id: companion
                z: 2
                edge: root.edgeName
                scale: 1
                reveal: root.slot.qualified && field.ready ? 1 : 0
                interactive: false
                energy: 0
                eyeOpen: 1
                mouthCurve: 0.12
                pulse: 0
                x: root.edgeName === "left" ?
                    root.localDepth()-5 :
                    sheet.width-root.localDepth()-implicitWidth+5
                y: root.slot.qualified ?
                    root.slot.center - implicitHeight * .5 : 0
            }
        }
    }
    Component.onCompleted: console.log("WULL_PANEL_REAL_STAGE=BOOT")
    Timer {
        interval: 4200; running: true; repeat: false
        onTriggered: root.capture()
    }
    Timer {
        interval: 11200; running: true; repeat: false
        onTriggered: root.fail("PANEL_FIXTURE_TIMEOUT")
    }
}
