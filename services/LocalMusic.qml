pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

Singleton {
    id: root

    readonly property bool enabled: Config.options?.sidebar?.music?.enable ?? false
    readonly property string configuredLibraryFolder:
        Config.options?.sidebar?.music?.libraryFolder ?? ""
    readonly property string configuredHost:
        Config.options?.sidebar?.music?.mpdHost ?? ""
    readonly property int configuredPort:
        Number(Config.options?.sidebar?.music?.mpdPort ?? 6600)
    readonly property string mpdHost: configuredHost.length > 0
        ? configuredHost
        : ((Quickshell.env("MPD_HOST") ?? "").length > 0
            ? Quickshell.env("MPD_HOST") : "127.0.0.1")
    readonly property int mpdPort: {
        const envPort = Number(Quickshell.env("MPD_PORT") ?? 0)
        if (configuredPort > 0) return configuredPort
        return envPort > 0 ? envPort : 6600
    }

    property string detectedLibraryFolder: ""
    readonly property string defaultLibraryFolder:
        FileUtils.trimFileProtocol(Directories.music)
    readonly property string libraryFolder: configuredLibraryFolder.length > 0
        ? configuredLibraryFolder
        : (detectedLibraryFolder.length > 0
            ? detectedLibraryFolder : defaultLibraryFolder)

    readonly property var mprisPlayer: MprisController.mpdPlayer
    readonly property bool mprisAvailable: mprisPlayer !== null
    property bool mpdConnected: false
    readonly property bool available: mpdConnected

    property bool scanning: false
    property string error: ""
    property string mpdState: "stop"

    property var libraryTracks: []
    property var playlists: []
    property var folderCollections: []
    readonly property var collections: [...playlists, ...folderCollections]

    property var activeQueue: []
    property string activeQueueName: ""
    property int currentIndex: -1
    property string currentPath: ""
    property string currentUri: ""
    property string currentTitle: ""
    property string currentArtist: ""
    property string currentAlbum: ""
    property string currentArt: ""
    property real currentDuration: 0
    property real currentPosition: 0
    property real volume: 1
    property bool shuffleMode: false
    property int repeatMode: 0

    readonly property bool playing: mprisAvailable
        ? (mprisPlayer?.isPlaying ?? false)
        : mpdState === "play"
    readonly property bool paused: !playing
    readonly property bool hasQueue: activeQueue.length > 0
    readonly property bool hasCurrentTrack:
        currentIndex >= 0 && currentIndex < activeQueue.length
    readonly property bool canGoPrevious:
        hasCurrentTrack && (currentIndex > 0 || repeatMode === 2 || currentPosition > 3)
    readonly property bool canGoNext:
        hasCurrentTrack && (currentIndex < activeQueue.length - 1 || repeatMode === 2)

    readonly property string _mpdScript: Directories.scriptsPath + "/local_music_mpd.py"

    function _trackForIdentity(uri: string, path: string): var {
        const wantedUri = String(uri ?? "")
        const wantedPath = String(path ?? "")
        for (const track of activeQueue) {
            if ((wantedUri && String(track?.uri ?? "") === wantedUri)
                    || (wantedPath && String(track?.path ?? "") === wantedPath))
                return track
        }
        for (const track of libraryTracks) {
            if ((wantedUri && String(track?.uri ?? "") === wantedUri)
                    || (wantedPath && String(track?.path ?? "") === wantedPath))
                return track
        }
        return null
    }

    function _applyCurrentTrack(track): void {
        if (!track) {
            currentTitle = currentPath.length > 0
                ? currentPath.substring(currentPath.lastIndexOf("/") + 1) : ""
            currentArtist = ""
            currentAlbum = ""
            currentArt = ""
            return
        }
        currentUri = String(track.uri ?? "")
        currentPath = String(track.path ?? track.uri ?? "")
        currentTitle = String(track.title ?? "")
        currentArtist = String(track.artist ?? "")
        currentAlbum = String(track.album ?? "")
        currentArt = String(track.art ?? "")
        currentDuration = Math.max(0, Number(track.duration ?? currentDuration) || 0)
    }

    function _applyPayload(payload, includeLibrary = false): void {
        if (!payload || payload.connected === false) {
            mpdConnected = false
            if (payload?.error) error = String(payload.error)
            return
        }

        mpdConnected = true
        error = ""
        MprisController.ensureMpdMprisBridge(mpdHost, mpdPort)
        if (String(payload.musicRoot ?? "").length > 0)
            detectedLibraryFolder = String(payload.musicRoot)

        if (includeLibrary) {
            libraryTracks = payload.tracks ?? []
            playlists = payload.playlists ?? []
            folderCollections = payload.folders ?? []
        }

        if (Array.isArray(payload.queue))
            activeQueue = payload.queue

        const status = payload.status ?? {}
        mpdState = String(status.state ?? "stop")
        currentIndex = Number(status.song ?? -1)
        currentPosition = Math.max(0, Number(status.elapsed ?? 0) || 0)
        currentDuration = Math.max(0, Number(status.duration ?? 0) || 0)
        const mpdVolume = Number(status.volume)
        if (Number.isFinite(mpdVolume) && mpdVolume >= 0)
            volume = Math.max(0, Math.min(1, mpdVolume / 100))
        shuffleMode = String(status.random ?? "0") === "1"
        repeatMode = String(status.single ?? "0") === "1"
            ? 1
            : (String(status.repeat ?? "0") === "1" ? 2 : 0)

        const current = payload.current ?? (
            currentIndex >= 0 && currentIndex < activeQueue.length
                ? activeQueue[currentIndex] : null
        )
        if (current) {
            _applyCurrentTrack(current)
        } else {
            currentIndex = -1
            currentUri = ""
            currentPath = ""
            currentTitle = ""
            currentArtist = ""
            currentAlbum = ""
            currentArt = ""
            currentDuration = 0
            currentPosition = 0
        }
    }

    function setLibraryFolder(path: string): void {
        const normalized = FileUtils.trimFileProtocol(String(path ?? "")).trim()
        Config.setNestedValue("sidebar.music.libraryFolder", normalized)
        if (enabled) Qt.callLater(root.rescan)
    }

    function rescan(): void {
        if (!enabled || _scanProc.running) return
        scanning = true
        error = ""
        MprisController.ensureMpdMprisBridge(mpdHost, mpdPort)
        _scanProc.command = [
            "python3", _mpdScript, "snapshot",
            mpdHost, String(mpdPort), configuredLibraryFolder
        ]
        _scanProc.running = true
    }

    function refreshStatus(): void {
        if (!enabled || _statusProc.running || _scanProc.running) return
        _statusProc.command = [
            "python3", _mpdScript, "status",
            mpdHost, String(mpdPort), configuredLibraryFolder
        ]
        _statusProc.running = true
    }

    function updateDatabase(): void {
        _sendMpd("update", [])
        updateRescanTimer.restart()
    }

    function playLibrary(index: int): void {
        playQueue(libraryTracks, index, Translation.tr("Library"))
    }

    function playCollection(collection, index = 0): void {
        if (!collection) return
        playQueue(collection.tracks ?? [], index, String(collection.name ?? "Playlist"))
    }

    function playPath(path: string): void {
        const normalized = FileUtils.trimFileProtocol(String(path ?? "")).trim()
        if (normalized.length === 0) return
        const index = libraryTracks.findIndex(track =>
            String(track?.path ?? "") === normalized
                || String(track?.uri ?? "") === normalized)
        if (index < 0) {
            error = "not_in_mpd_library"
            return
        }
        playLibrary(index)
    }

    function playQueue(queue, index = 0, name = ""): void {
        if (!available || !Array.isArray(queue) || queue.length === 0) return
        const valid = queue.filter(track =>
            String(track?.uri ?? track?.path ?? "").length > 0)
        if (valid.length === 0) return

        index = Math.max(0, Math.min(valid.length - 1, Number(index) || 0))
        activeQueue = valid
        activeQueueName = String(name ?? "")
        currentIndex = index
        _applyCurrentTrack(valid[index])
        currentPosition = 0
        error = ""

        _queueProc.command = [
            "python3", _mpdScript, "queue",
            mpdHost, String(mpdPort), String(index),
            JSON.stringify(valid.map(track => String(track.uri ?? track.path)))
        ]
        _queueProc.running = true
    }

    function _sendMpd(command: string, args): void {
        Quickshell.execDetached([
            "python3", _mpdScript, "command",
            mpdHost, String(mpdPort), command,
            JSON.stringify(Array.isArray(args) ? args : [])
        ])
        statusRefreshTimer.restart()
    }

    function togglePlaying(): void {
        const player = mprisPlayer
        if (player && (player.canTogglePlaying ?? false)) {
            player.togglePlaying()
            statusRefreshTimer.restart()
            return
        }
        _sendMpd("pause", [playing ? 1 : 0])
    }

    function next(): void {
        const player = mprisPlayer
        if (player && MprisController.canGoNextForPlayer(player)) {
            MprisController.nextForPlayer(player, false)
            statusRefreshTimer.restart()
            return
        }
        _sendMpd("next", [])
    }

    function previous(): void {
        if (currentPosition > 3) {
            seek(0)
            return
        }
        const player = mprisPlayer
        if (player && MprisController.canGoPreviousForPlayer(player)) {
            MprisController.previousForPlayer(player, false)
            statusRefreshTimer.restart()
            return
        }
        _sendMpd("previous", [])
    }

    function jumpTo(index: int): void {
        if (index >= 0 && index < activeQueue.length)
            _sendMpd("play", [index])
    }

    function seek(seconds: real): void {
        const target = Math.max(0, Number(seconds) || 0)
        const player = mprisPlayer
        if (player && (player.canSeek ?? false)
                && (player.positionSupported ?? true)) {
            player.position = target
            statusRefreshTimer.restart()
            return
        }
        _sendMpd("seekcur", [target])
    }

    function setVolume(value: real): void {
        const clamped = Math.max(0, Math.min(1, Number(value) || 0))
        volume = clamped
        const player = mprisPlayer
        if (player && (player.volumeSupported ?? false) && (player.canControl ?? false)) {
            player.volume = clamped
            statusRefreshTimer.restart()
            return
        }
        _sendMpd("setvol", [Math.round(clamped * 100)])
    }

    function toggleShuffle(): void {
        const target = !shuffleMode
        shuffleMode = target
        const player = mprisPlayer
        if (player && (player.shuffleSupported ?? false) && (player.canControl ?? false)) {
            player.shuffle = target
            statusRefreshTimer.restart()
            return
        }
        _sendMpd("random", [target ? 1 : 0])
    }

    function cycleRepeatMode(): void {
        const target = (repeatMode + 1) % 3
        repeatMode = target
        // MPD expresses track repeat as repeat+single and queue repeat as repeat.
        _sendMpd("repeat", [target === 0 ? 0 : 1])
        _sendMpd("single", [target === 1 ? 1 : 0])
    }

    function stop(): void {
        const player = mprisPlayer
        if (player && (player.canStop ?? false)) {
            player.stop()
            statusRefreshTimer.restart()
            return
        }
        _sendMpd("stop", [])
    }

    Component.onCompleted: {
        if (enabled) {
            MprisController.ensureMpdMprisBridge(mpdHost, mpdPort)
            Qt.callLater(root.rescan)
        }
    }

    onEnabledChanged: {
        if (enabled) {
            MprisController.ensureMpdMprisBridge(mpdHost, mpdPort)
            Qt.callLater(root.rescan)
        }
    }

    onConfiguredLibraryFolderChanged: if (enabled) Qt.callLater(root.rescan)
    onConfiguredHostChanged: if (enabled) Qt.callLater(root.rescan)
    onConfiguredPortChanged: if (enabled) Qt.callLater(root.rescan)

    Timer {
        id: pollTimer
        interval: 900
        repeat: true
        running: root.enabled
        onTriggered: root.refreshStatus()
    }

    Timer {
        id: statusRefreshTimer
        interval: 180
        repeat: false
        onTriggered: root.refreshStatus()
    }

    Timer {
        id: updateRescanTimer
        interval: 2200
        repeat: false
        onTriggered: root.rescan()
    }

    Process {
        id: _scanProc
        property string output: ""
        stdout: StdioCollector {
            onStreamFinished: _scanProc.output = text ?? ""
        }
        onStarted: _scanProc.output = ""
        onExited: (code, _status) => {
            root.scanning = false
            if (code !== 0) {
                root.mpdConnected = false
                try {
                    const payload = JSON.parse(_scanProc.output || "{}")
                    root.error = String(payload.error ?? "mpd_unavailable")
                } catch (e) {
                    root.error = "mpd_unavailable"
                }
                return
            }
            try {
                root._applyPayload(JSON.parse(_scanProc.output || "{}"), true)
            } catch (e) {
                root.error = "mpd_snapshot_parse_failed"
            }
        }
    }

    Process {
        id: _statusProc
        property string output: ""
        stdout: StdioCollector {
            onStreamFinished: _statusProc.output = text ?? ""
        }
        onStarted: _statusProc.output = ""
        onExited: (code, _status) => {
            if (code !== 0) {
                root.mpdConnected = false
                return
            }
            try {
                root._applyPayload(JSON.parse(_statusProc.output || "{}"), false)
            } catch (e) {
                root.error = "mpd_status_parse_failed"
            }
        }
    }

    Process {
        id: _queueProc
        property string output: ""
        stdout: StdioCollector {
            onStreamFinished: _queueProc.output = text ?? ""
        }
        onStarted: _queueProc.output = ""
        onExited: (code, _status) => {
            if (code !== 0) {
                root.error = "mpd_queue_failed"
                return
            }
            statusRefreshTimer.restart()
        }
    }
}
