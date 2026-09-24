pragma Singleton

import QtQuick
import Quickshell.Io
import qs.services

// Niri keyboard-layout state for shell indicators. NiriService owns the
// compositor event stream; this service only resolves a short XKB code.
Singleton {
    id: root

    property list<string> layoutCodes: []
    property var cachedLayoutCodes: ({})
    property string currentLayoutName: ""
    property string currentLayoutCode: ""
    readonly property string baseLayoutFilePath: "/usr/share/X11/xkb/rules/base.lst"

    onCurrentLayoutNameChanged: root.updateLayoutCode()

    function syncFromNiri(): void {
        root.layoutCodes = NiriService.keyboardLayoutNames ?? []
        root.currentLayoutName = NiriService.getCurrentKeyboardLayoutName()
    }

    function updateLayoutCode(): void {
        if (root.currentLayoutName.length === 0) {
            root.currentLayoutCode = ""
            return
        }
        if (root.cachedLayoutCodes.hasOwnProperty(root.currentLayoutName)) {
            root.currentLayoutCode = root.cachedLayoutCodes[root.currentLayoutName]
            return
        }
        root.currentLayoutCode = ""
        if (!getLayoutProc.running)
            getLayoutProc.running = true
    }

    Process {
        id: getLayoutProc
        command: ["cat", root.baseLayoutFilePath]

        stdout: StdioCollector {
            id: layoutCollector
            onStreamFinished: {
                const targetDescription = root.currentLayoutName
                const lines = layoutCollector.text.split("\n")
                const found = lines.some(line => {
                    if (!line.trim() || line.trim().startsWith("!"))
                        return false
                    const variant = line.match(/^\s*(\S+)\s+(\S+)\s+(.+)$/)
                    if (variant && variant[3] === targetDescription) {
                        const code = variant[2] + variant[1]
                        root.cachedLayoutCodes[targetDescription] = code
                        root.currentLayoutCode = code
                        return true
                    }
                    const layout = line.match(/^\s*(\S+)\s+(.+)$/)
                    if (layout && layout[2] === targetDescription) {
                        root.cachedLayoutCodes[targetDescription] = layout[1]
                        root.currentLayoutCode = layout[1]
                        return true
                    }
                    return false
                })
                if (!found && targetDescription === root.currentLayoutName)
                    root.currentLayoutCode = ""
            }
        }
    }

    Connections {
        target: NiriService
        function onKeyboardLayoutNamesChanged(): void { root.syncFromNiri() }
        function onCurrentKeyboardLayoutIndexChanged(): void { root.syncFromNiri() }
    }

    Component.onCompleted: root.syncFromNiri()
}
