import QtQuick
import QtQuick.Controls
import QtQuick.Window
import Quickshell
import qs.modules.abyss.companion
import "../../../modules/abyss/companion/WullExpressions.js" as Expressions

ApplicationWindow {
    id: root
    width: Math.min(1440, Screen.width - 80)
    height: Math.min(1230, Screen.height - 80)
    visible: true
    color: "#020d19"
    title: "Wull — liquid companion design"
    property string selectedExpression: "idle"
    property color selectedAccent: "#478dff"
    property bool animate: true
    property real previewReveal: 1
    property real previewX: 115
    property real previewYaw: -15
    readonly property string capturePath: Quickshell.env("WULL_DESIGN_CAPTURE") ?? ""
    readonly property bool capturing: capturePath.length > 0
    readonly property string framesPath: Quickshell.env("WULL_DESIGN_FRAMES") ?? ""
    property int frameIndex: 0
    property bool frameBusy: false
    readonly property var themes: [
        { name: "ABYSS BLUE", color: "#478dff" },
        { name: "WARM AMBER", color: "#ffa94c" },
        { name: "PURPLE", color: "#aa72ff" },
        { name: "SEA GREEN", color: "#09daba" }
    ]
    function react(expression) {
        selectedExpression = expression
        reactionReset.restart()
    }
    Timer { id: reactionReset; interval: 1800; onTriggered: root.selectedExpression = "idle" }
    ScrollView {
        anchors.fill: parent
        contentWidth: board.width; contentHeight: board.height
        Rectangle {
            id: board
            width: 1440; height: 1230
            gradient: Gradient {
                GradientStop { position: 0; color: "#061a30" }
                GradientStop { position: 0.45; color: "#020d19" }
                GradientStop { position: 1; color: "#031627" }
            }
            Rectangle {
                x: 22; y: 22; width: 1396; height: 284; radius: 20
                color: "#071626"; border.width: 1; border.color: "#154563"
                WaterDropletBody {
                    id: hero
                    x: root.previewX; y: 162; width: 76; height: 92; scale: 3.0
                    expression: root.selectedExpression
                    viewYaw: root.previewYaw
                    accentColor: root.selectedAccent
                    energy: expressionProfile.energy
                    pulse: expressionProfile.shine ? 0.6 : 0.1
                    motionEnabled: root.animate && !root.capturing
                    opacity: root.previewReveal
                    reveal: root.previewReveal
                    onPressed: root.react("happy")
                }
                Text { x: 410; y: 38; text: "Wull"; font.pixelSize: 62; font.bold: true; color: "#edfaff" }
                Text { x: 411; y: 119; text: "A little drop of life."; font.pixelSize: 25; color: "#5ae1ff" }
                Text {
                    x: 412; y: 162; width: 480
                    text: "3D liquid volume · reflected light · refraction\nCurved surface, liquid depth and luminous caustics"
                    color: "#9eb6cd"; font.pixelSize: 16; lineHeight: 1.5
                }
                Row {
                    x: 320; y: 230; spacing: 10
                    Repeater {
                        model: ["Appear", "Tap", "Notify", "Complete", "Travel", "Hide"]
                        Button {
                            required property string modelData
                            text: modelData
                            contentItem: Text { text: parent.text; color: "#c4efff"; font.pixelSize: 13; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            background: Rectangle { color: parent.down ? "#164b69" : parent.hovered ? "#10344d" : "#092237"; radius: 7; border.width: 1; border.color: "#24536e" }
                            onClicked: {
                                if (modelData === "Appear") root.previewReveal = 1
                                else if (modelData === "Hide") root.previewReveal = 0
                                else if (modelData === "Travel") root.previewX = root.previewX === 115 ? 200 : 115
                                else root.react(modelData === "Tap" ? "happy" : modelData === "Notify" ? "alert" : "excited")
                            }
                        }
                    }
                }
                Row {
                    x: 660; y: 230; spacing: 6
                    Repeater {
                        model: [{name: "Front", yaw: 0}, {name: "3/4", yaw: 35}, {name: "Side", yaw: 90}, {name: "Back", yaw: 180}]
                        Button {
                            required property var modelData
                            text: modelData.name
                            contentItem: Text { text: parent.text; color: "#c4efff"; font.pixelSize: 12; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            background: Rectangle { color: root.previewYaw === modelData.yaw ? "#164b69" : "#092237"; radius: 7; border.width: 1; border.color: "#24536e" }
                            onClicked: root.previewYaw = modelData.yaw
                        }
                    }
                }
                Column {
                    x: 928; y: 32; spacing: 12
                    Text { text: "PANEL COLOR ADAPTATION"; font.pixelSize: 14; color: "#72dafa" }
                    Row {
                        spacing: 12
                        Repeater {
                            model: root.themes
                            Rectangle {
                                required property var modelData
                                width: 104; height: 165; radius: 12
                                color: "#06101d"; border.width: 1; border.color: "#15334d"
                                WaterDropletBody {
                                    x: 13; y: 26; width: 76; height: 92
                                    accentColor: modelData.color
                                    motionEnabled: root.animate && !root.capturing
                                    enabled: false
                                }
                                Rectangle { x: 41; y: 130; width: 22; height: 6; radius: 3; color: modelData.color }
                                TapHandler { onTapped: root.selectedAccent = modelData.color }
                            }
                        }
                    }
                    Text { text: "Select a color to preview the material."; font.pixelSize: 12; color: "#819bb5" }
                }
            }
            Text { x: 30; y: 327; text: "01   EXPRESSIONS"; color: "#60deff"; font.pixelSize: 22; font.bold: true }
            Text { x: 30; y: 362; text: "One continuous character. Nine readable emotional states."; color: "#9ab6cb"; font.pixelSize: 15 }
            Row {
                x: 24; y: 397; spacing: 10
                Repeater {
                    id: expressionCards
                    model: Expressions.names
                    Rectangle {
                        id: card
                        required property string modelData
                        width: 145; height: 193; radius: 13
                        color: "#051320"; border.width: 1
                        border.color: root.selectedExpression === modelData ? "#41ccff" : "#183f59"
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter; y: 16
                            text: card.modelData.toUpperCase(); font.pixelSize: 13; font.bold: true; color: "#d8f4ff"
                        }
                        WaterDropletBody {
                            id: sample
                            x: 35; y: 59; width: 76; height: 92; scale: 1.30
                            expression: card.modelData
                            accentColor: root.selectedAccent
                            energy: expressionProfile.energy
                            pulse: expressionProfile.shine ? 0.5 : 0
                            stateLean: expression === "thinking" ? 0.12 : 0
                            motionEnabled: root.animate && !root.capturing
                            onPressed: root.selectedExpression = card.modelData
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter; y: 167
                            text: ["idle", "sleepy", "working"].includes(card.modelData) ? "gentle motion" : "react + settle"
                            font.pixelSize: 11; color: "#829eb7"
                        }
                    }
                }
            }
            Text { x: 30; y: 619; text: "02   3D SURFACE VIEWS"; color: "#60deff"; font.pixelSize: 22; font.bold: true }
            Row {
                x: 24; y: 664; spacing: 14
                Repeater {
                    model: [
                        { title: "FRONT", desc: "Curved shell · liquid core", yaw: 0 },
                        { title: "SIDE", desc: "Volume · refracted light", yaw: 90 },
                        { title: "BACK", desc: "Glass depth · reflections", yaw: 180 },
                        { title: "3/4", desc: "Turn · moving highlights", yaw: 35 }
                    ]
                    Rectangle {
                        required property var modelData
                        width: 337; height: 190; radius: 14
                        color: "#051320"; border.width: 1; border.color: "#183f59"
                        WaterDropletBody {
                            x: 28; y: 50; width: 76; height: 92; scale: 1.3
                            viewYaw: modelData.yaw
                            accentColor: root.selectedAccent
                            energy: expressionProfile.energy
                            pulse: expressionProfile.shine ? 0.65 : 0.1
                            motionEnabled: root.animate && !root.capturing
                            enabled: false
                        }
                        Text { x: 139; y: 56; text: modelData.title; color: "#d8f4ff"; font.pixelSize: 13; font.bold: true }
                        Text { x: 139; y: 90; width: 178; wrapMode: Text.WordWrap; text: modelData.desc; color: "#829eb7"; font.pixelSize: 14; lineHeight: 1.4 }
                    }
                }
            }
            Text { x: 30; y: 886; text: "03   REFERENCE COMPARISON"; color: "#60deff"; font.pixelSize: 22; font.bold: true }
            Text { x: 385; y: 924; text: "MAINTAINER REFERENCE"; color: "#9ab6cb"; font.pixelSize: 14 }
            Text { x: 868; y: 924; text: hero.softwareFallback ? "ACTUAL SOFTWARE FALLBACK" : "ACTUAL GPU RENDER"; color: "#9ab6cb"; font.pixelSize: 14 }
            // Original reference is displayed only in this development gallery.
            // Production Wull never loads it or any captured character frames.
            Item {
                x: 335; y: 946; width: 360; height: 240; clip: true
                Image {
                    width: 828.24; height: 240.12
                    source: Quickshell.env("WULL_DESIGN_REFERENCE") || Qt.resolvedUrl("../../../docs/wull-visual/design-20261003/reference-closeup.png")
                    fillMode: Image.Stretch
                }
            }
            WaterDropletBody {
                x: 950; y: 1109; width: 76; height: 92; scale: 3.0
                accentColor: "#478dff"
                motionEnabled: false
                enabled: false
            }
            Text { x: 28; y: 1201; text: "LIVE QML RENDERER PREVIEW  ·  Rust semantic states  ·  Local model adapter prepared separately"; color: "#6788a5"; font.pixelSize: 12 }
            Button {
                x: 1250; y: 868; text: root.animate ? "Pause motion" : "Resume motion"
                contentItem: Text { text: parent.text; color: "#c4efff"; font.pixelSize: 13; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                background: Rectangle { color: parent.hovered ? "#10344d" : "#092237"; radius: 7; border.width: 1; border.color: "#24536e" }
                onClicked: root.animate = !root.animate
            }
        }
    }
    Behavior on previewReveal { enabled: root.animate && !root.capturing; NumberAnimation { duration: 360; easing.type: Easing.OutCubic } }
    Behavior on previewX { enabled: root.animate && !root.capturing; NumberAnimation { duration: 850; easing.type: Easing.InOutCubic } }
    Timer {
        interval: 50; running: root.framesPath.length > 0; repeat: true
        onTriggered: {
            if (root.frameBusy || !hero.materialReady) return
            if (root.frameIndex === 180) {
                stop()
                console.log("WULL_DESIGN_FRAMES=180_SAVED")
                Qt.quit()
                return
            }
            root.frameBusy = true
            const index = root.frameIndex
            if (index % 18 === 0) {
                const phase = Math.floor(index / 18)
                root.selectedExpression = Expressions.names[phase % 9]
                root.previewReveal = phase === 9 ? 0 : 1
                root.previewX = phase === 2 || phase === 3 ? 180 : 115
                root.previewYaw = phase === 3 || phase === 6 ? 35 : phase === 4 ? 90 : phase === 5 ? 180 : 0
                root.selectedAccent = root.themes[Math.floor(phase / 2) % 4].color
            }
            board.grabToImage(function(result) {
                const filename = root.framesPath + "/frame-" + String(index).padStart(4, "0") + ".png"
                if (!result.saveToFile(filename)) {
                    console.log("WULL_DESIGN_FRAMES=FAILED")
                    Qt.quit()
                    return
                }
                root.frameIndex += 1
                root.frameBusy = false
            }, Qt.size(board.width, board.height))
        }
    }
    Timer {
        interval: 1700; running: root.capturing; repeat: false
        onTriggered: {
            if (!hero.materialReady && !hero.softwareFallback) {
                console.log("WULL_DESIGN_CAPTURE=SHADER_NOT_READY")
                Qt.quit()
                return
            }
            board.grabToImage(function(result) {
                console.log("WULL_DESIGN_CAPTURE=" + (result.saveToFile(root.capturePath) ? "SAVED" : "FAILED"))
                Qt.quit()
            }, Qt.size(board.width, board.height))
        }
    }
}
