// Isolated, disposable Quickshell proof. No production shell or user config.
import QtQuick
import Quickshell
import "./companion" as Companion

ShellRoot {
    id: root
    readonly property string testCase: Quickshell.env("WULL_SMOKE_CASE") ?? ""
    property bool backendOn: ["exit-restart", "auto-restart",
                               "crash-budget"].includes(testCase)
    property string stage: testCase.startsWith("disabled") ? "disabled"
        : testCase === "crash-budget" ? "budget" : "initial"

    Companion.CompanionBridge {
        id: bridge
        // Match the production host's guarded development binary override.
        binaryPath: root.backendOn ? (Quickshell.env("INIR_COMPANIOND") ?? "") : ""
        useNativeDispatcher: root.backendOn
        onStateAccepted: (_sequence) => {
            if (root.stage === "initial" && bridge.visibility === "present") {
                root.stage = "exiting"
                if (!bridge.sendEvent("click")) {
                    console.log("WULL_BRIDGE_FIXTURE_INVALID")
                    Qt.quit()
                }
            } else if (root.stage === "restarting" && bridge.visibility === "present") {
                if (bridge.ready && bridge.requestedVisible) {
                    console.log("WULL_BRIDGE_RESTART_OK")
                    Qt.quit()
                }
            }
        }
        onReadyChanged: {
            if (!bridge.ready && root.stage === "exiting")
                verifyExit.restart()
        }
    }

    Component.onCompleted: {
        if (["exit-restart", "auto-restart", "crash-budget"].includes(root.testCase))
            bridge.show()
        else if (!root.testCase.startsWith("disabled")) {
            console.log("WULL_BRIDGE_FIXTURE_INVALID")
            Qt.quit()
        }
    }

    Timer {
        id: verifyDisabled
        interval: 350
        running: root.testCase === "disabled" || root.testCase === "disabled-override"
        onTriggered: {
            if (!bridge.backendEnabled && !bridge.ready
                    && bridge.visibility === "hidden") {
                console.log("WULL_BRIDGE_DISABLED_OK")
            } else {
                console.log("WULL_BRIDGE_FIXTURE_INVALID")
            }
            Qt.quit()
        }
    }

    Timer {
        id: verifyExit
        interval: 150
        onTriggered: {
            // The production host gates visibility and input on ready.
            // A previously accepted present state must not imply readiness
            // after the fake daemon has unexpectedly exited.
            if (root.stage !== "exiting" || bridge.ready
                    || !bridge.requestedVisible
                    || bridge.visibility !== "present") {
                console.log("WULL_BRIDGE_FIXTURE_INVALID")
                Qt.quit()
                return
            }
            console.log("WULL_BRIDGE_EXIT_GATE_OK")
            root.stage = "restarting"
            if (root.testCase === "exit-restart") {
                root.backendOn = false
                rearm.restart()
            }
            // auto-restart intentionally keeps the backend enabled and
            // requires the bridge's own bounded retry to reconnect.
        }
    }

    Timer {
        id: rearm
        interval: 150
        onTriggered: {
            root.backendOn = true
            bridge.show()
        }
    }

    Timer {
        interval: 9600
        running: root.testCase === "crash-budget"
        onTriggered: {
            if (bridge.backendEnabled && !bridge.ready
                    && bridge.restartAttempts === bridge.maxRestartAttempts) {
                console.log("WULL_BRIDGE_CRASH_BUDGET_OK")
            } else {
                console.log("WULL_BRIDGE_FIXTURE_INVALID")
            }
            Qt.quit()
        }
    }

    Timer {
        interval: root.testCase === "crash-budget" ? 11000 : 8000
        running: true
        onTriggered: {
            console.log("WULL_BRIDGE_FIXTURE_TIMEOUT")
            Qt.quit()
        }
    }
}
