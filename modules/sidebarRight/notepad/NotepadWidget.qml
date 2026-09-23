import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: root
    property int margin: 10
    // Dashboard can opt into a denser chrome while Sidebar keeps the full
    // title/stats/toolbar presentation. The editor and draft semantics stay
    // identical across both surfaces.
    property bool compactPresentation: false
    // Hot-corner Quick Notes is a capture surface rather than a tab manager.
    // Keep the same editor/autosave backend while hiding Dashboard/Sidebar
    // navigation chrome that would slow down a one-thought interaction.
    property bool quickCapturePresentation: false
    readonly property bool narrowCompact:
        root.compactPresentation && root.width > 0 && root.width < 260

    // Style tokens (5-style support)
    readonly property color colText: Appearance.angelEverywhere ? Appearance.angel.colText
        : Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer1
    readonly property color colTextSecondary: Appearance.angelEverywhere ? Appearance.angel.colTextSecondary
        : Appearance.inirEverywhere ? Appearance.inir.colTextSecondary : Appearance.colors.colSubtext
    readonly property color colCard: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
        : Appearance.inirEverywhere ? Appearance.inir.colLayer0
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
        : Appearance.colors.colLayer0
    readonly property color colBorder: Appearance.angelEverywhere ? Appearance.angel.colCardBorder
        : Appearance.inirEverywhere ? Appearance.inir.colBorder : Appearance.colors.colLayer0Border
    readonly property int borderWidth: Appearance.angelEverywhere ? Appearance.angel.cardBorderWidth
        : Appearance.inirEverywhere ? 1 : (Appearance.auroraEverywhere ? 0 : 1)
    readonly property real radius: Appearance.angelEverywhere ? Appearance.angel.roundingNormal
        : Appearance.inirEverywhere ? Appearance.inir.roundingNormal : Appearance.rounding.normal
    readonly property color colPrimary: Appearance.angelEverywhere ? Appearance.angel.colPrimary
        : Appearance.inirEverywhere ? Appearance.inir.colPrimary : Appearance.colors.colPrimary

    // Word count helper
    readonly property int wordCount: textArea.text.trim().length > 0
        ? textArea.text.trim().split(/\s+/).length : 0
    readonly property int tabCount: Notepad.tabs.length
    // Compact Dashboard/Quick Notes surfaces do not expose Zettelkasten
    // actions. Keep that optional singleton (and its Todo backend dependency)
    // cold until the full Sidebar Notepad actually needs the integration.
    readonly property bool zettelkastenIntegrationEnabled:
        !root.compactPresentation
    readonly property bool canSaveZettel: root.zettelkastenIntegrationEnabled
        && Notepad.ready
        && Zettelkasten.ready
        && !Zettelkasten.busy
        && textArea.text.trim().length > 0
    function _captureZettel(): bool {
        if (!root.canSaveZettel)
            return false

        // Persist the visible editor first, then capture a snapshot without
        // consuming or clearing the Notepad draft. Capture is intentionally
        // non-destructive; draft cleanup remains an explicit user action.
        root.flushPendingSave()

        const index = Notepad.indexForTabId(root._loadedTabId)
        const tabTitle = String(Notepad.tabs[index]?.title ?? "").trim()
        const title = /^Note \d+$/.test(tabTitle) ? "" : tabTitle
        const draftText = String(textArea.text)
        return Zettelkasten.capture(title, draftText)
    }

    function saveAsZettel(): bool {
        return root._captureZettel()
    }

    function captureQuickNote(): bool {
        return root._captureZettel()
    }

    // Public focus/save hooks for lightweight secondary surfaces such as the
    // bottom-left Quick Notes popup. They keep the canonical editor in charge
    // of autosave semantics without exposing its private TextArea.
    function focusEditor(): void {
        if (!Notepad.ready)
            return
        Qt.callLater(() => {
            if (root.visible && root.enabled)
                textArea.forceActiveFocus()
        })
    }

    function _activeTabId(): string {
        return String(Notepad.tabs[Notepad.currentTab]?.id ?? "")
    }

    function _loadedTabText(): string {
        const index = Notepad.indexForTabId(root._loadedTabId)
        if (index < 0)
            return ""
        return String(Notepad.tabs[index]?.text ?? "")
    }

    function _persistEditorText(): bool {
        if (!Notepad.ready || root._loadingTab || !root._loadedTabId)
            return false
        if (textArea.text === root._loadedTabText())
            return true
        return Notepad.setTabTextById(root._loadedTabId, textArea.text)
    }

    function flushPendingSave(): void {
        saveTimer.stop()
        root._persistEditorText()
    }

    // Tab mutations can change Notepad.currentTab synchronously. Persist the
    // current editor first so an 800ms autosave still pending in the old tab
    // can never be written into, or discarded by, the newly-selected tab.
    function switchToTab(index): void {
        root.flushPendingSave()
        Notepad.switchTab(index)
    }

    function addTabSafely(): void {
        root.flushPendingSave()
        Notepad.addTab()
    }

    function removeTabSafely(index): void {
        root.flushPendingSave()
        Notepad.removeTab(index)
    }

    // When this widget gets focus (from BottomWidgetGroup.focusActiveItem),
    // move focus to the internal text area on the next event loop tick.
    onFocusChanged: (focus) => {
        if (focus)
            root.focusEditor()
    }
    Component.onDestruction: root.flushPendingSave()

    // Guards programmatic text loads (tab switch / external reload) so they
    // don't trigger the save timer and clobber the freshly-loaded tab. Track the
    // tab identity separately from Notepad.currentTab: several NotepadWidget
    // instances can exist at once (Sidebar, Dashboard and Quick Notes), and a
    // delayed autosave must always write back to the tab it actually displays.
    property bool _loadingTab: false
    property string _loadedTabId: ""

    function _loadActiveTab() {
        if (!Notepad.ready)
            return
        saveTimer.stop()
        root._loadingTab = true
        root._loadedTabId = root._activeTabId()
        textArea.text = Notepad.text
        root._loadingTab = false
    }

    // The TextArea.text binding to Notepad.text breaks the moment the user
    // types, so tab switches and external reloads must be reflected manually.
    // Flush the old displayed tab before adopting a newly-selected one.
    Connections {
        target: Notepad
        function onCurrentTabChanged() {
            root.flushPendingSave()
            root._loadActiveTab()
        }
        function onTabsChanged() {
            if (!Notepad.ready)
                return
            if (root._loadedTabId !== root._activeTabId()) {
                root.flushPendingSave()
                root._loadActiveTab()
                return
            }
            if (!saveTimer.running && textArea.text !== root._loadedTabText())
                root._loadActiveTab()
        }
        function onReadyChanged() {
            if (!Notepad.ready)
                return
            if (root._loadedTabId !== root._activeTabId()
                    || textArea.text !== Notepad.text)
                root._loadActiveTab()
            if (root.focus)
                root.focusEditor()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.margin
        spacing: root.compactPresentation ? 4 : 6

        // Header with title and stats. Dashboard already owns the module title,
        // so compactPresentation removes this duplicate row entirely.
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: !root.compactPresentation

            StyledText {
                text: Translation.tr("Notepad")
                font.pixelSize: Appearance.font.pixelSize.larger
                font.weight: Font.Medium
                color: root.colText
            }

            Item { Layout.fillWidth: true }

            // Stats badge
            Rectangle {
                scale: textArea.text.length > 0 ? 1 : 0
                visible: scale > 0
                Behavior on scale {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                }
                implicitWidth: statsRow.implicitWidth + 12
                implicitHeight: 22
                radius: 11
                color: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                    : Appearance.inirEverywhere ? Appearance.inir.colLayer1
                    : Appearance.colors.colSecondaryContainer

                RowLayout {
                    id: statsRow
                    anchors.centerIn: parent
                    spacing: 6

                    StyledText {
                        text: root.wordCount + " " + (root.wordCount === 1 ? Translation.tr("word") : Translation.tr("words"))
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        font.family: Appearance.font.family.numbers
                        color: Appearance.angelEverywhere ? Appearance.angel.colText
                            : Appearance.inirEverywhere ? Appearance.inir.colText
                            : Appearance.colors.colOnSecondaryContainer
                    }
                }
            }
        }

        // Tab bar
        RowLayout {
            Layout.fillWidth: true
            spacing: 4
            visible: !root.quickCapturePresentation
                && (root.tabCount > 1 || root.tabCount === 1) // Always show outside quick capture

            Flickable {
                Layout.fillWidth: true
                implicitHeight: 28
                contentWidth: tabRow.implicitWidth
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Row {
                    id: tabRow
                    spacing: 4

                    Repeater {
                        model: Notepad.tabs
                        delegate: Rectangle {
                            id: tabPill
                            required property var modelData
                            required property int index
                            readonly property bool active: index === Notepad.currentTab
                            width: tabLabel.implicitWidth + (tabCount > 1 ? closeBtn.width + 16 : 16)
                            height: 26
                            radius: 13
                            color: active
                                ? (Appearance.angelEverywhere ? Appearance.angel.colPrimary
                                    : Appearance.inirEverywhere ? Appearance.inir.colPrimary
                                    : Appearance.colors.colPrimary)
                                : (tabMA.containsMouse
                                    ? (Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
                                        : Appearance.inirEverywhere ? Appearance.inir.colLayer1Hover
                                        : Appearance.colors.colLayer1Hover)
                                    : "transparent")
                            Behavior on color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration } }

                            Row {
                                anchors.centerIn: parent
                                spacing: 4

                                StyledText {
                                    id: tabLabel
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.title || `Note ${index + 1}`
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    font.weight: tabPill.active ? Font.Medium : Font.Normal
                                    color: tabPill.active
                                        ? (Appearance.angelEverywhere ? Appearance.angel.colOnPrimary
                                            : Appearance.inirEverywhere ? Appearance.inir.colOnPrimary
                                            : Appearance.colors.colOnPrimary)
                                        : root.colTextSecondary
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                    width: Math.min(implicitWidth,
                                        root.compactPresentation ? 64 : 80)
                                }

                                // Close button (only when multiple tabs)
                                MaterialSymbol {
                                    id: closeBtn
                                    opacity: tabCount > 1 ? 1 : 0
                                    visible: opacity > 0
                                    Behavior on opacity {
                                        enabled: Appearance.animationsEnabled
                                        NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                                    }
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "close"
                                    iconSize: 12
                                    color: tabPill.active
                                        ? (Appearance.angelEverywhere ? Appearance.angel.colOnPrimary
                                            : Appearance.inirEverywhere ? Appearance.inir.colOnPrimary
                                            : Appearance.colors.colOnPrimary)
                                        : root.colTextSecondary

                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.margins: -4
                                        enabled: Notepad.ready
                                        onClicked: root.removeTabSafely(tabPill.index)
                                    }
                                }
                            }

                            MouseArea {
                                id: tabMA
                                anchors.fill: parent
                                enabled: Notepad.ready
                                hoverEnabled: true
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                z: -1
                                onClicked: root.switchToTab(tabPill.index)
                            }
                        }
                    }
                }
            }

            // Add tab button
            NotepadToolButton {
                icon: "add"
                tooltipText: Translation.tr("New tab")
                enabled: Notepad.ready
                onClicked: root.addTabSafely()
            }

            // Dashboard compact mode keeps the tab strip and editing tools on
            // one line. This returns almost an entire row to the note editor.
            Rectangle {
                visible: root.compactPresentation
                Layout.preferredWidth: 1
                Layout.preferredHeight: 18
                color: root.colBorder
            }

            NotepadToolButton {
                visible: root.compactPresentation
                    && textArea.text.length > 0
                    && !root.narrowCompact
                icon: "text_fields"
                tooltipText: root.wordCount + " "
                    + (root.wordCount === 1
                        ? Translation.tr("word") : Translation.tr("words"))
                enabled: true
            }

            NotepadToolButton {
                visible: root.compactPresentation
                icon: "content_copy"
                tooltipText: Translation.tr("Copy all")
                enabled: textArea.text.length > 0
                onClicked: {
                    Quickshell.execDetached(["wl-copy", textArea.text])
                    copiedToast.show(Translation.tr("Copied!"))
                }
            }

            NotepadToolButton {
                visible: root.compactPresentation
                icon: "content_paste"
                tooltipText: Translation.tr("Paste from clipboard")
                enabled: Notepad.ready
                onClicked: clipboardProc.running = true
            }

            NotepadToolButton {
                visible: root.compactPresentation && !root.narrowCompact
                icon: "select_all"
                tooltipText: Translation.tr("Select all")
                enabled: textArea.text.length > 0
                onClicked: textArea.selectAll()
            }

            NotepadToolButton {
                visible: root.compactPresentation
                icon: "delete"
                tooltipText: Translation.tr("Clear all")
                enabled: Notepad.ready && textArea.text.length > 0
                destructive: true
                onClicked: {
                    textArea.text = ""
                    root.flushPendingSave()
                }
            }
        }

        // Full toolbar remains unchanged for Sidebar; Dashboard folds these
        // actions into the tab row above.
        RowLayout {
            Layout.fillWidth: true
            spacing: 4
            visible: !root.compactPresentation

            NotepadToolButton {
                icon: "content_copy"
                tooltipText: Translation.tr("Copy all")
                enabled: textArea.text.length > 0
                onClicked: {
                    Quickshell.execDetached(["wl-copy", textArea.text])
                    copiedToast.show(Translation.tr("Copied!"))
                }
            }

            NotepadToolButton {
                icon: "content_paste"
                tooltipText: Translation.tr("Paste from clipboard")
                enabled: Notepad.ready
                onClicked: clipboardProc.running = true
            }

            NotepadToolButton {
                icon: "select_all"
                tooltipText: Translation.tr("Select all")
                enabled: textArea.text.length > 0
                onClicked: textArea.selectAll()
            }

            NotepadToolButton {
                icon: "note_add"
                tooltipText: !root.zettelkastenIntegrationEnabled
                    ? ""
                    : Zettelkasten.ready
                        ? Translation.tr("Save as Zettelkasten quick note")
                        : Translation.tr("Configure an Obsidian vault to enable Zettelkasten")
                enabled: root.canSaveZettel
                onClicked: root.saveAsZettel()
            }

            Item { Layout.fillWidth: true }

            NotepadToolButton {
                icon: "delete"
                tooltipText: Translation.tr("Clear all")
                enabled: Notepad.ready && textArea.text.length > 0
                destructive: true
                onClicked: {
                    textArea.text = ""
                    root.flushPendingSave()
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Appearance.angelEverywhere ? Appearance.angel.roundingNormal : Appearance.rounding.normal
            color: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                : Appearance.inirEverywhere ? Appearance.inir.colLayer0
                : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurface
                : Appearance.colors.colLayer0
            border.width: Appearance.angelEverywhere ? Appearance.angel.cardBorderWidth
                : Appearance.inirEverywhere ? 1 : (Appearance.auroraEverywhere ? 0 : 1)
            border.color: Appearance.angelEverywhere ? Appearance.angel.colCardBorder
                : Appearance.inirEverywhere ? Appearance.inir.colBorder : Appearance.colors.colLayer0Border
            clip: true

            ScrollView {
                id: scrollView
                anchors.fill: parent
                anchors.margins: root.compactPresentation ? 6 : 8
                ScrollBar.vertical.policy: ScrollBar.AsNeeded
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

                TextArea {
                    id: textArea
                    enabled: Notepad.ready
                    width: scrollView.availableWidth
                    wrapMode: TextArea.Wrap
                    renderType: Text.NativeRendering
                    font.pixelSize: Appearance.inirEverywhere ? Appearance.font.pixelSize.smaller : Appearance.font.pixelSize.small
                    color: Appearance.inirEverywhere ? Appearance.inir.colText : Appearance.colors.colOnLayer0
                    selectionColor: Appearance.angelEverywhere ? Appearance.angel.colPrimary
                        : Appearance.inirEverywhere ? Appearance.inir.colPrimary
                        : Appearance.colors.colSecondaryContainer
                    selectedTextColor: Appearance.angelEverywhere ? Appearance.angel.colOnPrimary
                        : Appearance.inirEverywhere ? Appearance.inir.colOnPrimary
                        : Appearance.colors.colOnSecondaryContainer
                    placeholderText: Translation.tr("Write your notes here...")
                    placeholderTextColor: Appearance.inirEverywhere ? Appearance.inir.colTextSecondary : Appearance.colors.colOutline
                    Component.onCompleted: root._loadActiveTab()
                    selectByMouse: true
                    persistentSelection: true
                    activeFocusOnTab: true
                    background: null

                    TextInputContextMenu {
                        target: textArea
                    }

                    Keys.onPressed: (event) => {
                        if (Notepad.ready && (event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_S) {
                            root.flushPendingSave()
                            event.accepted = true
                        }
                    }

                    onTextChanged: {
                        if (root._loadingTab || !Notepad.ready) return
                        saveTimer.restart()
                    }

                    onCursorRectangleChanged: {
                        scrollView.ScrollBar.vertical.position = Math.max(0, Math.min(
                            (cursorRectangle.y - scrollView.height / 2) / contentHeight,
                            1 - scrollView.height / contentHeight
                        ))
                    }
                }
            }
        }
    }

    Timer {
        id: saveTimer
        interval: 800
        repeat: false
        onTriggered: root._persistEditorText()
    }

    // Clipboard paste process
    Process {
        id: clipboardProc
        command: ["wl-paste", "-n"]
        running: false
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => {
                if (Notepad.ready && data && data.length > 0) {
                    const cursorPos = textArea.cursorPosition
                    textArea.insert(cursorPos, data)
                }
            }
        }
    }

    // Copied toast notification
    Connections {
        target: root.zettelkastenIntegrationEnabled ? Zettelkasten : null

        function onCaptured(payload): void {
            copiedToast.show(Translation.tr("Saved to Zettelkasten"))
        }
    }

    Rectangle {
        id: copiedToast
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 20
        implicitWidth: toastContent.implicitWidth + 20
        implicitHeight: 32
        radius: 16
        color: root.colPrimary
        opacity: 0
        visible: opacity > 0
        property string message: Translation.tr("Copied!")

        function show(message) {
            copiedToast.message = String(message ?? Translation.tr("Copied!"))
            opacity = 1
            toastTimer.restart()
        }

        Behavior on opacity {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
        }

        RowLayout {
            id: toastContent
            anchors.centerIn: parent
            spacing: 6

            MaterialSymbol {
                text: "check"
                iconSize: 14
                color: Appearance.angelEverywhere ? Appearance.angel.colOnPrimary
                    : Appearance.inirEverywhere ? Appearance.inir.colOnPrimary
                    : Appearance.colors.colOnPrimary
            }

            StyledText {
                text: copiedToast.message
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.angelEverywhere ? Appearance.angel.colOnPrimary
                    : Appearance.inirEverywhere ? Appearance.inir.colOnPrimary
                    : Appearance.colors.colOnPrimary
            }
        }

        Timer {
            id: toastTimer
            interval: 1500
            onTriggered: copiedToast.opacity = 0
        }
    }

    // Toolbar button component
    component NotepadToolButton: Item {
        id: toolBtn
        required property string icon
        property string tooltipText: ""
        property bool destructive: false

        signal clicked()

        implicitWidth: root.compactPresentation ? 28 : 32
        implicitHeight: root.compactPresentation ? 26 : 28

        opacity: enabled ? 1 : 0.4

        Rectangle {
            anchors.fill: parent
            radius: Appearance.angelEverywhere ? Appearance.angel.roundingSmall
                : Appearance.inirEverywhere ? Appearance.inir.roundingSmall : Appearance.rounding.small
            color: {
                if (!toolBtn.enabled) return "transparent"
                if (toolBtnMA.containsPress)
                    return toolBtn.destructive
                        ? ColorUtils.transparentize(Appearance.colors.colError, 0.7)
                        : (Appearance.angelEverywhere ? Appearance.angel.colGlassCardActive
                         : Appearance.inirEverywhere ? Appearance.inir.colLayer1Active
                         : Appearance.colors.colLayer1Active)
                if (toolBtnMA.containsMouse)
                    return toolBtn.destructive
                        ? ColorUtils.transparentize(Appearance.colors.colError, 0.85)
                        : (Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
                         : Appearance.inirEverywhere ? Appearance.inir.colLayer1Hover
                         : Appearance.colors.colLayer1Hover)
                return "transparent"
            }
            Behavior on color { enabled: Appearance.animationsEnabled; ColorAnimation { duration: Appearance.animation.elementMoveFast.duration } }

            MaterialSymbol {
                anchors.centerIn: parent
                text: toolBtn.icon
                iconSize: root.compactPresentation ? 16 : 18
                color: toolBtn.destructive && toolBtn.enabled
                    ? Appearance.colors.colError
                    : root.colTextSecondary
            }

            MouseArea {
                id: toolBtnMA
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: toolBtn.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: if (toolBtn.enabled) toolBtn.clicked()
            }

            StyledToolTip {
                visible: toolBtnMA.containsMouse && toolBtn.tooltipText !== ""
                text: toolBtn.tooltipText
            }
        }
    }
}
