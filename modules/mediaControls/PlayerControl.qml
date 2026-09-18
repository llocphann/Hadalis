pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Qt5Compat.GraphicalEffects as GE
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.common.models
import qs.services
import "root:"

Item {
    id: root
    required property MprisPlayer player
    required property list<real> visualizerPoints
    // CAVA's shared service adapts this ceiling to the real signal. Keep a
    // conservative fallback for external/legacy callers, while active owners
    // pass the shared normalization ceiling so quiet-but-real audio stays visible.
    property real visualizerMaxValue: 1000
    property real radius: Appearance.rounding.large
    // Track-change slide direction: +1 next/forward (new content enters from the
    // right), -1 previous (enters from the left). Set by the prev/next handlers
    // before the track advances so the cross-slide reads as directed.
    property int slideDirection: 1
    
    // Use centralized YtMusic detection from MprisController
    readonly property bool isYtMusicPlayer: {
        if (!player) return false
        // Direct match with YtMusic.mpvPlayer
        if (YtMusic.mpvPlayer && player === YtMusic.mpvPlayer) return true
        // Use MprisController's detection for consistency
        return MprisController._isYtMusicMpv(player)
    }
    
    function doTogglePlaying(): void {
        if (isYtMusicPlayer) {
            YtMusic.togglePlaying()
        } else {
            player?.togglePlaying()
        }
    }
    
    function doPrevious(): void {
        root.slideDirection = -1
        MprisController.previousForPlayer(root.player)
    }
    
    function doNext(): void {
        root.slideDirection = 1
        MprisController.nextForPlayer(root.player)
    }

    function focusPrimaryControl(): void {
        playPauseButton.forceActiveFocus()
    }
    
    // Screen position for aurora glass effect
    property real screenX: 0
    property real screenY: 0
    readonly property var surfaceScreen: root.QsWindow.window?.screen ?? Quickshell.screens[0] ?? null
    readonly property string surfaceWallpaperUrl: {
        const _dep1 = WallpaperListener.multiMonitorEnabled
        const _dep2 = WallpaperListener.effectivePerMonitor
        const _dep3 = Wallpapers.effectiveWallpaperUrl
        return WallpaperListener.wallpaperUrlForScreen(root.surfaceScreen)
    }

    readonly property string effectiveArtUrl: isYtMusicPlayer ? YtMusic.currentThumbnail : MprisController.effectiveArtUrl(player)
    readonly property string effectiveTitle: isYtMusicPlayer ? YtMusic.currentTitle : (player?.trackTitle ?? "")
    readonly property string effectiveArtist: isYtMusicPlayer ? YtMusic.currentArtist : (player?.trackArtist ?? "")
    // Only the artwork identity may trigger cover motion. Title/artist often
    // arrive before the real art URL and caused the same cover to slide twice.
    readonly property string mediaTransitionKey: (root.effectiveArtUrl ?? "").split("?")[0].split("#")[0]
    property string artDownloadLocation: Directories.coverArt
    readonly property string resolverDisplaySource: artworkResolver.displaySource
    readonly property bool downloaded: root.displayedArtFilePath !== ""
    property string displayedArtFilePath: ""
    readonly property bool effectiveCanGoPrevious: isYtMusicPlayer ? YtMusic.canGoPrevious : MprisController.canGoPreviousForPlayer(root.player)
    readonly property bool effectiveCanGoNext: isYtMusicPlayer ? YtMusic.canGoNext : MprisController.canGoNextForPlayer(root.player)

    function checkAndDownloadArt() {
        artworkResolver.refresh()
    }

    Connections {
        target: root.player
        function onTrackArtUrlChanged() {
            if (!root.isYtMusicPlayer)
                root.checkAndDownloadArt()
        }
        function onTrackTitleChanged() {
            Qt.callLater(root.checkAndDownloadArt)
        }
        function onTrackArtistChanged() {
            Qt.callLater(root.checkAndDownloadArt)
        }
        function onTrackAlbumChanged() {
            Qt.callLater(root.checkAndDownloadArt)
        }
    }

    onResolverDisplaySourceChanged: {
        const src = root.resolverDisplaySource
        if (src && src.length > 0) {
            clearArtTimer.stop()
            root.displayedArtFilePath = src
        } else {
            clearArtTimer.restart()
        }
    }

    MediaArtworkResolver {
        id: artworkResolver
        sourceUrl: root.effectiveArtUrl
        title: root.effectiveTitle
        artist: root.effectiveArtist
        album: root.player?.trackAlbum ?? ""
        cacheDirectory: root.artDownloadLocation
    }

    Timer {
        id: clearArtTimer
        interval: 1600
        onTriggered: {
            if (!root.resolverDisplaySource || root.resolverDisplaySource.length === 0)
                root.displayedArtFilePath = ""
        }
    }

    Component.onCompleted: {
        if (root.resolverDisplaySource && root.resolverDisplaySource.length > 0)
            root.displayedArtFilePath = root.resolverDisplaySource
    }

    Timer {
        running: root.player?.playbackState === MprisPlaybackState.Playing
        interval: 1000
        repeat: true
        onTriggered: root.player?.positionChanged()
    }

    ColorQuantizer {
        id: colorQuantizer
        source: root.displayedArtFilePath
        depth: 0
        rescaleSize: 1
    }

    property color artDominantColor: ColorUtils.mix(
        colorQuantizer?.colors[0] ?? Appearance.colors.colPrimary,
        Appearance.colors.colPrimaryContainer, 0.7
    )

    property QtObject blendedColors: AdaptedMaterialScheme { color: root.artDominantColor }

    StyledRectangularShadow { target: card }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: parent.width - Appearance.sizes.elevationMargin
        height: parent.height - Appearance.sizes.elevationMargin
        radius: root.radius
        Behavior on radius {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
        color: blendedColors?.colLayer0 ?? Appearance.colors.colLayer0
        Behavior on color {
            enabled: Appearance.animationsEnabled
            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
        border.width: 0
        Behavior on border.width {
            enabled: Appearance.animationsEnabled
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
        border.color: "transparent"
        Behavior on border.color {
            enabled: Appearance.animationsEnabled
            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
        }
        clip: true

        layer.enabled: true
        layer.effect: GE.OpacityMask {
            maskSource: Rectangle { width: card.width; height: card.height; radius: card.radius }
        }

        // Card-level art wash follows the loaded art without sliding. Only the
        // visible cover moves, so a track change has one clear motion.
        MediaCrossSlideImage {
            id: bgArt
            anchors.fill: parent
            source: root.displayedArtFilePath
            transitionKey: "player-card-wash"
            downloaded: root.downloaded
            slideDirection: root.slideDirection
            animateChanges: false
            artRadius: card.radius
            placeholderColor: blendedColors?.colLayer0 ?? Appearance.colors.colLayer0
            iconColor: "transparent"
            opacity: 0.5
            visible: root.displayedArtFilePath !== ""
            effectEnabled: Appearance.effectsEnabled
            blurEnabled: true
            blur: 0.15
            blurMax: 16
            saturation: 0.3
        }

        // Gradient overlay for Material only — a material-tinted wash that
        // clashes with the flat ZZZ console plate, so exclude it there.
        Rectangle {
            anchors.fill: parent
            visible: true
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop { position: 0.35; color: ColorUtils.transparentize(blendedColors?.colLayer0 ?? Appearance.colors.colLayer0, 0.3) }
                GradientStop { position: 1.0; color: ColorUtils.transparentize(blendedColors?.colLayer0 ?? Appearance.colors.colLayer0, 0.15) }
            }
        }

        // Visualizer at bottom
        WaveVisualizer {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 35
            live: root.player?.isPlaying ?? false
            points: root.visualizerPoints
            maxVisualizerValue: Math.max(1, root.visualizerMaxValue)
            smoothing: 2
            color: ColorUtils.transparentize(
                blendedColors?.colPrimary ?? Appearance.colors.colPrimary, 0.6)
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12

            // Cover art — direction-aware cross-slide (one leaves, one enters)
            MediaCrossSlideImage {
                id: coverArtContainer
                Layout.preferredWidth: card.height - 24
                Layout.preferredHeight: card.height - 24
                artRadius: Appearance.rounding.small
                source: root.displayedArtFilePath
                transitionKey: root.mediaTransitionKey
                downloaded: root.downloaded
                slideDirection: root.slideDirection
                placeholderColor: blendedColors?.colLayer1 ?? Appearance.colors.colLayer1
                iconColor: blendedColors?.colSubtext ?? Appearance.colors.colSubtext
                iconSize: 32
            }

            // Info & controls
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 4

                // Title
                StyledText {
                    Layout.fillWidth: true
                    text: StringUtils.cleanMusicTitle(root.isYtMusicPlayer ? YtMusic.currentTitle : root.player?.trackTitle) || "—"
                    font.pixelSize: Appearance.font.pixelSize.large
                    font.weight: Font.Medium
                    font.italic: false
                    color: blendedColors?.colOnLayer0 ?? Appearance.colors.colOnLayer0
                    Behavior on color {
                        enabled: Appearance.animationsEnabled
                        ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                    }
                    elide: Text.ElideRight
                    animateChange: true
                    animationDistanceX: root.slideDirection * 8
                    animationDistanceY: 0
                }

                // Artist
                StyledText {
                    Layout.fillWidth: true
                    text: root.isYtMusicPlayer ? YtMusic.currentArtist : (root.player?.trackArtist || "")
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: blendedColors?.colSubtext ?? Appearance.colors.colSubtext
                    Behavior on color {
                        enabled: Appearance.animationsEnabled
                        ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                    }
                    elide: Text.ElideRight
                    visible: text !== ""
                    animateChange: true
                    animationDistanceX: root.slideDirection * 8
                    animationDistanceY: 0
                }

                Item { Layout.fillHeight: true }

                // Progress bar
                Item {
                    Layout.fillWidth: true
                    implicitHeight: 16

                    Loader {
                        id: seekLoader
                        anchors.fill: parent
                        active: root.player?.canSeek ?? false
                        sourceComponent: StyledSlider {
                            Accessible.name: Translation.tr("Playback position")
                            configuration: StyledSlider.Configuration.Wavy
                            wavy: root.player?.isPlaying ?? false
                            animateWave: root.player?.isPlaying ?? false
                            highlightColor: blendedColors?.colPrimary ?? Appearance.colors.colPrimary
                            trackColor: blendedColors?.colSecondaryContainer ?? Appearance.colors.colSecondaryContainer
                            handleColor: blendedColors?.colPrimary ?? Appearance.colors.colPrimary
                            value: root.player?.length > 0 ? root.player.position / root.player.length : 0
                            onMoved: root.player.position = value * root.player.length
                            scrollable: true
                        }
                    }

                    Loader {
                        anchors.fill: parent
                        active: !(root.player?.canSeek ?? false)
                        sourceComponent: StyledProgressBar {
                            wavy: root.player?.isPlaying ?? false
                            animateWave: root.player?.isPlaying ?? false
                            highlightColor: blendedColors?.colPrimary ?? Appearance.colors.colPrimary
                            trackColor: blendedColors?.colSecondaryContainer ?? Appearance.colors.colSecondaryContainer
                            value: root.player?.length > 0 ? root.player.position / root.player.length : 0
                        }
                    }

                    KeyboardFocusRing {
                        anchors.fill: parent
                        focusVisible: seekLoader.item?.visualFocus ?? false
                    }
                }

                // Time + controls
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    StyledText {
                        text: StringUtils.friendlyTimeForSeconds(root.player?.position ?? 0)
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        font.family: Appearance.font.family.numbers
                        color: blendedColors?.colOnLayer0 ?? Appearance.colors.colOnLayer0
                        Behavior on color {
                            enabled: Appearance.animationsEnabled
                            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    RippleButton {
                        implicitWidth: 32; implicitHeight: 32
                        buttonText: Translation.tr("Previous")
                        enabled: root.effectiveCanGoPrevious
                        buttonRadius: Appearance.rounding.full
                        colBackground: "transparent"
                        colBackgroundHover: ColorUtils.transparentize(
                            blendedColors?.colLayer1 ?? Appearance.colors.colLayer1, 0.5)
                        colRipple: blendedColors?.colLayer1Active ?? Appearance.colors.colLayer1Active
                        onClicked: root.doPrevious()
                        contentItem: Item {
                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "skip_previous"; iconSize: 22; fill: 1
                                color: blendedColors?.colOnLayer0 ?? Appearance.colors.colOnLayer0
                                Behavior on color {
                                    enabled: Appearance.animationsEnabled
                                    ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                                }
                            }
                        }
                        StyledToolTip { text: Translation.tr("Previous") }
                    }

                    RippleButton {
                        id: playPauseButton
                        implicitWidth: 40; implicitHeight: 40
                        buttonText: root.player?.isPlaying ? Translation.tr("Pause") : Translation.tr("Play")
                        buttonRadius: Appearance.rounding.full
                        colBackground: "transparent"
                        colBackgroundHover: Appearance.colors.colLayer1Hover
                        colRipple: Appearance.colors.colLayer1Active
                        onClicked: root.doTogglePlaying()

                        contentItem: Item {
                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: root.player?.isPlaying ? "pause" : "play_arrow"
                                iconSize: 24; fill: 1
                                color: Appearance.colors.colOnLayer1
                                Behavior on color {
                                    enabled: Appearance.animationsEnabled
                                    animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                                }
                            }
                        }
                        StyledToolTip { text: root.player?.isPlaying ? Translation.tr("Pause") : Translation.tr("Play") }
                    }

                    RippleButton {
                        implicitWidth: 32; implicitHeight: 32
                        buttonText: Translation.tr("Next")
                        enabled: root.effectiveCanGoNext
                        buttonRadius: Appearance.rounding.full
                        colBackground: "transparent"
                        colBackgroundHover: ColorUtils.transparentize(
                            blendedColors?.colLayer1 ?? Appearance.colors.colLayer1, 0.5)
                        colRipple: blendedColors?.colLayer1Active ?? Appearance.colors.colLayer1Active
                        onClicked: root.doNext()
                        contentItem: Item {
                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "skip_next"; iconSize: 22; fill: 1
                                color: blendedColors?.colOnLayer0 ?? Appearance.colors.colOnLayer0
                                Behavior on color {
                                    enabled: Appearance.animationsEnabled
                                    ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                                }
                            }
                        }
                        StyledToolTip { text: Translation.tr("Next") }
                    }

                    Item { Layout.fillWidth: true }

                    StyledText {
                        text: StringUtils.friendlyTimeForSeconds(root.player?.length ?? 0)
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        font.family: Appearance.font.family.numbers
                        color: blendedColors?.colOnLayer0 ?? Appearance.colors.colOnLayer0
                        Behavior on color {
                            enabled: Appearance.animationsEnabled
                            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                        }
                    }
                }
            }
        }
    }
}
