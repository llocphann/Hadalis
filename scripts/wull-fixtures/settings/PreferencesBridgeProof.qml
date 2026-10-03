import QtQuick
import Quickshell
import qs.modules.abyss.companion

Scope {
    id: root
    property int stage: 0
    property int states: 0
    property int quietStates: 0
    function require(condition, message) {
        if (!condition) {
            console.error("WULL_SETTINGS_BRIDGE=FAIL " + message)
            Qt.exit(1)
        }
    }
    CompanionBridge {
        id: bridge
        binaryPath: Quickshell.env("WULL_SETTINGS_TEST_BINARY") || ""
        personality: "calm"
        appearanceFrequency: "rare"
        Component.onCompleted: show()
        onStateAccepted: sequence => {
            root.states++
            if (root.stage === 0 && visibility === "present") {
                root.require(energy > 0.12 && energy < 0.13, "initial Calm preference not applied before show")
                root.stage = 1
                personality = "balanced"
            } else if (root.stage === 1) {
                root.require(visibility === "present" && Math.abs(energy - 0.22) < 0.001, "live Balanced preference missing")
                root.stage = 2
                personality = "energetic"
            } else if (root.stage === 2) {
                root.require(visibility === "present" && energy > 0.29 && energy < 0.30, "live Energetic preference missing")
                root.stage = 3
                appearanceFrequency = "frequent"
            } else if (root.stage === 3) {
                root.require(visibility === "present", "frequency changed host permission")
                root.stage = 4
                hide()
            } else if (root.stage === 4) {
                root.require(visibility === "hidden", "explicit hide ignored")
                root.stage = 5
                appearanceFrequency = "always"
            } else if (root.stage === 5) {
                root.require(visibility === "hidden", "Always preference revived policy-hidden Wull")
                root.stage = 6
                root.quietStates = root.states
                quiet.start()
            }
        }
    }
    Timer {
        id: quiet
        interval: 800
        onTriggered: {
            root.require(root.states === root.quietStates && bridge.visibility === "hidden", "hidden backend sent autonomous state")
            console.log("WULL_SETTINGS_BRIDGE=PASS LIVE_PROFILES_AND_HIDDEN_PERMISSION")
            Qt.quit()
        }
    }
    Timer { running: true; interval: 8000; onTriggered: { console.error("WULL_SETTINGS_BRIDGE=FAIL timeout"); Qt.exit(1) } }
}
