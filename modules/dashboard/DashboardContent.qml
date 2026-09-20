pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Qt5Compat.GraphicalEffects as GE
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.sidebarRight.events

Item {
    id: root

    property int screenWidth: 1920
    property int screenHeight: 1080
    property bool embeddedSurface: false
    property bool presentationActive: GlobalStates.dashboardOpen || GlobalStates.overviewOpen

    readonly property bool inirEverywhere: Appearance.inirEverywhere
    readonly property bool angelEverywhere: Appearance.angelEverywhere
    readonly property bool auroraEverywhere: Appearance.auroraEverywhere
    readonly property bool zzzEverywhere: Appearance.zzzEverywhere
    readonly property bool showHeader: Config.options?.dashboard?.showHeader ?? true

    property var _agendaEditEvent: null
    property var _agendaPrefillDate: null
    property bool _agendaDialogShown: false
    property bool _agendaDialogLoaded: false

    function openAgendaDialog(arg) {
        const isDate = arg instanceof Date
        root._agendaEditEvent = (arg && !isDate) ? arg : null
        root._agendaPrefillDate = isDate ? arg : null
        root._agendaDialogLoaded = true
        if (agendaDialogLoader.item) {
            if (root._agendaEditEvent) {
                agendaDialogLoader.item.loadEvent(root._agendaEditEvent)
            } else {
                agendaDialogLoader.item.resetForm()
                if (root._agendaPrefillDate)
                    agendaDialogLoader.item.eventDate = root._agendaPrefillDate
            }
        }
        root._agendaDialogShown = true
    }

    readonly property string wallpaperUrl: Wallpapers.effectiveWallpaperUrl
    readonly property bool useWallpaperBackdrop:
        root.auroraEverywhere && !root.inirEverywhere
        && !Appearance.gameModeMinimal && root.wallpaperUrl.length > 0

    ColorQuantizer {
        id: wallpaperColorQuantizer
        source: (Appearance.auroraEverywhere || Appearance.angelEverywhere)
            ? root.wallpaperUrl : ""
        depth: 0
        rescaleSize: 10
    }

    readonly property color wallpaperDominantColor:
        wallpaperColorQuantizer?.colors?.[0] ?? Appearance.colors.colPrimary
    readonly property QtObject blendedColors: AdaptedMaterialScheme {
        color: ColorUtils.mix(root.wallpaperDominantColor,
            Appearance.colors.colPrimaryContainer, 0.8)
            || Appearance.colors.colSecondaryContainer
    }

    StyledRectangularShadow {
        target: background
        visible: !root.embeddedSurface
            && (Appearance.angelEverywhere
                || (!root.inirEverywhere && !root.auroraEverywhere))
            && !Appearance.gameModeMinimal
    }

    ZzzPlate {
        anchors.fill: background
        visible: !root.embeddedSurface && Appearance.zzzEverywhere
        fillColor: Appearance.colors.colLayer0
        strokeColor: Appearance.zzz.hairlineStrong
        strokeWidth: Appearance.zzz.hairlineThick
        chamfer: Appearance.zzz.cutCorner
    }

    Rectangle {
        id: background
        anchors.fill: parent
        clip: true

        color: root.embeddedSurface ? "transparent"
            : Appearance.zzzEverywhere ? "transparent"
            : root.inirEverywhere ? Appearance.inir.colLayer0
            : root.auroraEverywhere
                ? ColorUtils.applyAlpha(
                    root.blendedColors?.colLayer0 ?? Appearance.colors.colLayer0, 1)
                : Appearance.colors.colLayer0

        radius: root.embeddedSurface ? 0
            : Appearance.zzzEverywhere ? Appearance.zzz.panelRadius
            : root.angelEverywhere ? Appearance.angel.roundingLarge
            : root.inirEverywhere ? Appearance.inir.roundingLarge
            : Appearance.rounding.large

        border.width: root.embeddedSurface || Appearance.zzzEverywhere ? 0 : 1
        border.color: Appearance.zzzEverywhere ? Appearance.zzz.hairlineStrong
            : root.angelEverywhere ? Appearance.angel.colBorder
            : root.inirEverywhere ? Appearance.inir.colBorder
            : root.auroraEverywhere ? Appearance.aurora.colTooltipBorder
            : Appearance.colors.colLayer0Border

        layer.enabled: !root.embeddedSurface
            && (root.useWallpaperBackdrop
                || (root.zzzEverywhere && !Appearance.gameModeMinimal))
        layer.effect: GE.OpacityMask {
            maskSource: Rectangle {
                width: background.width
                height: background.height
                radius: background.radius
            }
        }

        Image {
            id: blurredWallpaper
            anchors.centerIn: parent
            width: root.screenWidth
            height: root.screenHeight
            visible: !root.embeddedSurface && root.useWallpaperBackdrop
            source: root.useWallpaperBackdrop ? root.wallpaperUrl : ""
            fillMode: Image.PreserveAspectCrop
            cache: true
            sourceSize.width: root.screenWidth
            sourceSize.height: root.screenHeight
            asynchronous: true
            layer.enabled: Appearance.effectsEnabled
                && root.auroraEverywhere && !root.inirEverywhere
            layer.effect: MultiEffect {
                source: blurredWallpaper
                anchors.fill: source
                saturation: root.angelEverywhere
                    ? Appearance.angel.blurSaturation
                    : (Appearance.effectsEnabled ? 0.2 : 0)
                blurEnabled: Appearance.effectsEnabled
                blurMax: 64
                blur: Appearance.effectsEnabled ? 1 : 0
            }
            Rectangle {
                anchors.fill: parent
                color: root.angelEverywhere
                    ? ColorUtils.transparentize(
                        root.blendedColors?.colLayer0
                            ?? Appearance.colors.colLayer0Base,
                        Appearance.angel.overlayOpacity)
                    : ColorUtils.transparentize(
                        root.blendedColors?.colLayer0
                            ?? Appearance.colors.colLayer0Base,
                        Appearance.aurora.overlayTransparentize)
            }
        }

        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: Appearance.angel.insetGlowHeight
            visible: !root.embeddedSurface && root.angelEverywhere
            color: Appearance.angel.colInsetGlow
            z: 10
        }

        ZzzPanelBackdrop {
            anchors.fill: parent
            visible: !root.embeddedSurface
            label: "AUTONOMIC STRIDER"
            index: "52"
            ghostText: "DASH"
            accentColor: Appearance.zzz.accent
            burstTriad: true
            burstScale: 0.52
            showTicks: false
            showGrid: false
            horizontalBias: 0.1
            verticalBias: -0.06
            ghostWidthFactor: 0.78
            ghostStrength: 0.7
            z: 0
        }

        ColumnLayout {
            id: mainColumn
            readonly property bool compact:
                (Config.options?.dashboard?.appearance?.density ?? "comfortable")
                    === "compact"
            anchors.fill: parent
            anchors.margins: root.embeddedSurface
                ? 0 : (compact ? 12 : 16)
            spacing: compact ? 8 : 12

            DashboardHeader {
                id: dashboardHeader
                Layout.fillWidth: true
                visible: root.showHeader
                editMode: dashboardCanvas.editMode
                onEditModeRequested:
                    dashboardCanvas.editMode = !dashboardCanvas.editMode
            }

            DashboardCanvas {
                id: dashboardCanvas
                Layout.fillWidth: true
                Layout.fillHeight: true
                presentationActive: root.presentationActive
                showStandaloneEditButton: !root.showHeader
                onRequestEventsDialog: event => root.openAgendaDialog(event)
            }
        }

        Loader {
            id: agendaDialogLoader
            anchors.fill: parent
            z: 200
            active: root._agendaDialogLoaded
            sourceComponent: EventsDialog {}
            onLoaded: {
                item.show = Qt.binding(() => root._agendaDialogShown)
                if (root._agendaEditEvent) {
                    item.loadEvent(root._agendaEditEvent)
                } else {
                    item.resetForm()
                    if (root._agendaPrefillDate)
                        item.eventDate = root._agendaPrefillDate
                }
                item.forceActiveFocus()
            }
            Connections {
                target: agendaDialogLoader.item
                function onDismiss() {
                    root._agendaDialogShown = false
                }
            }
        }
    }
}
