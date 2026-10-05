pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.settings
import qs.modules.sidebarRight.nightLight
import qs.modules.abyss.looks

Item {
    id: root

    property string outputName: ""
    property alias currentPage: pages.currentIndex
    readonly property var currentFeature: pages.currentItem?.item ?? null
    readonly property int loadedPageCount: [monitorLoader, displayLoader, audioLoader, nightLoader]
        .filter(loader => loader.active && loader.item !== null).length
    readonly property var pageTitles: [
        "Monitor arrangement", "Display mode", "Sound", "Eye protection"
    ]
    readonly property var pageWidths: [620, 540, 480, 460]
    readonly property var pageHeights: [430, 390, 430, 500]
    // SwipeView changes currentIndex before its horizontal motion has fully
    // settled. Keep the viewport geometry latched to the previously settled
    // page until that motion ends so the page distance cannot change mid-slide.
    property int geometryPage: 0
    property int pendingGeometryPage: 0

    implicitWidth: pageWidths[Math.max(0, Math.min(geometryPage, pageWidths.length - 1))]
    implicitHeight: pageHeights[Math.max(0, Math.min(geometryPage, pageHeights.length - 1))]

    function commitPageGeometry(): void {
        const view = pages.contentItem
        if (view && (view.moving || view.dragging || view.flicking)) {
            geometrySettleTimer.interval = 16
            geometrySettleTimer.restart()
            return
        }

        geometrySettleTimer.stop()
        root.geometryPage = root.pendingGeometryPage

        // A width change re-lays out SwipeView delegates. Re-pin the current
        // page immediately so geometry settlement never starts a second slide.
        if (view?.positionViewAtIndex)
            Qt.callLater(() => view.positionViewAtIndex(
                pages.currentIndex, ListView.Beginning))
    }

    function queuePageGeometry(index: int): void {
        root.pendingGeometryPage = index
        if (!AbyssStyle.motionEnabled) {
            geometrySettleTimer.stop()
            root.geometryPage = index
            return
        }

        // Material SwipeView animates programmatic index changes through its
        // ListView highlight duration. Use the live value rather than copying a
        // magic duration so this remains correct if Qt changes the style.
        geometrySettleTimer.interval = Math.max(16,
            Number(pages.contentItem?.highlightMoveDuration ?? 250) + 16)
        geometrySettleTimer.restart()
    }

    // Interactive descendants acquire focus on demand. Pre-focusing this
    // hover-owned surface would hold the shared dismissal lease forever.
    focus: false
    signal closeRequested()

    Keys.onLeftPressed: event => {
        if (pages.currentIndex > 0) pages.currentIndex--
        event.accepted = true
    }
    Keys.onRightPressed: event => {
        if (pages.currentIndex < pages.count - 1) pages.currentIndex++
        event.accepted = true
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            AbyssLabel {
                text: root.pageTitles[pages.currentIndex] ?? "Utilities"
                font.pixelSize: AbyssStyle.fontSize * 1.12
                font.weight: Font.DemiBold
                Layout.fillWidth: true
            }

        }

        SwipeView {
            id: pages
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            interactive: true
            onCurrentIndexChanged: root.queuePageGeometry(currentIndex)

            Loader {
                id: monitorLoader
                active: Math.abs(SwipeView.index - pages.currentIndex) <= 1
                sourceComponent: monitorPage
            }
            Loader {
                id: displayLoader
                active: Math.abs(SwipeView.index - pages.currentIndex) <= 1
                sourceComponent: displayPage
            }
            Loader {
                id: audioLoader
                active: Math.abs(SwipeView.index - pages.currentIndex) <= 1
                sourceComponent: audioPage
            }
            Loader {
                id: nightLoader
                active: Math.abs(SwipeView.index - pages.currentIndex) <= 1
                sourceComponent: nightPage
            }
        }

        Row {
            Layout.alignment: Qt.AlignHCenter
            spacing: 8

            Repeater {
                model: pages.count
                delegate: Rectangle {
                    required property int index
                    width: index === pages.currentIndex ? 9 : 7
                    height: width
                    radius: width / 2
                    color: index === pages.currentIndex
                        ? AbyssStyle.accent : Qt.alpha(AbyssStyle.textColor, .28)

                    Behavior on width {
                        enabled: AbyssStyle.motionEnabled
                        NumberAnimation { duration: AbyssStyle.motionFast; easing.type: Easing.OutCubic }
                    }
                    Behavior on color {
                        enabled: AbyssStyle.motionEnabled
                        ColorAnimation { duration: AbyssStyle.motionFast }
                    }

                    TapHandler {
                        onTapped: pages.currentIndex = parent.index
                    }
                }
            }
        }
    }

    Timer {
        id: geometrySettleTimer
        interval: 266
        repeat: false
        onTriggered: root.commitPageGeometry()
    }

    Connections {
        target: pages.contentItem
        ignoreUnknownSignals: true
        function onMovementEnded(): void {
            root.commitPageGeometry()
        }
        function onFlickEnded(): void {
            root.commitPageGeometry()
        }
    }

    Component {
        id: monitorPage

        Item {
            Loader {
                anchors.fill: parent
                active: CompositorService.isNiri
                sourceComponent: MonitorVisibilityConfig {
                    embeddedArrangementOnly: true
                    activeSection: "outputs"
                }
            }

            AbyssLabel {
                anchors.centerIn: parent
                width: Math.min(parent.width - 40, 520)
                visible: !CompositorService.isNiri
                horizontalAlignment: Text.AlignHCenter
                text: "Niri only."
                color: AbyssStyle.textColorMuted
            }
        }
    }

    Component {
        id: displayPage

        Item {
            ColumnLayout {
                anchors.fill: parent
                spacing: 12

                AbyssLabel {
                    Layout.fillWidth: true
                    text: "Choose active displays."
                    color: AbyssStyle.textColorMuted
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    AbyssButton {
                        Layout.fillWidth: true
                        glyph: "view_week"
                        text: "Extend"
                        checked: DisplayMode.currentMode === "extend"
                        enabled: CompositorService.isNiri && !DisplayMode.applying
                        onClicked: DisplayMode.apply("extend")
                    }
                    AbyssButton {
                        Layout.fillWidth: true
                        glyph: "laptop"
                        text: "Primary only"
                        checked: DisplayMode.currentMode === "primary-only"
                        enabled: CompositorService.isNiri && !DisplayMode.applying
                        onClicked: DisplayMode.apply("primary-only")
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        AbyssLabel { text: "Second screen" }
                        StyledComboBox {
                            Layout.fillWidth: true
                            enableSettingsSearch: false
                            model: DisplayMode.connectedOutputs.filter(
                                output => output !== DisplayMode.primaryOutput)
                            currentIndex: Math.max(0, model.indexOf(DisplayMode.selectedSecondary))
                            enabled: model.length > 0 && !DisplayMode.applying
                            onActivated: DisplayMode.selectedSecondary = currentText
                        }
                    }

                    AbyssButton {
                        Layout.alignment: Qt.AlignBottom
                        glyph: "desktop_windows"
                        text: "Second screen only"
                        checked: DisplayMode.currentMode === "second-only"
                        enabled: CompositorService.isNiri && !DisplayMode.applying
                            && DisplayMode.selectedSecondary.length > 0
                        onClicked: DisplayMode.apply("second-only")
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: mirrorColumn.implicitHeight + 24
                    radius: 18
                    color: Qt.alpha(AbyssStyle.accent, .05)
                    border.width: 1
                    border.color: Qt.alpha(AbyssStyle.accent, .16)

                    ColumnLayout {
                        id: mirrorColumn
                        anchors {
                            fill: parent
                            margins: 12
                        }
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            AbyssLabel {
                                text: "Mirror"
                                font.weight: Font.DemiBold
                                Layout.fillWidth: true
                            }
                            AbyssLabel {
                                text: DisplayMode.mirrorAvailable ? "wl-mirror ready" : "wl-mirror unavailable"
                                color: DisplayMode.mirrorAvailable
                                    ? AbyssStyle.textColorMuted : Appearance.colors.colError
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                AbyssLabel { text: "Source" }
                                StyledComboBox {
                                    Layout.fillWidth: true
                                    enableSettingsSearch: false
                                    model: DisplayMode.connectedOutputs
                                    currentIndex: Math.max(0, model.indexOf(DisplayMode.mirrorSource))
                                    enabled: model.length > 1 && !DisplayMode.applying
                                    onActivated: DisplayMode.setMirrorSource(currentText)
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                AbyssLabel { text: "Target" }
                                StyledComboBox {
                                    Layout.fillWidth: true
                                    enableSettingsSearch: false
                                    model: DisplayMode.connectedOutputs.filter(
                                        output => output !== DisplayMode.mirrorSource)
                                    currentIndex: Math.max(0, model.indexOf(DisplayMode.mirrorTarget))
                                    enabled: model.length > 0 && !DisplayMode.applying
                                    onActivated: DisplayMode.setMirrorTarget(currentText)
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            AbyssLabel {
                                Layout.fillWidth: true
                                text: DisplayMode.mirrorAvailable
                                    ? "Mirror via wl-mirror."
                                    : "Install wl-mirror."
                                color: AbyssStyle.textColorMuted
                            }
                            AbyssButton {
                                glyph: DisplayMode.currentMode === "mirror" ? "stop_screen_share" : "screen_share"
                                text: DisplayMode.currentMode === "mirror" ? "Stop mirror" : "Mirror"
                                enabled: DisplayMode.mirrorAvailable && !DisplayMode.applying
                                    && DisplayMode.mirrorSource.length > 0
                                    && DisplayMode.mirrorTarget.length > 0
                                onClicked: {
                                    if (DisplayMode.currentMode === "mirror") DisplayMode.stopMirror()
                                    else DisplayMode.apply("mirror")
                                }
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }

                AbyssLabel {
                    Layout.fillWidth: true
                    visible: DisplayMode.statusMessage.length > 0 || DisplayMode.lastError.length > 0
                    text: DisplayMode.lastError.length > 0
                        ? DisplayMode.lastError : DisplayMode.statusMessage
                    color: DisplayMode.lastError.length > 0
                        ? Appearance.colors.colError : AbyssStyle.textColorMuted
                }
            }
        }
    }

    Component {
        id: audioPage

        Item {
            ColumnLayout {
                anchors.fill: parent
                spacing: 10

                AbyssLabel {
                    Layout.fillWidth: true
                    text: Audio.sink ? "Output · " + Audio.friendlyDeviceName(Audio.sink)
                        : "No active audio output"
                    font.weight: Font.DemiBold
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    AbyssButton {
                        compact: true
                        glyph: Audio.sink?.audio?.muted ? "volume_off" : "volume_up"
                        description: Audio.sink?.audio?.muted ? "Unmute output" : "Mute output"
                        enabled: !!Audio.sink?.audio
                        onClicked: Audio.toggleMute()
                    }

                    AbyssSlider {
                        Layout.fillWidth: true
                        from: 0
                        to: Math.min(2, Audio.hardMaxValue)
                        value: Audio.value
                        unit: "%"
                        enabled: !!Audio.sink?.audio
                        onMoved: Audio.setSinkVolume(value)
                    }
                }

                AbyssLabel {
                    text: "Output device"
                    color: AbyssStyle.textColorMuted
                }

                StyledComboBox {
                    Layout.fillWidth: true
                    enableSettingsSearch: false
                    model: Audio.outputDevices.map(device => Audio.friendlyDeviceName(device))
                    currentIndex: Audio.outputDevices.findIndex(device =>
                        device.id === Audio.sink?.id)
                    enabled: Audio.outputDevices.length > 0
                    onActivated: {
                        const device = Audio.outputDevices[currentIndex]
                        if (device)
                            Audio.setDefaultSink(device)
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Qt.alpha(AbyssStyle.textColor, .12)
                }

                AbyssLabel {
                    Layout.fillWidth: true
                    text: Audio.source ? "Input · " + Audio.friendlyDeviceName(Audio.source)
                        : "No active audio input"
                    font.weight: Font.DemiBold
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    AbyssButton {
                        compact: true
                        glyph: Audio.micMuted ? "mic_off" : "mic"
                        description: Audio.micMuted ? "Unmute input" : "Mute input"
                        enabled: Audio.inputDevices.length > 0 || !!Audio.source?.audio
                        onClicked: Audio.toggleMicMute()
                    }

                    AbyssSlider {
                        Layout.fillWidth: true
                        from: 0
                        to: Math.min(2, Audio.hardMaxValue)
                        value: Audio.micVolume
                        unit: "%"
                        enabled: Audio.inputDevices.length > 0 || !!Audio.source?.audio
                        onMoved: Audio.setSourceVolume(value)
                    }
                }

                AbyssLabel {
                    text: "Input device"
                    color: AbyssStyle.textColorMuted
                }

                StyledComboBox {
                    Layout.fillWidth: true
                    enableSettingsSearch: false
                    model: Audio.inputDevices.map(device => Audio.friendlyDeviceName(device))
                    currentIndex: Audio.inputDevices.findIndex(device =>
                        device.id === Audio.source?.id)
                    enabled: Audio.inputDevices.length > 0
                    onActivated: {
                        const device = Audio.inputDevices[currentIndex]
                        if (device)
                            Audio.setDefaultSource(device)
                    }
                }

                AbyssLabel {
                    Layout.fillWidth: true
                    visible: Audio.outputDevices.length === 0 || Audio.inputDevices.length === 0
                    text: Audio.outputDevices.length === 0 && Audio.inputDevices.length === 0
                        ? "No PipeWire input or output devices are available."
                        : Audio.outputDevices.length === 0
                            ? "No PipeWire output devices are available."
                            : "No PipeWire input devices are available."
                    color: AbyssStyle.textColorMuted
                }

                Item { Layout.fillHeight: true }
            }
        }
    }

    Component {
        id: nightPage

        Item {
            NightLightDialog {
                anchors.fill: parent
                embeddedPresentation: true
                show: true
                onDismiss: root.closeRequested()
            }
        }
    }
}
