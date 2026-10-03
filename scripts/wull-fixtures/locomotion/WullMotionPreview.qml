import QtQuick
import QtQuick.Controls
import QtQuick.Window
import Quickshell
import qs.modules.abyss.companion

ApplicationWindow {
    id: root
    width: 1040; height: 610
    visible: true
    color: "#04101e"
    title: "Wull — walking and emergence"
    property bool animate: true
    property real shown: 1
    property real wantedX: 130
    property real wantedY: 162
    property bool walk: false
    property real direction: 1
    property int moveDuration: 3600
    property string sourceEdge: "top"
    readonly property string capture: Quickshell.env("WULL_DESIGN_CAPTURE") ?? ""
    readonly property string frames: Quickshell.env("WULL_DESIGN_FRAMES") ?? ""
    property int frameIndex: 0
    property bool busy: false
    property int walkedFrames: 0
    property int emergedFrames: 0
    property bool quietChecked: false
    property string hiddenSnapshot: ""
    property string initialBubblePositions: ""
    property bool bubblesMoved: false
    property bool depthOrderingChecked: false
    function findNamed(item, name) {
        if (item.objectName === name) return item
        for (const child of item.children) {
            const result=findNamed(child,name)
            if (result) return result
        }
        return null
    }
    function motionSnapshot(): string {
        const body=findNamed(actor,"wullLiquidBody")
        const gait=findNamed(actor,"wullLocomotion")
        return JSON.stringify({bob:body.bob,sway:body.sway,shimmer:body.shimmer,orbit:body.orbitPhase,phase:gait.phase,weight:gait.weight})
    }
    function bubblePositions(): string {
        const bubbles=findNamed(actor,"wullExternalDroplets")
        const positions=[]
        for(let i=0;i<bubbles.count;i++) {
            const b=bubbles.itemAt(i)
            positions.push([b.x,b.y,b.z])
        }
        return JSON.stringify(positions)
    }
    function travel(): void {
        root.walk=true
        root.direction=root.wantedX<400?1:-1
        root.wantedX=root.direction>0?480:130
        root.moveDuration=5469
    }
    Rectangle {
        id: board
        width: 1040; height: 610
        color: "#04101e"
        Text { x: 26; y: 22; text: "Wull, in motion"; color: "#e1f6ff"; font.pixelSize: 32; font.bold: true }
        Text { x: 27; y: 70; text: "Walk · plant · push · lift · emerge · settle"; color: "#78dafa"; font.pixelSize: 17 }
        Rectangle {
            x: 24; y: 117; width: 992; height: 32; radius: 10
            color: "#132238"; border.color: "#6980bb"
            Text { x: 14; anchors.verticalCenter: parent.verticalCenter; text: "ABYSS PANEL"; color: "#b5cbe8"; font.pixelSize: 12 }
        }
        Rectangle {
            x: 692; y: 255; width: 298; height: 148; radius: 14
            color: "#102039"; border.color: "#376897"
            Text { x: 18; y: 18; text: "Connected popup"; color: "#d9f2ff"; font.pixelSize: 18 }
            Text { x: 18; y: 55; width: 250; text: "Wull dives, changes attachment,\nthen emerges beside the surface."; color: "#8daec9"; font.pixelSize: 14; lineHeight: 1.5 }
        }
        AbyssCompanion {
            id: actor
            scale: 2
            managedPlacement: true
            targetX: root.wantedX; targetY: root.wantedY
            edge: "top"; emergenceEdge: root.sourceEdge
            upright: true
            travelEnabled: root.walk
            travelDuration: root.moveDuration
            travelDirection: root.direction
            reveal: root.shown
            motionEnabled: root.animate
            renderQuality: "quality"
            onActivated: expression = "happy"
        }
        Text { x: 28; y: 336; text: "TWO FEET · TWO HANDS"; color: "#78dafa"; font.pixelSize: 13; font.bold: true }
        Text { x: 28; y: 363; width: 550; text: "Feet step, hands swing and bubbles orbit around Wull.\nThe body shifts its weight; its reflection follows every limb."; color: "#9db8cd"; font.pixelSize: 16; lineHeight: 1.5 }
        Row {
            x: 27; y: 455; spacing: 12
            Repeater {
                model: ["Walk", "Emerge from panel", "Move to popup", "Hide", "Pause motion"]
                Button {
                    required property string modelData
                    text: modelData
                    contentItem: Text { text: parent.text; color: "#c4efff"; font.pixelSize: 13; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { color: parent.down ? "#164b69" : parent.hovered ? "#10344d" : "#092237"; radius: 7; border.width: 1; border.color: "#24536e" }
                    onClicked: {
                        if (modelData === "Walk") root.travel()
                        else if (modelData === "Emerge from panel") {
                            root.walk=false; root.sourceEdge="top"; root.wantedX=130; root.wantedY=162; root.shown=1
                        } else if (modelData === "Move to popup") {
                            root.walk=false; root.sourceEdge="right"; root.wantedX=538; root.wantedY=280; root.shown=1
                        } else if (modelData === "Hide") root.shown=0
                        else root.animate=!root.animate
                    }
                }
            }
        }
        Text { x: 28; y: 526; width: 972; text: "Actual Wull renderer · Blender-authored motion curves · No Blender process during desktop use"; color: "#6f91ad"; font.pixelSize: 13 }
        Text { x: 28; y: 554; text: "The dark attachment dot is removed. Light, water feet and the floor reflection remain."; color: "#6f91ad"; font.pixelSize: 13 }
    }
    Timer {
        interval: 50; running: root.frames.length>0; repeat: true
        onTriggered: {
            if (root.busy || !actor.materialReady) return
            if (root.frameIndex === 180) {
                stop()
                if (root.walkedFrames<15 || root.emergedFrames<5 || actor.visible || actor.walking
                        || !root.quietChecked || !root.bubblesMoved || !root.depthOrderingChecked) {
                    console.log("WULL_MOTION_BEHAVIOR=FAILED"); Qt.quit(); return
                }
                console.log("WULL_MOTION_BEHAVIOR="+JSON.stringify({walkedFrames:root.walkedFrames,emergedFrames:root.emergedFrames,hidden:!actor.visible,walking:actor.walking,hiddenClocksFrozen:root.quietChecked,bubblesMoved:root.bubblesMoved,frontAndBackBubbles:root.depthOrderingChecked}))
                console.log("WULL_DESIGN_FRAMES=180_SAVED")
                Qt.quit(); return
            }
            const i=root.frameIndex
            if (i===0) root.shown=0
            if (i===16) root.shown=1
            if (i===38) {
                root.initialBubblePositions=root.bubblePositions()
                root.walk=true; root.direction=1; root.moveDuration=2700; root.wantedX=302.8
            }
            if (i===90) {
                root.bubblesMoved=root.initialBubblePositions!==root.bubblePositions()
                const bubbles=root.findNamed(actor,"wullExternalDroplets")
                let front=0,back=0
                for (let j=0;j<bubbles.count;j++) {
                    if (bubbles.itemAt(j).z>0) front++
                    else back++
                }
                root.depthOrderingChecked=front>0 && back>0
            }
            if (i===100) {
                root.walk=false; root.sourceEdge="right"; root.wantedX=538; root.wantedY=280
            }
            if (i===146) root.shown=0
            if (i===168 && !actor.visible) root.hiddenSnapshot=root.motionSnapshot()
            if (i===177) root.quietChecked=root.hiddenSnapshot.length>0 && root.hiddenSnapshot===root.motionSnapshot()
            if (actor.walking) root.walkedFrames++
            if (actor.presentation>0.05 && actor.presentation<0.95) root.emergedFrames++
            root.busy=true
            board.grabToImage(function(result) {
                const file=root.frames+"/frame-"+String(i).padStart(4,"0")+".png"
                if(!result.saveToFile(file)) { console.log("WULL_DESIGN_FRAMES=FAILED"); Qt.quit(); return }
                root.frameIndex++; root.busy=false
            },Qt.size(board.width,board.height))
        }
    }
    Timer {
        interval: 1700; running: root.capture.length>0; repeat: false
        onTriggered: board.grabToImage(function(result) {
            console.log("WULL_DESIGN_CAPTURE="+(result.saveToFile(root.capture)?"SAVED":"FAILED"))
            Qt.quit()
        },Qt.size(board.width,board.height))
    }
}
