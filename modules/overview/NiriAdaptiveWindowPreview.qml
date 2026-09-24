pragma ComponentBehavior: Bound

import qs
import qs.services
import qs.modules.common
import QtQuick
import Quickshell
import Hadalis.NiriPreview 1.0

// Niri-only native preview surface.
//
// The existing PNG Image in OverviewNiriWidget remains underneath this item as
// an instant/failure fallback. This component is loaded by URL only when the
// package-owned capability marker is present, so systems without the native
// plugin never attempt to resolve Hadalis.NiriPreview.
Item {
    id: root

    property int windowId: -1
    property var windowData: null
    property bool presentationActive: false
    property bool showPreviews: true
    property bool hovered: false
    property bool focused: false

    readonly property string previewKey:
        root.windowId >= 0 ? "niri:" + String(root.windowId) : ""
    readonly property bool mediaPlayingHint: {
        MprisController._playbackStateVersion
        return AdaptivePreviewService.mediaPlayingForWindow(
            root.windowData, MprisController.displayPlayers)
    }
    readonly property int schedulingPriority:
        AdaptivePreviewService.priorityFor(
            root.hovered,
            root.focused,
            root.mediaPlayingHint,
            root.qualifiedActivityScore)

    readonly property bool probeActive:
        AdaptivePreviewService.isProbeActive(root.previewKey)
    readonly property bool backendAvailable:
        AdaptivePreviewService.niriLiveBackendAvailable && nativePreview.available

    property int motionStreak: 0
    property real activityScore: 0.0
    property bool liveClaim: false
    property string _registeredLiveKey: ""
    property string _registeredProbeKey: ""

    readonly property real qualifiedActivityScore:
        (root.previewLive
         || root.motionStreak >= AdaptivePreviewService.niriMotionSamples)
            ? root.activityScore : 0.0

    readonly property bool rawLiveWanted: AdaptivePreviewService.wantsLive(
        root.presentationActive && root.showPreviews,
        root.backendAvailable,
        root.hovered,
        root.focused,
        root.mediaPlayingHint,
        root.qualifiedActivityScore,
        true,
        AdaptivePreviewService.niriActivityPromotionThreshold,
        AdaptivePreviewService.niriMediaActivityPromotionThreshold,
        AdaptivePreviewService.niriFocusedActivityPromotionThreshold)

    readonly property bool previewLive:
        root.presentationActive
        && root.showPreviews
        && root.backendAvailable
        && root.liveClaim
        && AdaptivePreviewService.isLive(root.previewKey)

    // Native sessions are bounded: ordinary windows exist only while they own a
    // rotating probe slot; promoted windows keep the same session in live mode.
    readonly property bool captureActive:
        root.presentationActive
        && root.showPreviews
        && root.backendAvailable
        && (root.probeActive || root.previewLive || root.hovered)

    readonly property bool hasContent: nativePreview.hasContent
    readonly property real frameActivity: nativePreview.activity

    function _publishProbeCandidate(): void {
        const key = root.previewKey
        if (root._registeredProbeKey.length > 0
                && root._registeredProbeKey !== key)
            AdaptivePreviewService.removeProbeCandidate(root._registeredProbeKey)

        root._registeredProbeKey = key
        if (key.length === 0)
            return

        AdaptivePreviewService.setProbeCandidate(
            key,
            root.presentationActive
                && root.showPreviews
                && AdaptivePreviewService.niriLiveBackendAvailable
                && !root.previewLive,
            root.schedulingPriority)
    }

    function _publishLiveClaim(): void {
        const key = root.previewKey
        if (root._registeredLiveKey.length > 0
                && root._registeredLiveKey !== key)
            AdaptivePreviewService.removeLiveClaim(root._registeredLiveKey)

        root._registeredLiveKey = key
        if (key.length === 0)
            return

        AdaptivePreviewService.setLiveClaim(
            key,
            root.liveClaim
                && root.presentationActive
                && root.showPreviews
                && root.backendAvailable,
            root.hovered,
            root.focused,
            root.mediaPlayingHint,
            root.qualifiedActivityScore,
            "niri")
    }

    function _setLiveClaim(value): void {
        if (root.liveClaim === !!value) {
            root._publishLiveClaim()
            return
        }
        root.liveClaim = !!value
        root._publishLiveClaim()
        root._publishProbeCandidate()
    }

    function _reevaluateLiveIntent(): void {
        if (!root.presentationActive || !root.showPreviews
                || !root.backendAvailable
                || AdaptivePreviewService.mode === "snapshot") {
            promotionTimer.stop()
            silenceTimer.stop()
            root._setLiveClaim(false)
            return
        }

        if (root.rawLiveWanted) {
            const immediate = AdaptivePreviewService.mode === "live"
                || (root.hovered && AdaptivePreviewService.liveOnHover)
                || AdaptivePreviewService.promotionDelayMs <= 0
            if (immediate) {
                promotionTimer.stop()
                root._setLiveClaim(true)
            } else if (!root.liveClaim) {
                promotionTimer.restart()
            } else {
                root._publishLiveClaim()
            }

            if (AdaptivePreviewService.mode !== "live")
                silenceTimer.restart()
            return
        }

        promotionTimer.stop()
        root._setLiveClaim(false)
    }

    function _recordActivity(value): void {
        let sample = Number(value)
        if (!Number.isFinite(sample))
            sample = 0
        sample = Math.max(0, Math.min(1, sample))

        if (sample >= AdaptivePreviewService.niriMotionSampleThreshold) {
            root.motionStreak = Math.min(1000, root.motionStreak + 1)
            root.activityScore = Math.max(
                sample,
                root.activityScore * 0.55 + sample * 0.45)

            if (root.liveClaim || root.previewLive)
                silenceTimer.restart()
        } else {
            root.motionStreak = 0
            root.activityScore *= 0.55
        }

        root._reevaluateLiveIntent()
        root._publishProbeCandidate()
        root._publishLiveClaim()

        // In probe mode the first frame establishes a baseline. Keep exactly
        // one next ICC frame pending; Niri may wait indefinitely until content
        // changes, which makes static windows effectively free between probes.
        if (root.probeActive && !root.previewLive)
            Qt.callLater(function() { nativePreview.captureOnce() })
    }

    onRawLiveWantedChanged: root._reevaluateLiveIntent()
    onPreviewLiveChanged: {
        root._publishProbeCandidate()
        if (root.previewLive && AdaptivePreviewService.mode !== "live")
            silenceTimer.restart()
    }
    onProbeActiveChanged: {
        if (!root.probeActive && !root.liveClaim && !root.previewLive) {
            root.motionStreak = 0
            root.activityScore = 0
        }
    }
    onHoveredChanged: {
        root._reevaluateLiveIntent()
        root._publishProbeCandidate()
        root._publishLiveClaim()
    }
    onFocusedChanged: {
        root._reevaluateLiveIntent()
        root._publishProbeCandidate()
        root._publishLiveClaim()
    }
    onMediaPlayingHintChanged: {
        root._reevaluateLiveIntent()
        root._publishProbeCandidate()
        root._publishLiveClaim()
    }
    onPresentationActiveChanged: {
        root._publishProbeCandidate()
        root._reevaluateLiveIntent()
    }
    onShowPreviewsChanged: {
        root._publishProbeCandidate()
        root._reevaluateLiveIntent()
    }
    onBackendAvailableChanged: root._reevaluateLiveIntent()
    onPreviewKeyChanged: {
        root._publishProbeCandidate()
        root._publishLiveClaim()
    }

    NiriPreviewItem {
        id: nativePreview
        anchors.fill: parent
        windowId: Math.max(0, root.windowId)
        active: root.captureActive
        live: root.previewLive
        maxFps: AdaptivePreviewService.niriPreviewMaxFps
        onFrameCaptured: root._recordActivity(activity)
    }

    Timer {
        id: promotionTimer
        interval: AdaptivePreviewService.promotionDelayMs
        repeat: false
        onTriggered: {
            if (root.rawLiveWanted)
                root._setLiveClaim(true)
        }
    }

    Timer {
        id: silenceTimer
        interval: AdaptivePreviewService.niriStaticCooldownMs
        repeat: false
        onTriggered: {
            if (AdaptivePreviewService.mode === "live")
                return
            if (root.hovered) {
                restart()
                return
            }

            root.motionStreak = 0
            root.activityScore = 0
            root._setLiveClaim(false)
            root._publishProbeCandidate()
        }
    }

    Connections {
        target: AdaptivePreviewService
        function onModeChanged(): void { root._reevaluateLiveIntent() }
        function onLiveOnHoverChanged(): void { root._reevaluateLiveIntent() }
        function onLiveFocusedWindowChanged(): void { root._reevaluateLiveIntent() }
        function onLiveMediaWindowsChanged(): void { root._reevaluateLiveIntent() }
        function onNiriMotionSamplesChanged(): void { root._reevaluateLiveIntent() }
        function onNiriActivityPromotionThresholdChanged(): void {
            root._reevaluateLiveIntent()
        }
    }

    Component.onCompleted: {
        root._publishProbeCandidate()
        root._reevaluateLiveIntent()
    }
    Component.onDestruction: {
        if (root._registeredLiveKey.length > 0)
            AdaptivePreviewService.removeLiveClaim(root._registeredLiveKey)
        if (root._registeredProbeKey.length > 0)
            AdaptivePreviewService.removeProbeCandidate(root._registeredProbeKey)
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
