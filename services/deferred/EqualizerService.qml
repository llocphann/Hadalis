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
    readonly property bool available: root.backendAvailable && root.backendRunning

    property string error: ""
    property list<string> presets: []
    property string activePreset: ""

    readonly property var _frequencies: [31, 63, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
    property var bands: root._defaultBands(false)

    property bool _transportChecked: false
    property bool _transportAvailable: false
    property string _pendingPreset: ""
    property int _pendingBandIndex: -1
    property real _pendingBandGain: 0
    property int _lifecycleGeneration: 0
    readonly property bool _mutationBusy: applyPresetProc.running || setBandProc.running || resetProc.running

    function _defaultBands(synced) {
        return root._frequencies.map((frequency, index) => ({
            index: index,
            frequency: frequency,
            gain: 0,
            synced: synced === true
        }))
    }

    function _markBandsUnsynced() {
        root.bands = root.bands.map(band => Object.assign({}, band, { synced: false }))
    }

    function _cancelProcesses() {
        backendRefreshTimer.stop()
        transportProbe.running = false
        presetScanProc.running = false
        activePresetProc.running = false
        bandRefreshProc.running = false
        applyPresetProc.running = false
        setBandProc.running = false
        resetProc.running = false
        root._pendingPreset = ""
        root._pendingBandIndex = -1
    }

    function _setProcessError(message, generation) {
        if (!root.enabled || generation !== root._lifecycleGeneration)
            return
        root.error = message
    }

    function _startTransportProbe() {
        if (transportProbe.running)
            return
        transportProbe.generation = root._lifecycleGeneration
        transportProbe.running = true
    }

    function _refreshBackendState() {
        if (!root.enabled)
            return
        if (!root._transportChecked) {
            root._startTransportProbe()
            return
        }
        if (!root._transportAvailable) {
            root.error = "transport-unavailable"
            return
        }
        if (!EasyEffects.available) {
            root.error = "backend-unavailable"
            return
        }

        EasyEffects.fetchActiveState()
        if (!EasyEffects.active) {
            root.activePreset = ""
            root._markBandsUnsynced()
            root.error = "backend-not-running"
            return
        }

        root.error = ""
        root._refreshData()
    }

    function _refreshData() {
        if (!root.available || root._mutationBusy)
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
        if (!root._transportChecked) {
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
        if (!root.backendAvailable) {
            root.error = root._transportAvailable ? "backend-unavailable" : "transport-unavailable"
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

        root._pendingPreset = preset
        root.error = ""
        applyPresetProc.generation = root._lifecycleGeneration
        applyPresetProc.command = ["/usr/bin/env", "sh", "-c",
            "sock=\"${XDG_RUNTIME_DIR:-}/EasyEffectsServer\"; [ -n \"${XDG_RUNTIME_DIR:-}\" ] && [ -S \"$sock\" ] || exit 65; printf '%s\\n' \"$1\" | socat -T 2 - UNIX-CONNECT:\"$sock\" >/dev/null",
            "sh", "load_preset:output:" + preset]
        applyPresetProc.running = true
        return true
    }

    function setBandGain(index, gain) {
        const bandIndex = Math.round(Number(index))
        const requestedGain = Number(gain)
        if (!root._canMutate())
            return false
        if (!isFinite(requestedGain) || bandIndex < 0 || bandIndex >= root._frequencies.length) {
            root.error = "invalid-band"
            return false
        }

        const clampedGain = Math.max(-24, Math.min(24, requestedGain))
        root._pendingBandIndex = bandIndex
        root._pendingBandGain = clampedGain
        root.error = ""
        setBandProc.generation = root._lifecycleGeneration
        setBandProc.command = ["/usr/bin/env", "sh", "-c",
            "sock=\"${XDG_RUNTIME_DIR:-}/EasyEffectsServer\"; [ -n \"${XDG_RUNTIME_DIR:-}\" ] && [ -S \"$sock\" ] || exit 65; for side in left right; do printf 'set_property:output:equalizer:0:%s:band%sGain:%s\\n' \"$side\" \"$1\" \"$2\" | socat -T 2 - UNIX-CONNECT:\"$sock\" >/dev/null || exit $?; done",
            "sh", String(bandIndex), String(clampedGain)]
        setBandProc.running = true
        return true
    }

    function reset() {
        if (!root._canMutate())
            return false
        root.error = ""
        resetProc.generation = root._lifecycleGeneration
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
            root.bands = root._defaultBands(false)
        }
    }

    Connections {
        target: root.enabled ? EasyEffects : null

        function onAvailableChanged() {
            root._lifecycleGeneration++
            if (root._transportChecked)
                root._refreshBackendState()
        }

        function onActiveChanged() {
            root._lifecycleGeneration++
            if (!root.enabled)
                return
            if (!EasyEffects.active) {
                root.activePreset = ""
                root._markBandsUnsynced()
                if (root.backendAvailable)
                    root.error = "backend-not-running"
                return
            }
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
            if (generation !== root._lifecycleGeneration)
                return
            root._transportChecked = true
            root._transportAvailable = false
            root._setProcessError("transport-probe-failed", generation)
        }
        onStarted: startObserved = true
        onExited: (exitCode, exitStatus) => {
            if (!root.enabled || generation !== root._lifecycleGeneration)
                return
            root._transportChecked = true
            root._transportAvailable = (exitCode === 0)
            if (!root._transportAvailable) {
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
                root.error = exitCode === 65 ? "backend-not-running" : "preset-query-failed"
                return
            }
            if (!root.backendRunning) {
                root.activePreset = ""
                root.error = "backend-not-running"
                return
            }
            root.activePreset = (activePresetCollector.text ?? "").trim()
        }
    }

    Process {
        id: bandRefreshProc
        property bool startObserved: false
        property int generation: 0
        command: ["/usr/bin/env", "sh", "-c",
            "sock=\"${XDG_RUNTIME_DIR:-}/EasyEffectsServer\"; [ -n \"${XDG_RUNTIME_DIR:-}\" ] && [ -S \"$sock\" ] || exit 65; i=0; while [ \"$i\" -lt 10 ]; do value=\"$(printf 'get_property:output:equalizer:0:left:band%sGain\\n' \"$i\" | socat -T 2 - UNIX-CONNECT:\"$sock\")\" || exit $?; printf '%s=%s\\n' \"$i\" \"$value\"; i=$((i + 1)); done"]
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
            root._markBandsUnsynced()
            root._setProcessError("band-query-failed", generation)
        }
        onStarted: startObserved = true
        onExited: (exitCode, exitStatus) => {
            if (!root.enabled || generation !== root._lifecycleGeneration)
                return
            if (exitCode !== 0) {
                root._markBandsUnsynced()
                root.error = exitCode === 65 ? "backend-not-running" : "band-query-failed"
                return
            }
            if (!root.backendRunning) {
                root._markBandsUnsynced()
                root.error = "backend-not-running"
                return
            }

            const next = root._defaultBands(false)
            const seenIndexes = []
            let valid = 0
            for (const line of (bandCollector.text ?? "").split("\n")) {
                const match = line.trim().match(/^(\d+)=(.+)$/)
                if (!match)
                    continue
                const index = Number(match[1])
                const gain = Number(match[2])
                if (!isFinite(gain) || index < 0 || index >= next.length || seenIndexes.includes(index))
                    continue
                seenIndexes.push(index)
                next[index] = Object.assign({}, next[index], { gain: gain, synced: true })
                valid++
            }
            root.bands = next
            if (valid !== root._frequencies.length)
                root.error = "malformed-band-response"
            else if (root.error === "band-query-failed" || root.error === "malformed-band-response")
                root.error = ""
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
        }
        onStarted: startObserved = true
        onExited: (exitCode, exitStatus) => {
            if (!root.enabled || generation !== root._lifecycleGeneration)
                return
            const preset = root._pendingPreset
            root._pendingPreset = ""
            if (exitCode !== 0) {
                root.error = exitCode === 65 ? "backend-not-running" : "preset-apply-failed"
                return
            }
            if (!root.backendRunning) {
                root.error = "backend-not-running"
                return
            }
            root.activePreset = preset
            root.error = ""
            backendRefreshTimer.restart()
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
                root.error = exitCode === 65 ? "backend-not-running" : "band-apply-failed"
                return
            }
            if (!root.backendRunning) {
                root.error = "backend-not-running"
                return
            }
            if (index >= 0 && index < root.bands.length) {
                root.bands = root.bands.map((band, bandIndex) => bandIndex === index
                    ? Object.assign({}, band, { gain: gain, synced: true }) : band)
            }
            root.error = ""
        }
    }

    Process {
        id: resetProc
        property bool startObserved: false
        property int generation: 0
        command: ["/usr/bin/env", "sh", "-c",
            "sock=\"${XDG_RUNTIME_DIR:-}/EasyEffectsServer\"; [ -n \"${XDG_RUNTIME_DIR:-}\" ] && [ -S \"$sock\" ] || exit 65; i=0; while [ \"$i\" -lt 10 ]; do for side in left right; do printf 'set_property:output:equalizer:0:%s:band%sGain:0\\n' \"$side\" \"$i\" | socat -T 2 - UNIX-CONNECT:\"$sock\" >/dev/null || exit $?; done; i=$((i + 1)); done"]
        onRunningChanged: {
            if (running) {
                startObserved = false
                return
            }
            if (startObserved)
                return
            root._setProcessError("reset-failed", generation)
        }
        onStarted: startObserved = true
        onExited: (exitCode, exitStatus) => {
            if (!root.enabled || generation !== root._lifecycleGeneration)
                return
            if (exitCode !== 0) {
                root.error = exitCode === 65 ? "backend-not-running" : "reset-failed"
                return
            }
            if (!root.backendRunning) {
                root.error = "backend-not-running"
                return
            }
            root.bands = root._defaultBands(true)
            root.error = ""
        }
    }
}
