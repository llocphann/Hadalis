// Isolated, disposable Quickshell proof. No production shell or user config.
import QtQuick
import Quickshell
import "./companion" as Companion

ShellRoot {
    id: root
    readonly property string testCase: Quickshell.env("WULL_SMOKE_CASE") ?? ""
    property bool backendOn: ["exit-restart", "auto-restart",
                               "crash-budget", "disable-pending",
                               "budget-reset"].includes(testCase)
    property string stage: testCase.startsWith("disabled") ? "disabled"
        : ["crash-budget", "budget-reset"].includes(testCase)
            ? "budget" : "initial"

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
        if (["exit-restart", "auto-restart", "crash-budget",
             "disable-pending", "budget-reset"].includes(root.testCase))
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
            if (root.testCase === "disable-pending") {
                // Cancel the first 500ms retry before its deadline.
                root.stage = "disabled-after-exit"
                root.backendOn = false
                verifyCancelled.restart()
            } else {
                root.stage = "restarting"
                if (root.testCase === "exit-restart") {
                    root.backendOn = false
                    rearm.restart()
                }
                // auto-restart keeps the backend enabled and requires
                // the bridge's own bounded retry to reconnect.
            }
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
        id: verifyCancelled
        interval: 850
        onTriggered: {
            if (root.stage === "disabled-after-exit"
                    && !bridge.backendEnabled && !bridge.ready
                    && !bridge.requestedVisible
                    && bridge.restartAttempts === 0) {
                console.log("WULL_BRIDGE_DISABLE_CANCEL_OK")
            } else {
                console.log("WULL_BRIDGE_FIXTURE_INVALID")
            }
            Qt.quit()
        }
    }

    Timer {
        interval: 9600
        running: ["crash-budget", "budget-reset"].includes(root.testCase)
        onTriggered: {
            if (!bridge.backendEnabled || bridge.ready
                    || bridge.restartAttempts !== bridge.maxRestartAttempts) {
                console.log("WULL_BRIDGE_FIXTURE_INVALID")
                Qt.quit()
                return
            }
            if (root.testCase === "budget-reset") {
                root.backendOn = false
                root.stage = "budget-reset"
                budgetRearm.restart()
            } else {
                console.log("WULL_BRIDGE_CRASH_BUDGET_OK")
                Qt.quit()
            }
        }
    }

    Timer {
        id: budgetRearm
        interval: 125
        onTriggered: {
            if (bridge.restartAttempts !== 0 || bridge.backendEnabled) {
                console.log("WULL_BRIDGE_FIXTURE_INVALID")
                Qt.quit()
                return
            }
            root.backendOn = true
            bridge.show()
            budgetConfirm.restart()
        }
    }

    Timer {
        id: budgetConfirm
        interval: 350
        onTriggered: {
            if (root.stage === "budget-reset" && bridge.backendEnabled
                    && !bridge.ready && bridge.requestedVisible
                    && bridge.restartAttempts >= 1
                    && bridge.restartAttempts < bridge.maxRestartAttempts) {
                console.log("WULL_BRIDGE_BUDGET_RESET_OK")
            } else {
                console.log("WULL_BRIDGE_FIXTURE_INVALID")
            }
            Qt.quit()
        }
    }

    Timer {
        interval: root.testCase === "budget-reset" ? 12500
            : root.testCase === "crash-budget" ? 11000 : 8000
        running: true
        onTriggered: {
            console.log("WULL_BRIDGE_FIXTURE_TIMEOUT")
            Qt.quit()
        }
    }
}
