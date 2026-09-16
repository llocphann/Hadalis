pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Optional Equalizer capability facade.
 *
 * Phase 1 deliberately keeps this service disabled by default and detached
 * from Media UI. EasyEffects is the first backend; socat is used only as an
 * optional transport to EasyEffects' local control socket. Missing backend or
 * transport degrades to an unavailable capability and never affects playback.
 */
Singleton {
    id: root

    property bool enabled: false
    readonly property string backendName: "EasyEffects"
    readonly property bool backendAvailable: root.enabled && EasyEffects.available && root._transportAvailable
    readonly property bool backendRunning: root.enabled && EasyEffects.active
    readonly property bool available: root.backendAvailable && root.backendRunning && root._equalizerAvailable
    readonly property real minimumBandGain: -36
    readonly property real maximumBandGain: 36
    readonly property bool bandControlAvailable: {
        if (!root.available || root.bands.length === 0)
            return false
        for (let i = 0; i < root.bands.length; ++i) {
            if (root.bands[i]?.synced !== true)
                return false
        }
        return true
    }

    property string error: ""
    property list<string> presets: []
    property string activePreset: ""
    // Band count, frequencies and gains are discovered from the running
    // EasyEffects equalizer. EasyEffects supports a configurable 1-32 bands.
    property var bands: []

    property bool _transportChecked: false
    property bool _transportAvailable: false
    property bool _equalizerAvailable: false
    property string _pendingPreset: ""
    property int _pendingBandIndex: -1
    property real _pendingBandGain: 0
    property int _lifecycleGeneration: 0
    readonly property bool _mutationBusy: applyPresetProc.running || setBandProc.running || resetProc.running

    function _markBandsUnsynced() {
        root.bands = root.bands.map(band => Object.assign({}, band, { synced: false }))
    }

    function _cancelReadProcesses() {
        presetScanProc.running = false
        activePresetProc.running = false
        bandRefreshProc.running = false
    }

    function _cancelBackendProcesses() {
        backendRefreshTimer.stop()
        root._cancelReadProcesses()
        applyPresetProc.running = false
        setBandProc.running = false
        resetProc.running = false
        root._pendingPreset = ""
        root._pendingBandIndex = -1
    }

    function _cancelProcesses() {
        root._cancelBackendProcesses()
        transportProbe.running = false
    }

    function _beginMutation() {
        // Any read already in flight describes state before this mutation.
        // Invalidate it before stopping the process so late callbacks cannot
        // publish stale data over the mutation result.
        root._lifecycleGeneration++
        root._cancelReadProcesses()
        return root._lifecycleGeneration
    }

    function _setProcessError(message, generation) {
        if (!root.enabled || generation !== root._lifecycleGeneration)
            return
        root.error = message
    }

    function _errorForExit(exitCode, fallback) {
        if (exitCode === 65)
            return "backend-not-running"
        if (exitCode === 127) {
            root._transportAvailable = false
            root._equalizerAvailable = false
            return "transport-unavailable"
        }
        return fallback
    }

    function _clearRecoveredBackendError() {
        switch (root.error) {
        case "transport-probe-failed":
        case "transport-unavailable":
        case "backend-unavailable":
        case "backend-not-running":
        case "equalizer-unavailable":
        case "band-query-failed":
        case "malformed-band-response":
            root.error = ""
            break
        default:
            break
        }
    }

    function _scheduleReconcile() {
        if (root.enabled && root.backendAvailable && root.backendRunning)
            backendRefreshTimer.restart()
    }

    function _startTransportProbe() {
        if (transportProbe.running)
            return
        root._transportChecked = false
        transportProbe.generation = root._lifecycleGeneration
        transportProbe.running = true
    }

    function _retryStaleTransportProbe(generation) {
        if (!root.enabled || generation === root._lifecycleGeneration || root._transportChecked)
            return
        Qt.callLater(() => {
            if (root.enabled && !root._transportChecked)
                root._startTransportProbe()
        })
    }

    function _refreshBackendState() {
        if (!root.enabled)
            return
        if (!root._transportChecked || !root._transportAvailable) {
            root._startTransportProbe()
            return
        }
        if (!EasyEffects.available) {
            root._equalizerAvailable = false
            root.activePreset = ""
            root.bands = []
            root.error = "backend-unavailable"
            return
        }

        EasyEffects.fetchActiveState()
        if (!EasyEffects.active) {
            root._equalizerAvailable = false
            root.activePreset = ""
            root._markBandsUnsynced()
            root.error = "backend-not-running"
            return
        }

        root._refreshData()
    }

    function _refreshData() {
        if (!root.backendAvailable || !root.backendRunning || root._mutationBusy)
            return
        const generation = root._lifecycleGeneration
        if (!presetScanProc.running) {
            presetScanProc.generation = generation
            presetScanProc.running = true
        }
        if (!activePresetProc.running) {
            activePresetProc.generation = generation
            activePresetProc.running = true
        }
        if (!bandRefreshProc.running) {
            bandRefreshProc.generation = generation
            bandRefreshProc.running = true
        }
    }

    function refresh() {
        if (!root.enabled)
            return
        EasyEffects.fetchAvailability()
        if (!root._transportChecked || !root._transportAvailable) {
            root._startTransportProbe()
            return
        }
        root._refreshBackendState()
    }

    function _canMutate() {
        if (!root.enabled) {
            root.error = "feature-disabled"
            return false
        }
        if (!root._transportAvailable) {
            root.error = "transport-unavailable"
            return false
        }
        if (!EasyEffects.available) {
            root.error = "backend-unavailable"
            return false
        }
        if (!root.backendRunning) {
            root.error = "backend-not-running"
            return false
        }
        if (root._mutationBusy) {
            root.error = "backend-busy"
            return false
        }
        return true
    }

    function applyPreset(name) {
        const preset = String(name ?? "").trim()
        if (!root._canMutate())
            return false
        if (preset.length === 0 || preset.includes(":") || preset.includes("\n") || preset.includes("\r")) {
            root.error = "invalid-preset"
            return false
        }

        const generation = root._beginMutation()
        root._equalizerAvailable = false
        root._markBandsUnsynced()
        root._pendingPreset = preset
        root.error = ""
        applyPresetProc.generation = generation
        applyPresetProc.command = ["/usr/bin/env", "sh", "-c",
            "sock=\"${XDG_RUNTIME_DIR:-}/EasyEffectsServer\"; [ -n \"${XDG_RUNTIME_DIR:-}\" ] && [ -S \"$sock\" ] || exit 65; printf '%s\\n' \"$1\" | socat -T 2 - UNIX-CONNECT:\"$sock\" >/dev/null",
            "sh", "load_preset:output:" + preset]
        applyPresetProc.running = true
        return true
    }

    function setBandGain(index, gain) {
        const bandIndex = Number(index)
        const requestedGain = Number(gain)
        if (!root._canMutate())
            return false
        if (!isFinite(bandIndex) || Math.floor(bandIndex) !== bandIndex
                || !isFinite(requestedGain) || bandIndex < 0 || bandIndex >= root.bands.length
                || root.bands[bandIndex]?.synced !== true) {
            root.error = "invalid-band"
            return false
        }

        const clampedGain = Math.max(root.minimumBandGain, Math.min(root.maximumBandGain, requestedGain))
        const generation = root._beginMutation()
        root._pendingBandIndex = bandIndex
        root._pendingBandGain = clampedGain
        root.error = ""
        setBandProc.generation = generation
        setBandProc.command = ["/usr/bin/env", "sh", "-c",
            "sock=\"${XDG_RUNTIME_DIR:-}/EasyEffectsServer\"; [ -n \"${XDG_RUNTIME_DIR:-}\" ] && [ -S \"$sock\" ] || exit 65; for side in left right; do printf 'set_property:output:equalizer:0:%s:band%sGain:%s\\n' \"$side\" \"$1\" \"$2\" | socat -T 2 - UNIX-CONNECT:\"$sock\" >/dev/null || exit $?; done",
            "sh", String(bandIndex), String(clampedGain)]
        setBandProc.running = true
        return true
    }

    function reset() {
        if (!root._canMutate())
            return false
        const generation = root._beginMutation()
        root._equalizerAvailable = false
        root._markBandsUnsynced()
        root.error = ""
        resetProc.generation = generation
        resetProc.running = true
        return true
    }

    onEnabledChanged: {
        root._lifecycleGeneration++
        if (root.enabled) {
            root.refresh()
        } else {
            root._cancelProcesses()
            root.error = ""
            root.activePreset = ""
            root.presets = []
            root._transportChecked = false
            root._transportAvailable = false
            root._equalizerAvailable = false
            root.bands = []
        }
    }

    Connections {
        target: root.enabled ? EasyEffects : null

        function onAvailableChanged() {
            root._lifecycleGeneration++
            root._cancelBackendProcesses()
            if (!EasyEffects.available) {
                root._equalizerAvailable = false
                root.activePreset = ""
                root.bands = []
                root.error = "backend-unavailable"
                return
            }
            if (root._transportChecked)
                root._refreshBackendState()
        }

        function onActiveChanged() {
            root._lifecycleGeneration++
            root._cancelBackendProcesses()
            if (!root.enabled)
                return
            if (!EasyEffects.active) {
                root._equalizerAvailable = false
                root.activePreset = ""
                root._markBandsUnsynced()
                if (root.backendAvailable)
                    root.error = "backend-not-running"
                return
            }
            root._equalizerAvailable = false
            backendRefreshTimer.restart()
        }
    }

    Timer {
        id: backendRefreshTimer
        interval: 300
        repeat: false
        onTriggered: root._refreshBackendState()
    }

    Process {
        id: transportProbe
        property bool startObserved: false
        property int generation: 0
        command: ["/usr/bin/env", "sh", "-c", "command -v socat >/dev/null 2>&1"]
        onRunningChanged: {
            if (running) {
                startObserved = false
                return
            }
            if (startObserved)
                return
            if (generation !== root._lifecycleGeneration) {
                root._retryStaleTransportProbe(generation)
                return
            }
            root._transportChecked = true
            root._transportAvailable = false
            root._equalizerAvailable = false
            root._setProcessError("transport-probe-failed", generation)
        }
        onStarted: startObserved = true
        onExited: (exitCode, exitStatus) => {
            if (!root.enabled)
                return
            if (generation !== root._lifecycleGeneration) {
                root._retryStaleTransportProbe(generation)
                return
            }
            root._transportChecked = true
            root._transportAvailable = (exitCode === 0)
            if (!root._transportAvailable) {
                root._equalizerAvailable = false
                root.error = "transport-unavailable"
                return
            }
            root._refreshBackendState()
        }
    }

    Process {
        id: presetScanProc
        property bool startObserved: false
        property int generation: 0
        command: ["/usr/bin/env", "sh", "-c",
            "for d in \"${XDG_DATA_HOME:-$HOME/.local/share}/easyeffects/output\" \"$HOME/.config/easyeffects/output\" \"$HOME/.var/app/com.github.wwmm.easyeffects/data/easyeffects/output\" \"$HOME/.var/app/com.github.wwmm.easyeffects/config/easyeffects/output\"; do [ -d \"$d\" ] || continue; for f in \"$d\"/*.json \"$d\"/*/*.json; do [ -f \"$f\" ] || continue; n=\"${f##*/}\"; n=\"${n%.json}\"; printf '%s\\n' \"$n\"; done; done | sort -u"]
        stdout: StdioCollector { id: presetCollector }
        onRunningChanged: {
            if (running) {
                startObserved = false
                return
            }
            if (startObserved)
                return
            root._setProcessError("preset-scan-failed", generation)
        }
        onStarted: startObserved = true
        onExited: (exitCode, exitStatus) => {
            if (!root.enabled || generation !== root._lifecycleGeneration)
                return
            if (exitCode !== 0) {
                root.error = "preset-scan-failed"
                return
            }
            const seen = []
            const next = []
            for (const line of (presetCollector.text ?? "").split("\n")) {
                const name = line.trim()
                if (name.length === 0 || seen.includes(name))
                    continue
                seen.push(name)
                next.push(name)
            }
            root.presets = next
            if (root.error === "preset-scan-failed")
                root.error = ""
        }
    }

    Process {
        id: activePresetProc
        property bool startObserved: false
        property int generation: 0
        command: ["/usr/bin/env", "sh", "-c",
            "sock=\"${XDG_RUNTIME_DIR:-}/EasyEffectsServer\"; [ -n \"${XDG_RUNTIME_DIR:-}\" ] && [ -S \"$sock\" ] || exit 65; printf 'get_last_loaded_preset:output\\n' | socat -T 2 - UNIX-CONNECT:\"$sock\""]
        stdout: StdioCollector { id: activePresetCollector }
        onRunningChanged: {
            if (running) {
                startObserved = false
                return
            }
            if (startObserved)
                return
            root._setProcessError("preset-query-failed", generation)
        }
        onStarted: startObserved = true
        onExited: (exitCode, exitStatus) => {
            if (!root.enabled || generation !== root._lifecycleGeneration)
                return
            if (exitCode !== 0) {
                root.activePreset = ""
                root.error = root._errorForExit(exitCode, "preset-query-failed")
                return
            }
            if (!root.backendRunning) {
                root.activePreset = ""
                root.error = "backend-not-running"
                return
            }
            root.activePreset = (activePresetCollector.text ?? "").trim()
            if (root.error === "preset-query-failed")
                root.error = ""
        }
    }

    Process {
        id: bandRefreshProc
        property bool startObserved: false
        property int generation: 0
        command: ["/usr/bin/env", "sh", "-c",
            "sock=\"${XDG_RUNTIME_DIR:-}/EasyEffectsServer\"; [ -n \"${XDG_RUNTIME_DIR:-}\" ] && [ -S \"$sock\" ] || exit 65; count=\"$(printf 'get_property:output:equalizer:0:numBands\\n' | socat -T 2 - UNIX-CONNECT:\"$sock\")\" || exit $?; case \"$count\" in ''|*[!0-9]*) exit 66;; esac; [ \"$count\" -ge 1 ] && [ \"$count\" -le 32 ] || exit 66; printf 'count=%s\\n' \"$count\"; i=0; while [ \"$i\" -lt \"$count\" ]; do lg=\"$(printf 'get_property:output:equalizer:0:left:band%sGain\\n' \"$i\" | socat -T 2 - UNIX-CONNECT:\"$sock\")\" || exit $?; rg=\"$(printf 'get_property:output:equalizer:0:right:band%sGain\\n' \"$i\" | socat -T 2 - UNIX-CONNECT:\"$sock\")\" || exit $?; lf=\"$(printf 'get_property:output:equalizer:0:left:band%sFrequency\\n' \"$i\" | socat -T 2 - UNIX-CONNECT:\"$sock\")\" || exit $?; rf=\"$(printf 'get_property:output:equalizer:0:right:band%sFrequency\\n' \"$i\" | socat -T 2 - UNIX-CONNECT:\"$sock\")\" || exit $?; printf '%s=%s|%s|%s|%s\\n' \"$i\" \"$lg\" \"$rg\" \"$lf\" \"$rf\"; i=$((i + 1)); done"]
        stdout: StdioCollector { id: bandCollector }
        onRunningChanged: {
            if (running) {
                startObserved = false
                return
            }
            if (startObserved)
                return
            if (generation !== root._lifecycleGeneration)
                return
            root._equalizerAvailable = false
            root._markBandsUnsynced()
            root._setProcessError("band-query-failed", generation)
        }
        onStarted: startObserved = true
        onExited: (exitCode, exitStatus) => {
            if (!root.enabled || generation !== root._lifecycleGeneration)
                return
            if (exitCode !== 0) {
                root._equalizerAvailable = false
                root._markBandsUnsynced()
                root.error = exitCode === 66 ? "malformed-band-response"
                    : root._errorForExit(exitCode, "equalizer-unavailable")
                return
            }
            if (!root.backendRunning) {
                root._equalizerAvailable = false
                root._markBandsUnsynced()
                root.error = "backend-not-running"
                return
            }

            let count = -1
            const rows = []
            for (const rawLine of (bandCollector.text ?? "").split("\n")) {
                const line = rawLine.trim()
                if (line.startsWith("count=")) {
                    const parsedCount = Number(line.slice(6))
                    if (isFinite(parsedCount) && parsedCount >= 1 && parsedCount <= 32
                            && Math.floor(parsedCount) === parsedCount)
                        count = parsedCount
                    continue
                }
                const separator = line.indexOf("=")
                if (separator <= 0)
                    continue
                const index = Number(line.slice(0, separator))
                const values = line.slice(separator + 1).split("|")
                if (values.length !== 4 || !isFinite(index) || Math.floor(index) !== index)
                    continue
                if (values.some(value => value.trim().length === 0))
                    continue
                const leftGain = Number(values[0])
                const rightGain = Number(values[1])
                const leftFrequency = Number(values[2])
                const rightFrequency = Number(values[3])
                if (!isFinite(leftGain) || !isFinite(rightGain)
                        || !isFinite(leftFrequency) || !isFinite(rightFrequency))
                    continue
                rows.push({
                    index: index,
                    frequency: leftFrequency,
                    rightFrequency: rightFrequency,
                    gain: leftGain,
                    rightGain: rightGain,
                    linked: Math.abs(leftGain - rightGain) < 0.001
                        && Math.abs(leftFrequency - rightFrequency) < 0.001,
                    synced: true
                })
            }

            if (count < 1 || rows.length !== count) {
                root._equalizerAvailable = false
                root._markBandsUnsynced()
                root.error = "malformed-band-response"
                return
            }
            rows.sort((a, b) => a.index - b.index)
            for (let i = 0; i < rows.length; ++i) {
                if (rows[i].index !== i) {
                    root._equalizerAvailable = false
                    root._markBandsUnsynced()
                    root.error = "malformed-band-response"
                    return
                }
            }
            root.bands = rows
            root._equalizerAvailable = true
            root._clearRecoveredBackendError()
        }
    }

    Process {
        id: applyPresetProc
        property bool startObserved: false
        property int generation: 0
        onRunningChanged: {
            if (running) {
                startObserved = false
                return
            }
            if (startObserved)
                return
            root._pendingPreset = ""
            root._setProcessError("preset-apply-failed", generation)
            if (root.enabled && generation === root._lifecycleGeneration)
                root._scheduleReconcile()
        }
        onStarted: startObserved = true
        onExited: (exitCode, exitStatus) => {
            if (!root.enabled || generation !== root._lifecycleGeneration)
                return
            const preset = root._pendingPreset
            root._pendingPreset = ""
            if (exitCode !== 0) {
                root.error = root._errorForExit(exitCode, "preset-apply-failed")
                root._scheduleReconcile()
                return
            }
            if (!root.backendRunning) {
                root.error = "backend-not-running"
                return
            }
            root.activePreset = preset
            root.error = ""
            root._scheduleReconcile()
        }
    }

    Process {
        id: setBandProc
        property bool startObserved: false
        property int generation: 0
        onRunningChanged: {
            if (running) {
                startObserved = false
                return
            }
            if (startObserved)
                return
            root._pendingBandIndex = -1
            root._setProcessError("band-apply-failed", generation)
        }
        onStarted: startObserved = true
        onExited: (exitCode, exitStatus) => {
            if (!root.enabled || generation !== root._lifecycleGeneration)
                return
            const index = root._pendingBandIndex
            const gain = root._pendingBandGain
            root._pendingBandIndex = -1
            if (exitCode !== 0) {
                root._equalizerAvailable = false
                root._markBandsUnsynced()
                root.error = root._errorForExit(exitCode, "band-apply-failed")
                root._scheduleReconcile()
                return
            }
            if (!root.backendRunning) {
                root._equalizerAvailable = false
                root.error = "backend-not-running"
                return
            }
            root._equalizerAvailable = true
            if (index >= 0 && index < root.bands.length) {
                root.bands = root.bands.map((band, bandIndex) => bandIndex === index
                    ? Object.assign({}, band, {
                        gain: gain,
                        rightGain: gain,
                        linked: Math.abs((band.frequency ?? 0) - (band.rightFrequency ?? 0)) < 0.001,
                        synced: true
                    }) : band)
            }
            root.error = ""
        }
    }

    Process {
        id: resetProc
        property bool startObserved: false
        property int generation: 0
        command: ["/usr/bin/env", "sh", "-c",
            "sock=\"${XDG_RUNTIME_DIR:-}/EasyEffectsServer\"; [ -n \"${XDG_RUNTIME_DIR:-}\" ] && [ -S \"$sock\" ] || exit 65; count=\"$(printf 'get_property:output:equalizer:0:numBands\\n' | socat -T 2 - UNIX-CONNECT:\"$sock\")\" || exit $?; case \"$count\" in ''|*[!0-9]*) exit 66;; esac; [ \"$count\" -ge 1 ] && [ \"$count\" -le 32 ] || exit 66; i=0; while [ \"$i\" -lt \"$count\" ]; do for side in left right; do printf 'set_property:output:equalizer:0:%s:band%sGain:0\\n' \"$side\" \"$i\" | socat -T 2 - UNIX-CONNECT:\"$sock\" >/dev/null || exit $?; done; i=$((i + 1)); done"]
        onRunningChanged: {
            if (running) {
                startObserved = false
                return
            }
            if (startObserved)
                return
            root._setProcessError("reset-failed", generation)
            if (root.enabled && generation === root._lifecycleGeneration)
                root._scheduleReconcile()
        }
        onStarted: startObserved = true
        onExited: (exitCode, exitStatus) => {
            if (!root.enabled || generation !== root._lifecycleGeneration)
                return
            if (exitCode !== 0) {
                root._equalizerAvailable = false
                root.error = exitCode === 66 ? "malformed-band-response"
                    : root._errorForExit(exitCode, "reset-failed")
                root._scheduleReconcile()
                return
            }
            if (!root.backendRunning) {
                root._equalizerAvailable = false
                root.error = "backend-not-running"
                return
            }
            root._equalizerAvailable = true
            root.bands = root.bands.map(band => Object.assign({}, band, {
                gain: 0,
                rightGain: 0,
                synced: true
            }))
            root.error = ""
            root._scheduleReconcile()
        }
    }
}
