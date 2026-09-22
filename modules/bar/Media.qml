import qs.modules.common
import qs.modules.common.widgets
import qs.modules.mediaControls
import qs.services
import qs
import qs.modules.common.functions

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Io
import Quickshell.Wayland

Item {
    id: root

    CodeWorkflowRuntimeTarget {
        runtimeObject: root
        targetId: "bar/media"
        label: "Bar · Media"
        icon: "music_note"
        kind: "component"
        family: "ii"
        panelId: "iiBar"
        parentId: "bar"
        depth: 1
        sourcePath: "modules/bar/Media.qml"
    }

    property bool borderless: Config.options?.bar?.borderless ?? false
    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    readonly property string cleanedTitle: StringUtils.cleanMusicTitle(activePlayer?.trackTitle) || Translation.tr("No media")
    readonly property string fullTrackText: `${cleanedTitle}${activePlayer?.trackArtist ? ' • ' + activePlayer.trackArtist : ''}`
    readonly property string popupMode: Config.options?.media?.popupMode ?? "dock"
    readonly property bool showVerboseLabel: Config.options?.bar?.verbose ?? true
    readonly property bool hasTrackMetadata: (activePlayer?.trackTitle?.length ?? 0) > 0
        || (activePlayer?.trackArtist?.length ?? 0) > 0
    readonly property bool lockMediaWidth: showVerboseLabel && hasTrackMetadata
    // The title scroller owns its own HoverHandler to pause the marquee, so the
    // legacy MouseArea does not report containsMouse over that child. Expose one
    // module-wide hover state for the connected Media popup instead.
    readonly property bool containsMouse:
        mediaInput.containsMouse || titleHoverHandler.hovered
    property int pendingTrackDirection: 0
    readonly property int effectiveTrackAnimationDirection: pendingTrackDirection !== 0 ? pendingTrackDirection : 1

    Layout.fillHeight: true
    // Keep the media footprint compact and user-controlled. A stable width
    // prevents track-length changes from resizing the center pill while the
    // marquee handles titles that exceed the configured space.
    readonly property real maxMediaWidth: {
        const configured = Number(Config.options?.bar?.media?.width ?? 180)
        return isFinite(configured)
            ? Math.max(120, Math.min(320, configured))
            : 180
    }
    implicitWidth: lockMediaWidth
        ? maxMediaWidth
        : Math.min(rowLayout.implicitWidth + rowLayout.spacing * 2, maxMediaWidth)
    implicitHeight: Appearance.sizes.barHeight
    clip: true

    Timer {
        running: activePlayer?.playbackState == MprisPlaybackState.Playing
        interval: Config.options?.resources?.updateInterval ?? 3000
        repeat: true
        onTriggered: activePlayer?.positionChanged()
    }

    property bool barMediaPopupVisible: false

    function toggleExpanded(): void {
        if (root.popupMode === "bar")
            root.barMediaPopupVisible = !root.barMediaPopupVisible
        else
            GlobalStates.mediaControlsOpen = !GlobalStates.mediaControlsOpen
    }

    // Expanded media controls use the same morphing surface as the small bar
    // popouts. Internal player cards stay intact, but the outer shell deforms
    // directly from the media module instead of opening a floating window/card.
    StyledPopup {
        id: barMediaPopup
        hoverTarget: root
        hoverActivates: true
        alternativeVisibleCondition: root.barMediaPopupVisible && root.popupMode === "bar"
        closeOnOutsideClick: root.barMediaPopupVisible
        keyboardFocus: root.barMediaPopupVisible
        popupBackgroundMargin: Appearance.sizes.elevationMargin
        onRequestClose: root.barMediaPopupVisible = false

        function restoreInitialFocus(): void {
            Qt.callLater(() => {
                if (root.barMediaPopupVisible
                        && barMediaPopup.requestedVisible
                        && barMediaPopup.presentationWindow)
                    mediaPopupContent.focusInitialControl()
            })
        }

        onRequestedVisibleChanged: {
            if (requestedVisible)
                restoreInitialFocus()
        }
        onPresentationWindowChanged: {
            if (requestedVisible && presentationWindow)
                restoreInitialFocus()
        }

        BarMediaPopup {
            id: mediaPopupContent
            focus: true
            onCloseRequested: root.barMediaPopupVisible = false
        }
    }

    MouseArea {
        id: mediaInput
        anchors.fill: parent
        acceptedButtons: Qt.MiddleButton | Qt.BackButton | Qt.ForwardButton | Qt.RightButton | Qt.LeftButton
        hoverEnabled: true
        activeFocusOnTab: true

        Accessible.role: Accessible.Button
        Accessible.name: Translation.tr("Media controls")
        Accessible.focusable: true

        Keys.onPressed: event => {
            if (event.isAutoRepeat
                    || (event.key !== Qt.Key_Return
                        && event.key !== Qt.Key_Enter
                        && event.key !== Qt.Key_Space))
                return
            root.toggleExpanded()
            event.accepted = true
        }

        onPressed: (event) => {
            if (event.button === Qt.MiddleButton) {
                MprisController.togglePlaying();
            } else if (event.button === Qt.BackButton) {
                root.pendingTrackDirection = -1
                MprisController.previous();
            } else if (event.button === Qt.ForwardButton || event.button === Qt.RightButton) {
                root.pendingTrackDirection = 1
                MprisController.next();
            } else if (event.button === Qt.LeftButton) {
                root.toggleExpanded()
            }
        }
    }

    RowLayout { // Real content
        id: rowLayout

        spacing: 4 * Appearance.sizes.barModuleScale
        anchors.fill: parent

        Item {
            id: compactMediaGlyph
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: Math.round(22 * Appearance.sizes.barModuleScale)
            implicitHeight: implicitWidth

            ClippedFilledCircularProgress {
                id: mediaCircProg
                anchors.centerIn: parent
                lineWidth: Appearance.rounding.unsharpen
                value: (activePlayer && activePlayer.length > 0) ? (activePlayer.position / activePlayer.length) : 0
                implicitSize: Math.round(22 * Appearance.sizes.barModuleScale)
                colPrimary: Appearance.colors.colOnLayer0
                enableAnimation: activePlayer?.playbackState === MprisPlaybackState.Playing

                Item {
                    anchors.centerIn: parent
                    width: mediaCircProg.implicitSize
                    height: mediaCircProg.implicitSize

                    MaterialSymbol {
                        anchors.centerIn: parent
                        fill: 1
                        text: activePlayer?.isPlaying ? "pause" : "music_note"
                        iconSize: Math.round(Appearance.font.pixelSize.normal * Appearance.sizes.barModuleScale)
                        color: Appearance.colors.colOnLayer0
                        Behavior on color {
                            enabled: Appearance.animationsEnabled
                            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                        }
                    }
                }
            }
        }

        Item {
            id: titleScroller
            visible: root.showVerboseLabel
            Layout.alignment: Qt.AlignVCenter
            Layout.fillWidth: true
            Layout.rightMargin: rowLayout.spacing
            implicitWidth: titleText.implicitWidth
            implicitHeight: titleText.implicitHeight
            clip: true

            readonly property string fullText: root.fullTrackText
            readonly property bool overflowing: titleText.implicitWidth > width + 1
            // Continuous wraparound: scroll one text width + gap, then loop. The
            // trailing copy enters from the right exactly as the first exits left,
            // so it reads as a single seamless ribbon with no fade-snap.
            readonly property real gap: 40
            readonly property real loopDistance: titleText.implicitWidth + gap

            Row {
                id: marqueeRow
                height: parent.height
                spacing: titleScroller.gap
                x: 0

                StyledText {
                    id: titleText
                    height: marqueeRow.height
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: titleScroller.overflowing ? Text.AlignLeft : Text.AlignHCenter
                    width: titleScroller.overflowing ? implicitWidth : titleScroller.width
                    elide: Text.ElideNone
                    animateChange: true
                    animationDistanceX: root.effectiveTrackAnimationDirection * 10
                    animationDistanceY: 0
                    color: Appearance.colors.colOnLayer1
                    Behavior on color {
                        enabled: Appearance.animationsEnabled
                        ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                    }
                    text: titleScroller.fullText
                    onTextChanged: {
                        root.pendingTrackDirection = 0
                        if (!titleScroller.overflowing) marqueeRow.x = 0
                        if (!titleScroller._marqueeHovered && titleScroller.overflowing && Appearance.animationsEnabled) {
                            scrollAnim.stop()
                            titleScroller._marqueeHolding = true
                            titleScroller._startHoldTimer()
                        }
                    }
                }

                // Trailing copy — only present while scrolling, enters from the right.
                StyledText {
                    height: marqueeRow.height
                    verticalAlignment: Text.AlignVCenter
                    visible: titleScroller.overflowing
                    elide: Text.ElideNone
                    color: titleText.color
                    font: titleText.font
                    text: titleScroller.fullText
                }
            }

            // Pausable marquee: hold at start, then glide left continuously.
            // Hover pauses mid-scroll; on exit it resumes from the paused position.
            property bool _marqueeHolding: true
            property bool _marqueeHovered: false

            function _startHoldTimer() {
                if (!titleScroller.visible || !titleScroller.overflowing
                        || !Appearance.animationsEnabled || _marqueeHovered) return
                holdTimer.start()
            }

            Timer {
                id: holdTimer
                interval: 1800
                onTriggered: {
                    titleScroller._marqueeHolding = false
                    marqueeRow.x = 0
                    scrollAnim.start()
                }
            }

            NumberAnimation {
                id: scrollAnim
                target: marqueeRow; property: "x"
                from: 0
                to: -titleScroller.loopDistance
                duration: Math.max(3500, titleScroller.loopDistance * 42)
                easing.type: Easing.Linear
                // Gate on running — binding setPaused() on a stopped animation warns.
                paused: titleScroller._marqueeHovered && scrollAnim.running
                onFinished: {
                    marqueeRow.x = 0
                    titleScroller._marqueeHolding = true
                    titleScroller._startHoldTimer()
                }
            }

            // Kick off on geometry/overflow changes
            onOverflowingChanged: {
                if (!overflowing) {
                    marqueeRow.x = 0
                    scrollAnim.stop()
                    titleScroller._marqueeHolding = true
                } else if (!_marqueeHovered) {
                    scrollAnim.stop()
                    titleScroller._marqueeHolding = true
                    titleScroller._startHoldTimer()
                }
            }

            onVisibleChanged: {
                if (!visible) {
                    holdTimer.stop()
                    scrollAnim.stop()
                    marqueeRow.x = 0
                    _marqueeHolding = true
                } else if (overflowing && !_marqueeHovered) {
                    _startHoldTimer()
                }
            }

            HoverHandler {
                id: titleHoverHandler
                onHoveredChanged: {
                    titleScroller._marqueeHovered = hovered
                    if (hovered) {
                        holdTimer.stop()
                    } else {
                        if (titleScroller.overflowing && Appearance.animationsEnabled) {
                            if (titleScroller._marqueeHolding) {
                                titleScroller._startHoldTimer()
                            }
                            // NumberAnimation.paused is already false, so it resumes
                        }
                    }
                }
            }
        }

    }

}
