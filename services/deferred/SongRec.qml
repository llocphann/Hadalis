pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

Singleton {
    id: root

    enum MonitorSource { Monitor, Input }

    property var monitorSource: SongRec.MonitorSource.Monitor
    property int timeoutInterval: Config.options?.musicRecognition?.interval ?? 10
    property int timeoutDuration: Config.options?.musicRecognition?.timeout ?? 10
    readonly property bool running: recognizeMusicProc.running
    property string _recognitionOutput: ""

    function toggleRunning(running) {
        const wantRunning = (running !== undefined) ? running : !root.running
        if (recognizeMusicProc.running && wantRunning === false) root.manuallyStopped = true;
        if (wantRunning === true) {
            root.manuallyStopped = false;
            root._recognitionOutput = ""
        }

        recognizeMusicProc.running = wantRunning
        musicReconizedProc.running = false
    }

    function toggleMonitorSource(source) {
        if (source !== undefined) {
            root.monitorSource = source
            return
        }
        root.monitorSource = (root.monitorSource === SongRec.MonitorSource.Monitor) ? SongRec.MonitorSource.Input : SongRec.MonitorSource.Monitor
    }
    function monitorSourceToString(source) {
        if (source === SongRec.MonitorSource.Monitor) {
            return "monitor"
        } else {
            return "input"
        }
    }
    readonly property string monitorSourceString: monitorSourceToString(monitorSource)
    property var recognizedTrack: ({ title:"", subtitle:"", url:""})
    property bool manuallyStopped: false

    function handleRecognition(jsonText) {
        try {
            if ((jsonText ?? "").trim() === "") {
                Quickshell.execDetached(["/usr/bin/notify-send", Translation.tr("Couldn't recognize music"), Translation.tr("No match found before timeout"), "-a", "Shell"])
                return
            }
            var obj = JSON.parse(jsonText)
            root.recognizedTrack = {
                title: obj.track.title,
                subtitle: obj.track.subtitle,
                url: obj.track.url
            }

            musicReconizedProc.running = true
        } catch(e) {
            Quickshell.execDetached(["/usr/bin/notify-send", Translation.tr("Couldn't recognize music"), Translation.tr("Perhaps what you're listening to is too niche"), "-a", "Shell"])
        }
    }

    function _finishRecognition(exitCode: int): void {
        const output = root._recognitionOutput
        root._recognitionOutput = ""
        if (root.manuallyStopped) {
            root.manuallyStopped = false
            return
        }
        if (exitCode !== 0) {
            Quickshell.execDetached(["/usr/bin/notify-send", Translation.tr("Couldn't recognize music"), Translation.tr("Check songrec, audio tools, and the selected input source"), "-a", "Shell"])
            return
        }
        root.handleRecognition(output)
    }

    Process {
        id: recognizeMusicProc
        property bool startObserved: false
        running: false
        command: ["/usr/bin/bash", `${Directories.scriptsPath}/musicRecognition/recognize-music.sh`, "-i", String(root.timeoutInterval), "-t", String(root.timeoutDuration), "-s", root.monitorSourceString]
        stdout: StdioCollector {
            onStreamFinished: root._recognitionOutput = this.text ?? ""
        }
        onRunningChanged: {
            if (recognizeMusicProc.running) {
                recognizeMusicProc.startObserved = false
                return
            }
            if (recognizeMusicProc.startObserved)
                return
            Qt.callLater(() => root._finishRecognition(-1))
        }
        onStarted: recognizeMusicProc.startObserved = true
        onExited: (exitCode, exitStatus) => Qt.callLater(() => root._finishRecognition(exitCode))
    }

    Process {
        id: musicReconizedProc
        running: false
        command: [
            "/usr/bin/notify-send",
            "-a", "Shell",
            "-A", "shazam=Shazam",
            "-A", "youtube=YouTube",
            Translation.tr("Music Recognized"),
            root.recognizedTrack.title + " - " + root.recognizedTrack.subtitle
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                const action = (this.text ?? "").trim()
                if (action === "shazam") {
                    Qt.openUrlExternally(root.recognizedTrack.url);
                } else if (action === "youtube") {
                    Qt.openUrlExternally("https://www.youtube.com/results?search_query=" + root.recognizedTrack.title + " - " + root.recognizedTrack.subtitle);
                }
            }
        }
    }
}
