pragma ComponentBehavior: Bound

import qs
import qs.services
import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Wayland

// Loaded by URL only when the Hadalis-patched Quickshell capability marker is
// present. Keeping this in a separate file lets stock Quickshell continue to
// parse Overview and fall back to WindowPreviewService snapshots.
Item {
    id: root

    property int windowId: -1
    property var windowData: null
    property bool presentationActive: false
    property bool showPreviews: true
    property bool hovered: false
    property bool focused: false

    readonly property string previewKey: windowId >= 0 ? "niri:" + String(windowId) : ""
    readonly property bool mediaPlayingHint: {
        MprisController._playbackStateVersion
        return AdaptivePreviewService.mediaPlayingForWindow(
            root.windowData, MprisController.displayPlayers)
    }
    readonly property bool previewBackendAvailable:
        AdaptivePreviewService.niriLiveBackendAvailable && captureSource.ready
    readonly property bool captureActive:
        root.presentationActive
        && root.showPreviews
        && root.previewBackendAvailable
        && !GameMode.active
        && !RecorderStatus.isRecording

    property real activityScore: 0.0
    property int motionStreak: 0
    property bool liveClaim: false
    property string _registeredPreviewKey: ""

    readonly property real qualifiedActivityScore:
        (root.previewLive || root.motionStreak >= AdaptivePreviewService.motionSamplesRequired)
            ? root.activityScore : 0.0

    readonly property bool rawLiveWanted: AdaptivePreviewService.wantsLive(
        root.captureActive,
        root.previewBackendAvailable,
        root.hovered,
        root.focused,
        root.mediaPlayingHint,
        root.qualifiedActivityScore)

    readonly property bool previewLive:
        root.captureActive
        && root.liveClaim
        && AdaptivePreviewService.isLive(root.previewKey)

    readonly property bool hasContent: screencopy.hasContent
    readonly property real frameActivity: screencopy.frameActivity
    readonly property size sourceSize: screencopy.sourceSize

    function _publishLiveClaim(): void {
        const key = root.previewKey
        if (root._registeredPreviewKey.length > 0
                && root._registeredPreviewKey !== key)
            AdaptivePreviewService.removeLiveClaim(root._registeredPreviewKey)

        root._registeredPreviewKey = key
        if (key.length === 0)
            return

        AdaptivePreviewService.setLiveClaim(
            key,
            root.liveClaim && root.captureActive,
            root.hovered,
            root.focused,
            root.mediaPlayingHint,
            root.qualifiedActivityScore)
    }

    function _setLiveClaim(value): void {
        root.liveClaim = !!value
        root._publishLiveClaim()
    }

    function _reevaluateLiveIntent(): void {
        if (!root.captureActive || AdaptivePreviewService.mode === "snapshot") {
            livePromotionTimer.stop()
            liveCooldownTimer.stop()
            root._setLiveClaim(false)
            return
        }

        if (root.rawLiveWanted) {
            liveCooldownTimer.stop()
            const immediate = AdaptivePreviewService.mode === "live"
                || (root.hovered && AdaptivePreviewService.liveOnHover)
                || AdaptivePreviewService.promotionDelayMs <= 0
            if (immediate) {
                livePromotionTimer.stop()
                root._setLiveClaim(true)
            } else if (!root.liveClaim) {
                livePromotionTimer.restart()
            } else {
                root._publishLiveClaim()
            }
            return
        }

        livePromotionTimer.stop()
        if (!root.liveClaim || AdaptivePreviewService.cooldownMs <= 0) {
            liveCooldownTimer.stop()
            root._setLiveClaim(false)
        } else {
            liveCooldownTimer.restart()
        }
    }

    function _recordActivity(sampleValue): void {
        let sample = Number(sampleValue)
        if (!Number.isFinite(sample))
            sample = 0
        sample = Math.max(0, Math.min(1, sample))

        const smoothing = AdaptivePreviewService.activitySmoothing
        root.activityScore = root.activityScore * (1 - smoothing) + sample * smoothing

        if (sample >= AdaptivePreviewService.motionSampleThreshold)
            root.motionStreak = Math.min(root.motionStreak + 1, 1000)
        else
            root.motionStreak = 0

        root._reevaluateLiveIntent()
        root._publishLiveClaim()
    }

    onRawLiveWantedChanged: root._reevaluateLiveIntent()
    onHoveredChanged: {
        root._reevaluateLiveIntent()
        root._publishLiveClaim()
    }
    onFocusedChanged: {
        root._reevaluateLiveIntent()
        root._publishLiveClaim()
    }
    onMediaPlayingHintChanged: {
        root._reevaluateLiveIntent()
        root._publishLiveClaim()
    }
    onCaptureActiveChanged: {
        if (!root.captureActive) {
            root.activityScore = 0
            root.motionStreak = 0
        }
        root._reevaluateLiveIntent()
    }
    onPreviewKeyChanged: root._publishLiveClaim()

    ForeignToplevelCaptureSource {
        id: captureSource
        identifier: root.windowId >= 0 ? String(root.windowId) : ""
    }

    Item {
        id: cropViewport
        anchors.fill: parent
        clip: true

        ScreencopyView {
            id: screencopy
            anchors.centerIn: parent

            captureSource: root.captureActive ? captureSource : null
            live: root.previewLive
            paintCursor: false

            readonly property real sourceAspect:
                sourceSize.height > 0 ? sourceSize.width / sourceSize.height : 1
            readonly property real targetAspect:
                cropViewport.height > 0 ? cropViewport.width / cropViewport.height : 1

            width: {
                if (!hasContent)
                    return cropViewport.width
                return sourceAspect > targetAspect
                    ? cropViewport.height * sourceAspect
                    : cropViewport.width
            }
            height: {
                if (!hasContent)
                    return cropViewport.height
                return sourceAspect > targetAspect
                    ? cropViewport.height
                    : cropViewport.width / sourceAspect
            }

            onFrameCaptured: root._recordActivity(frameActivity)
        }
    }

    Timer {
        id: probeTimer
        interval: AdaptivePreviewService.probeIntervalMs
        repeat: true
        running: root.captureActive
            && AdaptivePreviewService.mode === "adaptive"
            && !root.previewLive
        onTriggered: screencopy.captureFrame()
    }

    Timer {
        id: livePromotionTimer
        interval: AdaptivePreviewService.promotionDelayMs
        repeat: false
        onTriggered: {
            if (root.rawLiveWanted)
                root._setLiveClaim(true)
        }
    }

    Timer {
        id: liveCooldownTimer
        interval: AdaptivePreviewService.cooldownMs
        repeat: false
        onTriggered: {
            if (!root.rawLiveWanted)
                root._setLiveClaim(false)
        }
    }

    Connections {
        target: AdaptivePreviewService
        function onModeChanged(): void { root._reevaluateLiveIntent() }
        function onLiveOnHoverChanged(): void { root._reevaluateLiveIntent() }
        function onLiveFocusedWindowChanged(): void { root._reevaluateLiveIntent() }
        function onLiveMediaWindowsChanged(): void { root._reevaluateLiveIntent() }
        function onActivityPromotionThresholdChanged(): void { root._reevaluateLiveIntent() }
        function onMediaActivityPromotionThresholdChanged(): void { root._reevaluateLiveIntent() }
        function onMotionSamplesRequiredChanged(): void { root._reevaluateLiveIntent() }
    }

    Component.onCompleted: root._reevaluateLiveIntent()
    Component.onDestruction: {
        if (root._registeredPreviewKey.length > 0)
            AdaptivePreviewService.removeLiveClaim(root._registeredPreviewKey)
    }

    opacity: root.hasContent ? 1 : 0
    Behavior on opacity {
        enabled: Appearance.animationsEnabled
        NumberAnimation {
            duration: Appearance.animation.elementMoveFast.duration
            easing.type: Easing.OutCubic
        }
    }
}
