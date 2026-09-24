import qs.services
import qs.modules.common
import qs.modules.common.widgets
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Shapes
import QtQuick.Layouts
import Quickshell

Item {
    id: root
    property bool compactMode: false
    property bool centerMode: true

    // Style helpers
    readonly property color _colLayer: Appearance.angelEverywhere ? Appearance.angel.colGlassCard
        : Appearance.inirEverywhere ? Appearance.inir.colLayer2
        : Appearance.auroraEverywhere ? Appearance.aurora.colElevatedSurface
        : Appearance.colors.colLayer2
    readonly property color _colLayerHover: Appearance.angelEverywhere ? Appearance.angel.colGlassCardHover
        : Appearance.inirEverywhere ? Appearance.inir.colLayer2Hover
        : Appearance.auroraEverywhere ? Appearance.aurora.colElevatedSurfaceHover
        : Appearance.colors.colLayer2Hover
    readonly property color _colLayerActive: Appearance.angelEverywhere ? Appearance.angel.colGlassCardActive
        : Appearance.inirEverywhere ? Appearance.inir.colLayer2Active
        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceActive
        : Appearance.colors.colLayer2Active
    readonly property color _colText: Appearance.angelEverywhere ? Appearance.angel.colText
        : Appearance.inirEverywhere ? Appearance.inir.colText
        : Appearance.colors.colOnLayer2
    readonly property color _colTextSecondary: Appearance.angelEverywhere ? Appearance.angel.colTextSecondary
        : Appearance.inirEverywhere ? Appearance.inir.colTextSecondary
        : Appearance.colors.colSubtext
    readonly property color _colAccent: Appearance.angelEverywhere ? Appearance.angel.colPrimary
        : Appearance.inirEverywhere ? Appearance.inir.colPrimary
        : Appearance.colors.colPrimary
    readonly property color _colTrack: ColorUtils.transparentize(root._colTextSecondary, 0.72)

    property bool settingsOpen: false

    // Reusable row for adjusting a single timer duration value
    component AdjustRow: RowLayout {
        id: adjustRow
        property string icon
        property string label
        property int currentValue
        property int minValue
        property int maxValue
        property int step
        property string configPath
        property bool isMinutes: true
        property bool _editing: false

        Layout.fillWidth: true
        spacing: 0

        MaterialSymbol {
            text: adjustRow.icon
            iconSize: 16
            color: root._colTextSecondary
            Layout.rightMargin: 6
        }
        StyledText {
            text: adjustRow.label
            font.pixelSize: Appearance.font.pixelSize.small
            color: root._colTextSecondary
            Layout.fillWidth: true
        }
        RippleButton {
            implicitWidth: 28; implicitHeight: 28
            buttonRadius: Appearance.rounding.full
            colBackground: "transparent"
            colBackgroundHover: root._colLayerHover
            colRipple: root._colLayerActive
            enabled: adjustRow.currentValue > adjustRow.minValue
            onClicked: Config.setNestedValue(adjustRow.configPath, Math.max(adjustRow.minValue, adjustRow.currentValue - adjustRow.step))
            contentItem: MaterialSymbol {
                anchors.centerIn: parent
                text: "remove"
                iconSize: 16
                color: enabled ? root._colText : root._colTextSecondary
            }
        }
        Rectangle {
            implicitWidth: 56
            implicitHeight: 28
            radius: Appearance.angelEverywhere ? Appearance.angel.roundingSmall
                : Appearance.inirEverywhere ? Appearance.inir.roundingSmall
                : Appearance.rounding.small
            color: adjustRow._editing
                ? (Appearance.angelEverywhere ? ColorUtils.transparentize(Appearance.angel.colPrimary, 0.8)
                 : Appearance.inirEverywhere ? Appearance.inir.colSecondaryContainer
                 : Appearance.colors.colPrimaryContainer)
                : Appearance.angelEverywhere ? Appearance.angel.colGlassCard
                : Appearance.inirEverywhere ? Appearance.inir.colLayer1
                : Appearance.colors.colLayer1
            border.width: adjustRow._editing ? 1 : 0
            border.color: Appearance.angelEverywhere ? Appearance.angel.colPrimary
                : Appearance.inirEverywhere ? Appearance.inir.colPrimary
                : Appearance.colors.colPrimary
            TextInput {
                anchors.centerIn: parent
                width: parent.width - 8
                text: adjustRow.isMinutes ? Math.floor(adjustRow.currentValue / 60).toString() : adjustRow.currentValue.toString()
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.Medium
                font.family: Appearance.font.family.main
                color: root._colText
                horizontalAlignment: Text.AlignHCenter
                validator: IntValidator { bottom: 1; top: 999 }
                selectByMouse: true
                onActiveFocusChanged: {
                    adjustRow._editing = activeFocus
                    if (activeFocus) selectAll()
                }
                onEditingFinished: {
                    const val = parseInt(text) || 1
                    const newValue = adjustRow.isMinutes ? val * 60 : val
                    Config.setNestedValue(adjustRow.configPath, Math.max(adjustRow.minValue, Math.min(adjustRow.maxValue, newValue)))
                }
            }
            StyledText {
                anchors.right: parent.right
                anchors.rightMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                visible: adjustRow.isMinutes
                text: "m"
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: root._colTextSecondary
                opacity: 0.7
            }
        }
        RippleButton {
            implicitWidth: 28; implicitHeight: 28
            buttonRadius: Appearance.rounding.full
            colBackground: "transparent"
            colBackgroundHover: root._colLayerHover
            colRipple: root._colLayerActive
            enabled: adjustRow.currentValue < adjustRow.maxValue
            onClicked: Config.setNestedValue(adjustRow.configPath, Math.min(adjustRow.maxValue, adjustRow.currentValue + adjustRow.step))
            contentItem: MaterialSymbol {
                anchors.centerIn: parent
                text: "add"
                iconSize: 16
                color: enabled ? root._colText : root._colTextSecondary
            }
        }
    }

    StyledFlickable {
        id: flickable
        anchors.fill: parent
        // The settings face replaces the dial, keeping all duration controls
        // within the compact popup's normal height.
        contentHeight: (root.centerMode && contentColumn.implicitHeight <= flickable.height)
            ? flickable.height
            : contentColumn.implicitHeight
        clip: true
        interactive: contentColumn.implicitHeight > flickable.height

        ColumnLayout {
            id: contentColumn
            width: flickable.width
            spacing: 0
            // Center vertically via y offset — safe from polish loops because
            // implicitHeight here is the column's own intrinsic size (no spacers),
            // and flickable.height is an external reference that doesn't depend on us.
            y: (root.centerMode && implicitHeight < flickable.height)
                ? Math.max(0, (flickable.height - implicitHeight) / 2)
                : 0

            // Open orbital focus arc: intentionally not a generic 360° timer
            // ring. The bottom gap carries the session rhythm and keeps the time
            // readout visually lighter in compact Dashboard layouts.
            Item {
                id: focusDial
                visible: !root.settingsOpen
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: root.compactMode
                    ? Math.min(184, Math.max(146,
                        Math.min(flickable.width * 0.52, flickable.height * 0.54)))
                    : 190
                Layout.preferredHeight: Layout.preferredWidth
                Layout.bottomMargin: 2

                readonly property real rawProgress:
                    TimerService.pomodoroLapDuration > 0
                        ? Math.max(0, Math.min(1,
                            TimerService.pomodoroSecondsLeft
                                / TimerService.pomodoroLapDuration))
                        : 0
                property real displayProgress: rawProgress
                readonly property real arcRadius:
                    Math.max(36, Math.min(width, height) / 2 - 13)
                readonly property real startAngle: 135
                readonly property real sweepAngle: 270

                Behavior on displayProgress {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation {
                        duration: 220
                        easing.type: Easing.OutCubic
                    }
                }

                Shape {
                    anchors.fill: parent
                    antialiasing: true

                    ShapePath {
                        fillColor: "transparent"
                        strokeColor: root._colTrack
                        strokeWidth: 7
                        capStyle: ShapePath.RoundCap

                        PathAngleArc {
                            centerX: focusDial.width / 2
                            centerY: focusDial.height / 2
                            radiusX: focusDial.arcRadius
                            radiusY: focusDial.arcRadius
                            startAngle: focusDial.startAngle
                            sweepAngle: focusDial.sweepAngle
                        }
                    }

                    ShapePath {
                        fillColor: "transparent"
                        strokeColor: root._colAccent
                        strokeWidth: 7
                        capStyle: ShapePath.RoundCap

                        PathAngleArc {
                            centerX: focusDial.width / 2
                            centerY: focusDial.height / 2
                            radiusX: focusDial.arcRadius
                            radiusY: focusDial.arcRadius
                            startAngle: focusDial.startAngle
                            sweepAngle: focusDial.sweepAngle
                                * focusDial.displayProgress
                        }
                    }
                }

                Rectangle {
                    readonly property real angle:
                        (focusDial.startAngle
                            + focusDial.sweepAngle * focusDial.displayProgress)
                            * Math.PI / 180
                    width: 11
                    height: 11
                    radius: width / 2
                    color: root._colAccent
                    visible: focusDial.displayProgress > 0.002
                    x: focusDial.width / 2
                        + focusDial.arcRadius * Math.cos(angle) - width / 2
                    y: focusDial.height / 2
                        + focusDial.arcRadius * Math.sin(angle) - height / 2

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width + 8
                        height: width
                        radius: width / 2
                        color: ColorUtils.transparentize(root._colAccent, 0.78)
                        z: -1
                    }
                }

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 2

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: {
                            const minutes = Math.floor(
                                TimerService.pomodoroSecondsLeft / 60)
                                .toString().padStart(2, '0')
                            const seconds = Math.floor(
                                TimerService.pomodoroSecondsLeft % 60)
                                .toString().padStart(2, '0')
                            return `${minutes}:${seconds}`
                        }
                        font.pixelSize: Math.round(
                            (root.compactMode ? 36 : 39)
                                * Appearance.fontSizeScale)
                        font.weight: Font.Medium
                        font.family: Appearance.font.family.numbers
                        color: root._colText
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: TimerService.pomodoroLongBreak
                            ? Translation.tr("Long break")
                            : TimerService.pomodoroBreak
                                ? Translation.tr("Break")
                                : Translation.tr("Focus")
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.Medium
                        color: root._colTextSecondary
                    }

                    Row {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 8
                        spacing: 5

                        Repeater {
                            model: Math.max(1,
                                TimerService.cyclesBeforeLongBreak)

                            Rectangle {
                                required property int index
                                readonly property bool current:
                                    index === TimerService.pomodoroCycle
                                readonly property bool complete:
                                    index < TimerService.pomodoroCycle
                                width: current ? 15 : 5
                                height: 5
                                radius: height / 2
                                color: current || complete
                                    ? root._colAccent : root._colTrack

                                Behavior on width {
                                    enabled: Appearance.animationsEnabled
                                    NumberAnimation {
                                        duration: Appearance.animation.elementMoveFast.duration
                                    }
                                }
                                Behavior on color {
                                    enabled: Appearance.animationsEnabled
                                    ColorAnimation {
                                        duration: Appearance.animation.elementMoveFast.duration
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Start/Pause + Reset buttons
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 6
                Layout.rightMargin: 6
                spacing: 10

                Item { Layout.fillWidth: true }

                RippleButton {
                    contentItem: StyledText {
                        anchors.centerIn: parent
                        horizontalAlignment: Text.AlignHCenter
                        text: TimerService.pomodoroRunning ? Translation.tr("Pause") : (TimerService.pomodoroSecondsLeft === TimerService.focusTime) ? Translation.tr("Start") : Translation.tr("Resume")
                        color: TimerService.pomodoroRunning
                            ? (Appearance.zzzEverywhere ? Appearance.zzz.onSticker
                                : Appearance.inirEverywhere ? Appearance.inir.colText
                                : Appearance.auroraEverywhere ? Appearance.colors.colOnLayer2 : Appearance.colors.colOnSecondaryContainer)
                            : Appearance.colors.colOnPrimary
                        Behavior on color {
                            enabled: Appearance.animationsEnabled
                            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
                        }
                    }
                    implicitHeight: 35
                    implicitWidth: 90
                    buttonRadius: Appearance.zzzEverywhere ? Appearance.zzz.controlRadius : Appearance.rounding.full
                    font.pixelSize: Appearance.font.pixelSize.larger
                    onClicked: TimerService.togglePomodoro()
                    colBackground: TimerService.pomodoroRunning
                        ? (Appearance.zzzEverywhere ? Appearance.zzz.sticker
                            : Appearance.inirEverywhere ? Appearance.inir.colLayer2
                            : Appearance.auroraEverywhere ? Appearance.aurora.colElevatedSurface : Appearance.colors.colSecondaryContainer)
                        : Appearance.colors.colPrimary
                    colBackgroundHover: TimerService.pomodoroRunning
                        ? (Appearance.zzzEverywhere ? Appearance.colors.colPrimaryHover
                            : Appearance.inirEverywhere ? Appearance.inir.colLayer2Hover
                            : Appearance.auroraEverywhere ? Appearance.aurora.colElevatedSurfaceHover : Appearance.colors.colSecondaryContainerHover)
                        : Appearance.colors.colPrimaryHover
                    colRipple: TimerService.pomodoroRunning
                        ? (Appearance.zzzEverywhere ? Appearance.colors.colPrimaryActive
                            : Appearance.inirEverywhere ? Appearance.inir.colLayer2Active
                            : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceActive : Appearance.colors.colSecondaryContainerActive)
                        : Appearance.colors.colPrimaryActive
                }

                RippleButton {
                    implicitHeight: 35
                    implicitWidth: 90

                    onClicked: TimerService.resetPomodoro()
                    enabled: (TimerService.pomodoroSecondsLeft < TimerService.pomodoroLapDuration) || TimerService.pomodoroCycle > 0 || TimerService.pomodoroBreak

                    font.pixelSize: Appearance.font.pixelSize.larger
                    colBackground: Appearance.inirEverywhere ? Appearance.inir.colLayer2
                        : Appearance.auroraEverywhere ? Appearance.aurora.colElevatedSurface
                        : Appearance.colors.colErrorContainer
                    colBackgroundHover: Appearance.inirEverywhere ? Appearance.inir.colLayer2Hover
                        : Appearance.auroraEverywhere ? Appearance.aurora.colElevatedSurfaceHover
                        : Appearance.colors.colErrorContainerHover
                    colRipple: Appearance.inirEverywhere ? Appearance.inir.colLayer2Active
                        : Appearance.auroraEverywhere ? Appearance.aurora.colSubSurfaceActive
                        : Appearance.colors.colErrorContainerActive

                    contentItem: StyledText {
                        anchors.centerIn: parent
                        horizontalAlignment: Text.AlignHCenter
                        text: Translation.tr("Reset")
                        color: Appearance.inirEverywhere ? Appearance.inir.colText
                            : Appearance.auroraEverywhere ? Appearance.colors.colOnLayer2
                            : Appearance.colors.colOnErrorContainer
                    }
                }

                Item { Layout.fillWidth: true }

                RippleButton {
                    implicitWidth: 36
                    implicitHeight: 36
                    buttonRadius: height / 2
                    enabled: !TimerService.pomodoroRunning
                    colBackground: root.settingsOpen
                        ? Appearance.colors.colPrimaryContainer
                        : root._colLayer
                    colBackgroundHover: Appearance.colors.colPrimaryContainerHover
                    onClicked: root.settingsOpen = !root.settingsOpen

                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: root.settingsOpen ? "close" : "tune"
                        iconSize: 20
                        color: root.settingsOpen
                            ? Appearance.colors.colOnPrimaryContainer
                            : root._colText
                    }

                    StyledToolTip {
                        text: Translation.tr("Customize timer")
                    }
                }
            }

            // The compact settings face uses the dial's space in this viewport.
            Item {
                Layout.fillWidth: true
                Layout.leftMargin: 8
                Layout.rightMargin: 8
                Layout.topMargin: (root.settingsOpen && !TimerService.pomodoroRunning) ? 4 : 0
                Layout.preferredHeight: settingsInner.implicitHeight + 16
                Layout.maximumHeight: (root.settingsOpen && !TimerService.pomodoroRunning)
                    ? settingsInner.implicitHeight + 16
                    : 0
                clip: true

                Behavior on Layout.maximumHeight {
                    enabled: Appearance.animationsEnabled && !root.compactMode
                    animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: Appearance.angelEverywhere ? Appearance.angel.roundingNormal
                        : Appearance.inirEverywhere ? Appearance.inir.roundingNormal
                        : Appearance.rounding.normal
                    color: root._colLayer
                    border.width: 1
                    border.color: Appearance.angelEverywhere ? Appearance.angel.colBorder
                        : Appearance.inirEverywhere ? Appearance.inir.colBorder
                        : Appearance.colors.colLayer0Border
                }

                ColumnLayout {
                    id: settingsInner
                    anchors { fill: parent; margins: 8 }
                    spacing: 6

                    AdjustRow {
                        icon: "target"
                        label: Translation.tr("Focus")
                        currentValue: TimerService.focusTime
                        minValue: 60; maxValue: 7200; step: 300
                        configPath: "time.pomodoro.focus"
                        isMinutes: true
                    }
                    AdjustRow {
                        icon: "coffee"
                        label: Translation.tr("Break")
                        currentValue: TimerService.breakTime
                        minValue: 60; maxValue: 1800; step: 60
                        configPath: "time.pomodoro.breakTime"
                        isMinutes: true
                    }
                    AdjustRow {
                        icon: "weekend"
                        label: Translation.tr("Long break")
                        currentValue: TimerService.longBreakTime
                        minValue: 60; maxValue: 3600; step: 300
                        configPath: "time.pomodoro.longBreak"
                        isMinutes: true
                    }
                    AdjustRow {
                        icon: "replay"
                        label: Translation.tr("Cycles")
                        currentValue: TimerService.cyclesBeforeLongBreak
                        minValue: 1; maxValue: 10; step: 1
                        configPath: "time.pomodoro.cyclesBeforeLongBreak"
                        isMinutes: false
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: Appearance.angelEverywhere ? Appearance.angel.colBorder
                            : Appearance.inirEverywhere ? Appearance.inir.colBorder
                            : Appearance.colors.colOutlineVariant
                        opacity: 0.5
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        MaterialSymbol {
                            text: (Config.options?.sounds?.pomodoro ?? false) ? "volume_up" : "volume_off"
                            iconSize: 16
                            color: root._colTextSecondary
                            Layout.rightMargin: 6
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: Translation.tr("Sound")
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: root._colTextSecondary
                        }
                        Switch {
                            checked: Config.options?.sounds?.pomodoro ?? false
                            onCheckedChanged: Config.setNestedValue("sounds.pomodoro", checked)
                        }
                    }
                }
            }
        }
    }
}
