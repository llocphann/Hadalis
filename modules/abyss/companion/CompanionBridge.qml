import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property string binaryPath: Quickshell.env("INIR_COMPANIOND") ?? ""
    property bool useNativeDispatcher: false
    readonly property string nativeDispatchPath: Quickshell.shellPath("scripts/native-dispatch")
    readonly property var backendCommand: binaryPath.length > 0
        ? [binaryPath]
        : useNativeDispatcher ? [nativeDispatchPath, "companion"] : []
    readonly property bool backendEnabled: backendCommand.length > 0
    property bool ready: false
    property bool requestedVisible: false
    property int outboundSeq: 0
    property double inboundSeq: 0

    property string visibility: "hidden"
    property string mood: "calm"
    property string activity: "idle"
    property real energy: 0
    property real gazeX: 0
    property real gazeY: 0
    property real squash: 0
    property real stretch: 0
    property real lean: 0
    property real tip: 0
    property real ripple: 0
    property real eyeOpen: 1
    property real mouthCurve: 0.12
    property real pulse: 0

    signal stateAccepted(double sequence)

    function boundedNumber(value, fallback, minimum, maximum) {
        const number = Number(value)
        if (!Number.isFinite(number))
            return fallback
        return Math.max(minimum, Math.min(maximum, number))
    }

    function resetState() {
        root.ready = false
        root.requestedVisible = false
        root.outboundSeq = 0
        root.inboundSeq = 0
        root.visibility = "hidden"
        root.mood = "calm"
        root.activity = "idle"
        root.energy = 0
        root.gazeX = 0
        root.gazeY = 0
        root.squash = 0
        root.stretch = 0
        root.lean = 0
        root.tip = 0
        root.ripple = 0
        root.eyeOpen = 1
        root.mouthCurve = 0.12
        root.pulse = 0
    }

    function sendEvent(eventName, activeValue) {
        if (!backendProcess.running || !root.ready)
            return false

        root.outboundSeq += 1
        const message = {
            "v": 1,
            "seq": root.outboundSeq,
            "type": "event",
            "event": eventName
        }
        if (activeValue !== undefined)
            message.active = !!activeValue

        backendProcess.write(JSON.stringify(message) + "\n")
        return true
    }

    function show() {
        root.requestedVisible = true
        if (root.ready)
            root.sendEvent("show")
    }

    function hide() {
        root.requestedVisible = false
        if (root.ready)
            root.sendEvent("hide")
    }

    function acceptLine(line) {
        if (!line || line.length > 8192)
            return

        let message
        try {
            message = JSON.parse(line)
        } catch (_error) {
            return
        }

        const sequence = Number(message.seq)
        if (message.v !== 1 || message.type !== "state"
                || !Number.isFinite(sequence) || sequence <= root.inboundSeq)
            return

        const body = message.body ?? {}
        const face = message.face ?? {}
        const gaze = Array.isArray(message.gaze) ? message.gaze : [0, 0]
        const wasReady = root.ready

        root.inboundSeq = sequence
        root.visibility = ["hidden", "peeking", "present"].includes(message.visibility)
            ? message.visibility : root.visibility
        root.mood = typeof message.mood === "string" ? message.mood : root.mood
        root.activity = typeof message.activity === "string" ? message.activity : root.activity
        root.energy = root.boundedNumber(message.energy, root.energy, 0, 1)
        root.gazeX = root.boundedNumber(gaze[0], root.gazeX, -1, 1)
        root.gazeY = root.boundedNumber(gaze[1], root.gazeY, -1, 1)
        root.squash = root.boundedNumber(body.squash, root.squash, -1, 1)
        root.stretch = root.boundedNumber(body.stretch, root.stretch, -1, 1)
        root.lean = root.boundedNumber(body.lean, root.lean, -1, 1)
        root.tip = root.boundedNumber(body.tip, root.tip, -1, 1)
        root.ripple = root.boundedNumber(body.ripple, root.ripple, 0, 1)
        root.eyeOpen = root.boundedNumber(face.eye, root.eyeOpen, 0.05, 1)
        root.mouthCurve = root.boundedNumber(face.mouth, root.mouthCurve, -1, 1)
        root.pulse = root.boundedNumber(message.pulse, root.pulse, 0, 1)
        root.ready = true
        root.stateAccepted(sequence)

        if (!wasReady && root.requestedVisible)
            Qt.callLater(() => root.sendEvent("show"))
    }

    onBackendEnabledChanged: {
        if (root.backendEnabled) {
            backendProcess.running = true
        } else {
            if (backendProcess.running)
                backendProcess.running = false
            root.resetState()
        }
    }

    Component.onCompleted: {
        if (root.backendEnabled)
            backendProcess.running = true
    }

    Process {
        id: backendProcess
        running: false
        stdinEnabled: true
        command: root.backendCommand

        stdout: SplitParser {
            onRead: line => root.acceptLine(line)
        }

        onRunningChanged: {
            if (!running) {
                root.ready = false
                root.inboundSeq = 0
            }
        }

        onExited: (_exitCode, _exitStatus) => {
            root.ready = false
        }
    }
}
