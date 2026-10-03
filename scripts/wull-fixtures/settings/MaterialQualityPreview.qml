//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env INIR_STANDALONE_WINDOW=1
import QtQuick
import QtQuick.Controls
import Quickshell
import qs.modules.common
import qs.modules.abyss.companion
import qs.modules.abyss.looks

ApplicationWindow {
    id: root
    width: 1200; height: 830
    visible: true
    color: "#020c18"
    title: "Wull material quality comparison"
    property int bootTicks: 0
    property int probeIndex: 0
    readonly property string probeDirectory: Quickshell.env("WULL_MATERIAL_PROBES") || ""
    readonly property var probeLevels: [0, 0.16, 0.35]
    function require(condition, message) {
        if (!condition) {
            console.error("WULL_MATERIAL_CHECK=FAIL " + message)
            Qt.exit(1)
        }
    }
    function find(item, name) {
        if (item.objectName === name) return item
        for (const child of item.children ?? []) {
            const result = root.find(child, name)
            if (result) return result
        }
        return null
    }
    Rectangle {
        id: board
        width: 1200; height: 830
        color: "#020c18"
        Text { x: 24; y: 22; text: "Wull — liquid material"; color: "#e2f7ff"; font.pixelSize: 30; font.bold: true }
        Text { x: 24; y: 61; text: "Actual QML renderer · same live Abyss accent · centered tip · two feet and two hands"; color: "#84adce"; font.pixelSize: 15 }
        Repeater {
            id: tiers
            model: ["performance", "balanced", "quality"]
            Rectangle {
                id: card
                required property int index
                required property string modelData
                x: 24 + index * 392; y: 104; width: 368; height: 458
                radius: 18
                color: "#061320"
                border.width: 1; border.color: "#16425c"
                property alias specimen: droplet
                Text {
                    x: 24; y: 22
                    text: ["Performance", "Balanced", "Quality"][card.index]
                    color: "#94e4ff"; font.pixelSize: 22; font.bold: true
                }
                WaterDropletBody {
                    id: droplet
                    x: (card.width - width) * 0.5; y: 189
                    width: 76; height: 92; scale: 3
                    transformOrigin: Item.Center
                    viewYaw: -15
                    motionEnabled: false
                    enabled: false
                    renderQuality: card.modelData
                }
                Text {
                    x: 24; y: 375; width: 320
                    text: ["Simpler light rig\nNo floor texture capture",
                        "Refracted light and volume detail\nBody, face and feet floor reflection",
                        "Internal reflection and subtle dispersion\nMore inner bubbles, clearer floor mirror"][card.index]
                    color: "#aac5d9"; font.pixelSize: 14; lineHeight: 1.4
                }
            }
        }
        Image {
            x: 24; y: 604; width: 713; height: 199
            source: "file://" + Quickshell.env("WULL_MATERIAL_REFERENCE")
            fillMode: Image.PreserveAspectFit
            smooth: true
        }
        Text { x: 760; y: 621; width: 410; text: "Original concept"; color: "#94e4ff"; font.pixelSize: 22; font.bold: true }
        Text { x: 760; y: 663; width: 410; text: "Provided reference, shown unchanged.\n\nLighting and fine detail still differ.\nThis comparison does not certify 100% resemblance."; color: "#aac5d9"; font.pixelSize: 15; lineHeight: 1.3 }
    }
    Timer {
        id: boot
        interval: 100; running: true; repeat: true
        onTriggered: {
            if (!Config.ready) { root.require(++root.bootTicks < 80, "config timeout"); return }
            stop()
            Appearance.colors.colPrimary = "#478dff"
            // The shared shell performance policy is a ceiling, even when
            // the individual companion is configured for Quality.
            Config.options.abyss.quality = "performance"
            Qt.callLater(() => {
                for (let i = 0; i < tiers.count; ++i) {
                    const body = tiers.itemAt(i).specimen
                    root.require(body.qualityLevel === 0 && root.find(body, "wullFloorReflectionSource").sourceItem === null,
                        "global Performance policy did not cap Wull")
                }
                Config.options.abyss.quality = "balanced"
                capture.start()
            })
        }
    }
    Timer {
        id: capture
        interval: 1200
        onTriggered: {
            for (let i = 0; i < tiers.count; ++i) {
                const body = tiers.itemAt(i).specimen
                root.require(body.materialReady && body.qualityLevel === i, "material tier not rendered")
                root.require(body.accentColor.toString() === AbyssStyle.accent.toString(), "theme binding lost")
                const limbs=root.find(body,"wullWaterLimbs")
                root.require(limbs.count===4,"quality tier lost limbs")
                let hands=0, feet=0
                for (let j=0;j<limbs.count;j++) {
                    const limb=limbs.itemAt(j)
                    if (limb.hand) { hands++; root.require(limb.y<60,"hand at ground height") }
                    else { feet++; root.require(limb.y>68,"foot above ground") }
                }
                root.require(hands===2 && feet===2,"Wull must have two hands and two feet")
                root.require(root.find(body, "wullExternalDroplets").count === [3,6,8][i], "tier droplet budget wrong")
                root.require((root.find(body, "wullFloorReflectionSource").sourceItem !== null) === (i > 0), "floor capture tier budget wrong")
            }
            root.require(board.grabToImage(result => {
                root.require(result.saveToFile(Quickshell.env("WULL_MATERIAL_CAPTURE")), "capture failed")
                console.log("WULL_MATERIAL_TIERS=PASS CAPTURE_SAVED")
                if (root.probeDirectory) {
                    tiers.itemAt(2).specimen.translucency = root.probeLevels[0]
                    probe.start()
                } else Qt.quit()
            }), "capture unavailable")
        }
    }
    Timer {
        id: probe
        interval: 180
        onTriggered: {
            const body = tiers.itemAt(2).specimen
            root.require(body.grabToImage(result => {
                root.require(result.saveToFile(root.probeDirectory + "/translucency-" + root.probeIndex + ".png"), "alpha capture failed")
                root.probeIndex += 1
                if (root.probeIndex === root.probeLevels.length) {
                    console.log("WULL_MATERIAL_ALPHA_PROBES=SAVED")
                    Qt.quit()
                } else {
                    body.translucency = root.probeLevels[root.probeIndex]
                    probe.start()
                }
            }, Qt.size(228, 276)), "alpha capture unavailable")
        }
    }
}
