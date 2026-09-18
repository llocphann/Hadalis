pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

Singleton {
    id: root

    readonly property bool enabled: Config.options?.sidebar?.music?.enable ?? false
    readonly property string configuredLibraryFolder: Config.options?.sidebar?.music?.libraryFolder ?? ""
    readonly property string defaultLibraryFolder: FileUtils.trimFileProtocol(Directories.music)
    readonly property string libraryFolder: configuredLibraryFolder.length > 0
        ? configuredLibraryFolder : defaultLibraryFolder
    readonly property bool normalizeVolume: Config.options?.sidebar?.music?.normalizeVolume ?? false

    property bool available: false
    property string mpvPath: ""
    property bool scanning: false
    property bool playing: false
    property bool paused: true
    property string error: ""

    property var libraryTracks: []
    property var playlists: []
    property var folderCollections: []
    readonly property var collections: [...playlists, ...folderCollections]

    property var activeQueue: []
    property string activeQueueName: ""
    property int currentIndex: -1
    property string currentPath: ""
    property string currentTitle: ""
    property string currentArtist: ""
    property string currentAlbum: ""
    property string currentArt: ""
    property real currentDuration: 0
    property real currentPosition: 0
    property real volume: Math.max(0, Math.min(1,
        Number(Config.options?.sidebar?.music?.volume ?? 100) / 100))
    property bool shuffleMode: Config.options?.sidebar?.music?.shuffleMode ?? false
    property int repeatMode: Config.options?.sidebar?.music?.repeatMode ?? 0
    property var _pendingPlayCommand: []

    readonly property bool hasQueue: activeQueue.length > 0
    readonly property bool hasCurrentTrack: currentIndex >= 0 && currentIndex < activeQueue.length
    readonly property bool canGoPrevious: hasCurrentTrack
        && (currentIndex > 0 || repeatMode === 2 || currentPosition > 3)
    readonly property bool canGoNext: hasCurrentTrack
        && (currentIndex < activeQueue.length - 1 || repeatMode === 2)

    readonly property string _runtimeDir: {
        const value = Quickshell.env("XDG_RUNTIME_DIR")
        return value && value.length > 0 ? value : "/tmp"
    }
    readonly property string ipcSocket:
        _runtimeDir + "/hadalis-local-music-" + Quickshell.processId + ".sock"
    readonly property string _scanScript: Directories.scriptsPath + "/local_music_scan.py"
    readonly property string _ipcScript: Directories.scriptsPath + "/local_music_ipc.py"

    function _trackForPath(path: string): var {
        const normalized = String(path ?? "")
        for (const track of activeQueue) {
            if (String(track?.path ?? "") === normalized) return track
        }
        for (const track of libraryTracks) {
            if (String(track?.path ?? "") === normalized) return track
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
        currentTitle = String(track.title ?? "")
        currentArtist = String(track.artist ?? "")
        currentAlbum = String(track.album ?? "")
        currentArt = String(track.art ?? "")
    }

    function _syncQueueFromMpv(playlist): void {
        if (!Array.isArray(playlist) || playlist.length === 0) return
        const ordered = []
        for (const entry of playlist) {
            const path = String(entry?.filename ?? "")
            const track = _trackForPath(path)
            ordered.push(track ?? {
                path: path,
                title: path.substring(path.lastIndexOf("/") + 1),
                artist: "", album: "", art: "", duration: 0
            })
        }
        activeQueue = ordered
    }

    function _handleStatus(line: string): void {
        let payload
        try { payload = JSON.parse(line) } catch (e) { return }
        if (payload?.unavailable) return

        paused = payload.pause ?? paused
        playing = _playProc.running && !paused
        currentPosition = Math.max(0, Number(payload["time-pos"] ?? currentPosition) || 0)
        currentDuration = Math.max(0, Number(payload.duration ?? currentDuration) || 0)
        const mpvVolume = Number(payload.volume)
        if (Number.isFinite(mpvVolume))
            volume = Math.max(0, Math.min(1, mpvVolume / 100))

        const path = String(payload.path ?? "")
        if (path.length > 0) currentPath = path
        if (Array.isArray(payload.playlist)) _syncQueueFromMpv(payload.playlist)

        let idx = currentPath.length > 0
            ? activeQueue.findIndex(track => String(track?.path ?? "") === currentPath) : -1
        if (idx < 0) idx = Number(payload["playlist-pos"] ?? -1)
        if (idx >= 0 && idx < activeQueue.length) {
            currentIndex = idx
            _applyCurrentTrack(activeQueue[idx])
        } else if (currentPath.length > 0) {
            _applyCurrentTrack(_trackForPath(currentPath))
        }
    }

    function setLibraryFolder(path: string): void {
        const normalized = FileUtils.trimFileProtocol(String(path ?? "")).trim()
        if (normalized.length === 0) return
        Config.setNestedValue("sidebar.music.libraryFolder", normalized)
        Qt.callLater(root.rescan)
    }

    function rescan(): void {
        if (!enabled || _scanProc.running) return
        scanning = true
        error = ""
        _scanProc.command = ["python3", _scanScript, libraryFolder]
        _scanProc.running = true
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
        const known = libraryTracks.find(track => String(track?.path ?? "") === normalized)
        const item = known ?? {
            path: normalized,
            title: normalized.substring(normalized.lastIndexOf("/") + 1),
            artist: "", album: "", art: "", duration: 0
        }
        playQueue([item], 0, Translation.tr("Queue"))
    }

    function playQueue(queue, index = 0, name = ""): void {
        if (!available || !Array.isArray(queue) || queue.length === 0) return
        const valid = queue.filter(track => String(track?.path ?? "").length > 0)
        if (valid.length === 0) return

        index = Math.max(0, Math.min(valid.length - 1, Number(index) || 0))
        activeQueue = valid
        activeQueueName = String(name ?? "")
        currentIndex = index
        currentPath = String(valid[index].path)
        _applyCurrentTrack(valid[index])
        currentPosition = 0
        currentDuration = Number(valid[index].duration ?? 0) || 0
        paused = false
        error = ""

        const args = [
            mpvPath,
            "--no-video", "--force-window=no", "--audio-display=no",
            "--input-ipc-server=" + ipcSocket,
            "--volume=" + Math.round(volume * 100), "--volume-max=100",
            "--gapless-audio=weak", "--playlist-start=" + index,
            ...(normalizeVolume ? ["--af=loudnorm=I=-14:TP=-1.5:LRA=11"] : []),
            ...(repeatMode === 1 ? ["--loop-file=inf"] : []),
            ...(repeatMode === 2 ? ["--loop-playlist=inf"] : []),
            ...(shuffleMode ? ["--shuffle"] : []),
            ...valid.map(track => String(track.path))
        ]
        _pendingPlayCommand = args
        if (_playProc.running) _playProc.running = false
        else _launchPending()
    }

    function _launchPending(): void {
        if (!Array.isArray(_pendingPlayCommand) || _pendingPlayCommand.length === 0) return
        const command = _pendingPlayCommand
        _pendingPlayCommand = []
        Quickshell.execDetached(["/usr/bin/rm", "-f", ipcSocket])
        _playProc.command = command
        _playProc.running = true
    }

    function _send(command): void {
        if (!_playProc.running) return
        Quickshell.execDetached([
            "python3", _ipcScript, "command", ipcSocket, JSON.stringify(command)
        ])
    }

    function togglePlaying(): void { _send(["cycle", "pause"]) }
    function next(): void { _send(["playlist-next", "force"]) }
    function previous(): void {
        if (currentPosition > 3) seek(0)
        else _send(["playlist-prev", "force"])
    }
    function jumpTo(index: int): void {
        if (index >= 0 && index < activeQueue.length)
            _send(["set_property", "playlist-pos", index])
    }
    function seek(seconds: real): void {
        _send(["seek", Math.max(0, Number(seconds) || 0), "absolute"])
    }
    function setVolume(value: real): void {
        const clamped = Math.max(0, Math.min(1, Number(value) || 0))
        volume = clamped
        Config.setNestedValue("sidebar.music.volume", Math.round(clamped * 100))
        _send(["set_property", "volume", Math.round(clamped * 100)])
    }
    function toggleShuffle(): void {
        shuffleMode = !shuffleMode
        Config.setNestedValue("sidebar.music.shuffleMode", shuffleMode)
        _send([shuffleMode ? "playlist-shuffle" : "playlist-unshuffle"])
    }
    function cycleRepeatMode(): void {
        repeatMode = (repeatMode + 1) % 3
        Config.setNestedValue("sidebar.music.repeatMode", repeatMode)
        _send(["set_property", "loop-file", repeatMode === 1 ? "inf" : "no"])
        _send(["set_property", "loop-playlist", repeatMode === 2 ? "inf" : "no"])
    }
    function stop(): void {
        if (_playProc.running) _send(["quit"])
    }

    Component.onCompleted: {
        _availabilityProc.running = true
        if (enabled) Qt.callLater(root.rescan)
    }
    onEnabledChanged: {
        if (enabled) {
            _availabilityProc.running = true
            Qt.callLater(root.rescan)
        } else stop()
    }
    onConfiguredLibraryFolderChanged: if (enabled) Qt.callLater(root.rescan)

    Process {
        id: _availabilityProc
        stdout: StdioCollector {
            id: mpvPathCollector
        }
        command: ["/bin/sh", "-c", "command -v mpv 2>/dev/null || true"]
        onExited: (_code, _status) => {
            root.mpvPath = (mpvPathCollector.text ?? "").trim()
            root.available = root.mpvPath.length > 0
            if (!root.available) root.error = "mpv_unavailable"
        }
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
                root.error = "scan_failed"
                return
            }
            try {
                const payload = JSON.parse(_scanProc.output || "{}")
                root.libraryTracks = payload.tracks ?? []
                root.playlists = payload.playlists ?? []
                root.folderCollections = payload.folders ?? []
                root.error = String(payload.error ?? "")
            } catch (e) {
                root.error = "scan_parse_failed"
            }
        }
    }

    Process {
        id: _playProc
        onStarted: {
            root.paused = false
            root.playing = true
        }
        onExited: (_code, _status) => {
            root.playing = false
            root.paused = true
            root.currentPosition = 0
            Quickshell.execDetached(["/usr/bin/rm", "-f", root.ipcSocket])
            if (root._pendingPlayCommand.length > 0) Qt.callLater(root._launchPending)
        }
    }

    Process {
        id: _watchProc
        running: _playProc.running
        command: ["python3", root._ipcScript, "watch", root.ipcSocket, "0.75"]
        stdout: SplitParser {
            onRead: line => root._handleStatus(line)
        }
    }
}
