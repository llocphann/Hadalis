pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

// Real Fcitx5 state, not a separate Niri keyboard-layout switch.
ColumnLayout {
    id: root
    Layout.fillWidth: true
    spacing: 10

    readonly property string bridge: Quickshell.shellPath("scripts/input-method/fcitx5-settings.py")
    property var inputState: ({ installed: false, engineInstalled: false, running: false,
        state: 0, current: "", unikeyConfigured: false, method: "0", charset: "0" })
    property bool loaded: false
    function syncMethod() {
        if (!loaded)
            return
        const options = methodCombo.model
        for (let i = 0; i < options.length; ++i) {
            if (options[i].value === String(root.inputState.method)) {
                methodCombo.currentIndex = i
                return
            }
        }
        methodCombo.currentIndex = -1
    }
    onInputStateChanged: Qt.callLater(root.syncMethod)
    property string errorText: ""
    property string infoText: ""
    readonly property bool busy: readProcess.running || writeProcess.running
    readonly property bool canConfigure: inputState.installed && inputState.engineInstalled
    readonly property bool vietnameseActive: inputState.state === 2 && inputState.current === "unikey"
    readonly property bool englishActive: inputState.state === 1

    function acceptResponse(raw, isWrite, exitCode) {
        try {
            const response = JSON.parse(String(raw ?? "").trim())
            if (!response || typeof response !== "object")
                throw new Error("Invalid input method response")
            if (exitCode !== 0 || response.ok !== true) {
                root.errorText = String(response.error ?? Translation.tr("Fcitx5 operation failed."))
                if (isWrite)
                    root.infoText = ""
            } else {
                root.inputState = response
                root.loaded = true
                root.errorText = ""
                if (isWrite)
                    root.infoText = String(response.notice ?? "")
            }
        } catch (error) {
            root.errorText = Translation.tr("Unable to read the Fcitx5 status.")
        }
    }

    function refresh() {
        if (!root.visible || root.busy)
            return
        readProcess.running = true
    }

    function runAction(action, value) {
        if (root.busy)
            return
        root.errorText = ""
        root.infoText = ""
        writeProcess.command = ["python3", root.bridge, action]
        if (value !== undefined && value !== null)
            writeProcess.command = ["python3", root.bridge, action, String(value)]
        writeProcess.running = true
    }

    onVisibleChanged: {
        if (visible)
            Qt.callLater(root.refresh)
    }
    Component.onCompleted: Qt.callLater(root.refresh)

    Timer {
        interval: 5000
        repeat: true
        running: root.visible
        onTriggered: root.refresh()
    }

    Process {
        id: readProcess
        command: ["python3", root.bridge, "status"]
        stdout: StdioCollector { id: readOutput }
        stderr: StdioCollector { id: readError }
        onExited: (exitCode) => {
            root.acceptResponse(readOutput.text || readError.text, false, exitCode)
        }
    }

    Process {
        id: writeProcess
        stdout: StdioCollector { id: writeOutput }
        stderr: StdioCollector { id: writeError }
        onExited: (exitCode) => {
            root.acceptResponse(writeOutput.text || writeError.text, true, exitCode)
            Qt.callLater(root.refresh)
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        MaterialSymbol {
            text: root.inputState.running ? "check_circle" : "keyboard"
            iconSize: Appearance.font.pixelSize.large
            color: root.inputState.running ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
        }
        StyledText {
            Layout.fillWidth: true
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOnLayer1
            text: !root.loaded ? Translation.tr("Checking input method…")
                : !root.inputState.installed ? Translation.tr("Fcitx5 is not installed")
                : !root.inputState.running ? Translation.tr("Fcitx5 is not running")
                : root.vietnameseActive ? Translation.tr("Vietnamese · Unikey active")
                : root.englishActive ? Translation.tr("English input active")
                : Translation.tr("Active input method: %1").arg(root.inputState.current || "Fcitx5")
        }
        Button {
            text: Translation.tr("Refresh")
            enabled: !root.busy
            onClicked: root.refresh()
        }
    }

    SettingsNote {
        visible: root.loaded && !root.inputState.installed
        warning: true
        icon: "warning"
        text: Translation.tr("Install fcitx5, fcitx5-qt and fcitx5-unikey, then log in to Niri again.")
    }
    SettingsNote {
        visible: root.loaded && root.inputState.installed && !root.inputState.engineInstalled
        warning: true
        icon: "warning"
        text: Translation.tr("Unikey is missing. Install fcitx5-unikey to enable Vietnamese typing.")
    }

    RowLayout {
        Layout.fillWidth: true
        visible: root.canConfigure && !root.inputState.running
        Button {
            text: Translation.tr("Start Fcitx5")
            enabled: !root.busy
            onClicked: root.runAction("start")
        }
        Item { Layout.fillWidth: true }
    }

    RowLayout {
        Layout.fillWidth: true
        visible: root.canConfigure && root.inputState.running && !root.inputState.unikeyConfigured
        StyledText {
            Layout.fillWidth: true
            text: Translation.tr("Unikey is not in the active input-method list.")
            color: Appearance.colors.colSubtext
            wrapMode: Text.WordWrap
        }
        Button {
            text: Translation.tr("Add Unikey")
            enabled: !root.busy
            onClicked: root.runAction("add-unikey")
        }
    }

    ContentSubsection {
        visible: root.canConfigure && root.inputState.running && root.inputState.unikeyConfigured
        title: Translation.tr("Input language")

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Button {
                Layout.fillWidth: true
                text: Translation.tr("English")
                highlighted: root.englishActive
                enabled: !root.busy
                onClicked: root.runAction("set-language", "en")
            }
            Button {
                Layout.fillWidth: true
                text: Translation.tr("Vietnamese")
                highlighted: root.vietnameseActive
                enabled: !root.busy
                onClicked: root.runAction("set-language", "vi")
            }
        }
    }

    ContentSubsection {
        visible: root.canConfigure
        title: Translation.tr("Vietnamese typing method")
        tooltip: Translation.tr("Changes the Unikey engine, not Niri's physical keyboard layout.")

        StyledComboBox {
            id: methodCombo
            Layout.fillWidth: true
            enabled: !root.busy
            model: [
                { displayName: Translation.tr("Telex"), value: "0" },
                { displayName: Translation.tr("VNI"), value: "1" }
            ]
            textRole: "displayName"
            currentIndex: {
                for (let i = 0; i < model.length; ++i)
                    if (model[i].value === root.inputState.method)
                        return i
                return -1
            }
            onActivated: {
                const chosen = model[currentIndex].value
                if (root.loaded && chosen !== root.inputState.method)
                    root.runAction("set-method", chosen)
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        visible: root.canConfigure
        spacing: 8
        StyledText {
            Layout.fillWidth: true
            text: root.inputState.charset === "0"
                ? Translation.tr("Output: Unicode (UTF-8)")
                : Translation.tr("Output: Custom character set (%1)").arg(root.inputState.charset)
            color: Appearance.colors.colOnLayer1
            font.pixelSize: Appearance.font.pixelSize.small
        }
        Button {
            visible: root.inputState.charset !== "0"
            enabled: !root.busy
            text: Translation.tr("Use Unicode")
            onClicked: root.runAction("set-charset", "0")
        }
    }

    SettingsNote {
        visible: root.canConfigure && root.inputState.method !== "0" && root.inputState.method !== "1"
        text: Translation.tr("A custom Unikey method is configured. Select Telex or VNI above to replace it.")
    }
    SettingsNote {
        visible: root.canConfigure && root.inputState.running
        text: Translation.tr("Ctrl+Space switches English and Vietnamese. Individual applications may keep their own input state.")
    }

    StyledText {
        Layout.fillWidth: true
        visible: root.errorText.length > 0
        text: root.errorText
        color: Appearance.colors.colError
        wrapMode: Text.WordWrap
        font.pixelSize: Appearance.font.pixelSize.small
    }
    SettingsNote {
        visible: root.infoText.length > 0
        text: root.infoText
    }

    RowLayout {
        Layout.fillWidth: true
        Button {
            text: Translation.tr("Advanced Fcitx5 settings")
            enabled: root.inputState.configtoolInstalled ?? false
            onClicked: ShellExec.execDetachedArgs(["fcitx5-configtool"], Translation.tr("Fcitx5 settings"))
        }
        Item { Layout.fillWidth: true }
    }

    SettingsNote {
        visible: root.loaded && root.inputState.installed && !root.inputState.configtoolInstalled
        text: Translation.tr("Install fcitx5-configtool for additional shortcuts and input-method options.")
    }

    MaterialTextField {
        Layout.fillWidth: true
        visible: root.canConfigure && root.inputState.running
        placeholderText: Translation.tr("Test here: tieengs Vieetj → tiếng Việt")
        Accessible.name: Translation.tr("Test Vietnamese input")
    }
}
