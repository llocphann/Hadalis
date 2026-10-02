// Private synthetic FOUR actual-production-host poses. No desktop read,
// host screenshot, pointer injection, external artwork or input-mask edits.
import QtQuick
import Quickshell
import qs.modules.abyss.companion

ShellRoot {
    id: root
    property bool finished: false
    readonly property var cases: [
        { host: topHost, edge: "top" },
        { host: bottomHost, edge: "bottom" },
        { host: leftHost, edge: "left" },
        { host: rightHost, edge: "right" }
    ]
    function fail(reason): void {
        if (finished) return
        finished = true
        console.log("WULL_VISUAL_MATRIX_FAIL=" + reason)
        Qt.quit()
    }
    function capture(): void {
        if (finished) return
        if (!privateWindow.backingWindowVisible ||
                Math.abs(sheet.width - 512) > .1 ||
                Math.abs(sheet.height - 512) > .1) {
            fail("WINDOW_UNAVAILABLE"); return
        }
        for (const spec of cases) {
            const host = spec.host
            const bodies = host.children.filter(item =>
                item.width === 76 && item.height === 92)
            if (host.edge !== spec.edge || !host.visible ||
                    Math.abs(host.scale - 1.25) > .001 || bodies.length !== 1) {
                fail("HOST_GEOMETRY_INVALID"); return
            }
            const body = bodies[0]
            body.motionEnabled = false
            body.bob = 0
            body.sway = 0
            body.shimmer = 0
            body.squash = 0
            if (!body.visible) { fail("BODY_NOT_VISIBLE"); return }
        }
        console.log("WULL_VISUAL_MATRIX_STAGE=FOUR_HOSTS_FROZEN")
        const output = Quickshell.env("WULL_VISUAL_MATRIX_PRIVATE_FILE")
        if (!output || output.length < 10) {
            fail("PRIVATE_PATH_UNSET"); return
        }
        Qt.callLater(function() {
            const ok = sheet.grabToImage(function(result) {
                if (finished) return
                if (!result || !result.saveToFile(output)) {
                    fail("PRIVATE_SAVE_FAILED"); return
                }
                finished = true
                console.log("WULL_VISUAL_MATRIX_STAGE=SYNTHETIC_SHEET_SAVED")
                Qt.quit()
            }, Qt.size(512, 512))
            if (!ok) fail("PRIVATE_GRAB_UNAVAILABLE")
        })
    }
    FloatingWindow {
        id: privateWindow
        visible: false
        color: "transparent"
        Component.onCompleted: visible = true
        implicitWidth: 512
        implicitHeight: 512
        title: "Private synthetic Wull visual matrix"
        Item {
            id: sheet
            anchors.fill: parent
            Text { x: 78; y: 32; text: "TOP / IDLE"; color: "#d2dce6" }
            Text { x: 302; y: 32; text: "BOTTOM / HAPPY"; color: "#d2dce6" }
            Text { x: 78; y: 268; text: "LEFT / CURIOUS"; color: "#d2dce6" }
            Text { x: 302; y: 268; text: "RIGHT / SLEEPY"; color: "#d2dce6" }
            AbyssCompanion {
                id: topHost
                edge: "top"; x: 91; y: 95; scale: 1.25
                reveal: 1; energy: 0; interactive: false
                eyeOpen: 1; mouthCurve: 0.12
            }
            AbyssCompanion {
                id: bottomHost
                edge: "bottom"; x: 318; y: 95; scale: 1.25
                reveal: 1; energy: 0; interactive: false
                eyeOpen: 1; mouthCurve: 0.8; pulse: 0.8
                bodySquash: 0.65
            }
            AbyssCompanion {
                id: leftHost
                edge: "left"; x: 91; y: 325; scale: 1.25
                reveal: 1; energy: 0; interactive: false
                eyeOpen: 1; mouthCurve: 0.15; gazeX: 0.8
                bodyLean: 0.45; bodyTip: 0.3
            }
            AbyssCompanion {
                id: rightHost
                edge: "right"; x: 318; y: 325; scale: 1.25
                reveal: 1; energy: 0; interactive: false
                eyeOpen: 0.4; mouthCurve: 0.06
                bodyStretch: 0.2
            }
        }
    }
    Component.onCompleted: console.log("WULL_VISUAL_MATRIX_STAGE=BOOT")
    Timer { interval: 1700; running: true; repeat: false; onTriggered: root.capture() }
    Timer { interval: 8500; running: true; repeat: false;
        onTriggered: root.fail("PRIVATE_QT_TIMEOUT") }
}
