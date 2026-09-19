import qs
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects as GE
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services
import qs.modules.settings
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.perimeter
import qs.modules.common.functions as CF

/**
 * Settings UI as a layer shell overlay panel.
 * Allows users to see live changes to the shell (sidebars, bar, etc.)
 * without opening a separate window. Loaded by the main shell when
 * Config.options?.settingsUi?.overlayMode is true.
 */
Scope {
    id: root

    property bool settingsOpen: GlobalStates.settingsOverlayOpen ?? false
    property bool navEditMode: false

    // Keep the PanelWindow alive briefly after close so the scrim backdrop
    // can fade out (the settings card itself shows/hides instantly, matching
    // the window-mode settings UI). Without this the Loader tears down the
    // instant settingsOpen flips false and the scrim cut to black.
    property bool _panelLoaded: settingsOpen || _closeAnimRunning
    property bool _closeAnimRunning: false
    property real _surfaceReveal: settingsOpen ? 1 : 0

    Behavior on _surfaceReveal {
        enabled: Appearance.animationsEnabled
        NumberAnimation {
            duration: Appearance.animation.elementMove.duration
            easing.type: Appearance.animation.elementMove.type
            easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
        }
    }

    onSettingsOpenChanged: {
        if (settingsOpen) {
            _closeAnimRunning = false
            closeAnimTimer.stop()
            _surfaceReveal = 0
            Qt.callLater(() => {
                if (root.settingsOpen)
                    root._surfaceReveal = 1
            })
        } else {
            _surfaceReveal = 0
            _closeAnimRunning = true
            closeAnimTimer.restart()
        }
    }

    // Keep the native host alive until the bottom-edge exit slide completes.
    Timer {
        id: closeAnimTimer
        interval: Appearance.animation.elementMove.duration + 40
        repeat: false
        onTriggered: _closeAnimRunning = false
    }

    // ── Search system (full, same as settings.qml) ──
    property string overlaySearchText: ""
    property var overlaySearchResults: []

    // Navigation target for search results (no visual spotlight)
    property var searchTargetControl: null

    Timer {
        id: searchDebounceTimer
        interval: 200
        onTriggered: root.recomputeOverlaySearchResults()
    }

    function getWaffleSettingsPageIndex() {
        for (var i = 0; i < overlayPages.length; i++) {
            var componentPath = String(overlayPages[i].component || "");
            if (componentPath.indexOf("modules/settings/WaffleConfig.qml") >= 0) {
                return i;
            }
        }
        return -1;
    }

    function recomputeOverlaySearchResults() {
        var q = String(overlaySearchText || "").toLowerCase().trim();
        if (!q.length) {
            overlaySearchResults = [];
            return;
        }

        var terms = q.split(/\s+/).filter(t => t.length > 0);
        var results = [];

        var isWaffleActive = Config.options?.panelFamily === "waffle";
        var wafflePageIndex = getWaffleSettingsPageIndex();
        var easyOn = root.easyMode;

        const overlaySearchIndex = SettingsPageRegistry.searchIndex();

        // 1. Static index
        for (var i = 0; i < overlaySearchIndex.length; i++) {
            var entry = overlaySearchIndex[i];
            if (wafflePageIndex >= 0 && entry.pageIndex === wafflePageIndex && !isWaffleActive)
                continue;
            if (easyOn && entry.pageIndex >= 0 && entry.pageIndex < overlayPages.length
                && overlayPages[entry.pageIndex].essential !== true)
                continue;

            var label = (entry.label || "").toLowerCase();
            var desc = (entry.description || "").toLowerCase();
            var page = (entry.pageName || "").toLowerCase();
            var sect = (entry.section || "").toLowerCase();
            var kw = (entry.keywords || []).join(" ").toLowerCase();

            var matchCount = 0;
            var score = 0;

            for (var j = 0; j < terms.length; j++) {
                var term = terms[j];
                if (label.indexOf(term) >= 0 || desc.indexOf(term) >= 0 ||
                    page.indexOf(term) >= 0 || sect.indexOf(term) >= 0 || kw.indexOf(term) >= 0) {
                    matchCount++;
                    if (label.indexOf(term) === 0) score += 800;
                    else if (label.indexOf(term) > 0) score += 400;
                    if (kw.indexOf(term) >= 0) score += 300;
                    if (sect.indexOf(term) >= 0) score += 200;
                }
            }

            if (matchCount === terms.length) {
                results.push({
                    pageIndex: entry.pageIndex,
                    pageName: entry.pageName,
                    section: entry.section,
                    label: entry.label,
                    labelHighlighted: SettingsSearchRegistry.highlightTerms(entry.label, terms),
                    description: entry.description,
                    descriptionHighlighted: SettingsSearchRegistry.highlightTerms(entry.description, terms),
                    score: score + 500,
                    isSection: true
                });
            }
        }

        // 2. Dynamic widget registry
        if (typeof SettingsSearchRegistry !== "undefined") {
            var widgetResults = SettingsSearchRegistry.buildResults(overlaySearchText);
            if (!isWaffleActive && wafflePageIndex >= 0) {
                widgetResults = widgetResults.filter(r => r.pageIndex !== wafflePageIndex);
            }
            if (easyOn) {
                widgetResults = widgetResults.filter(r =>
                    r.pageIndex >= 0 && r.pageIndex < overlayPages.length
                    && overlayPages[r.pageIndex].essential === true);
            }
            // Prefer real controls (dynamic registry entries with optionId)
            for (var wr = 0; wr < widgetResults.length; wr++) {
                widgetResults[wr].score = (widgetResults[wr].score || 0) + 2000;
            }
            results = results.concat(widgetResults);
        }

        // 3. Sort and deduplicate
        results.sort((a, b) => b.score - a.score);
        var seen = {};
        var unique = [];
        for (var k = 0; k < results.length; k++) {
            var r = results[k];
            var key = String(r.pageIndex) + "|" + String(r.label || "").toLowerCase();
            if (!seen[key]) {
                seen[key] = { index: unique.length, hasOptionId: r.optionId !== undefined };
                unique.push(r);
            } else if (r.optionId !== undefined && !seen[key].hasOptionId) {
                unique[seen[key].index] = r;
                seen[key].hasOptionId = true;
            }
        }

        overlaySearchResults = unique.slice(0, 50);
    }

    // ── Search navigation system ──
    property int pendingSpotlightOptionId: -1
    property string pendingSpotlightLabel: ""
    property string pendingSpotlightSection: ""
    property int pendingSpotlightPageIndex: -1
    property bool pendingSpotlightIsSection: false
    property int spotlightRetryCount: 0
    property int spotlightMaxRetries: 15

    function openOverlaySearchResult(entry) {
        // Clear search immediately
        overlaySearchText = "";
        if (typeof overlaySearchField !== "undefined" && overlaySearchField) overlaySearchField.text = "";

        // Reset any previous search target
        resetSearchTarget();

        if (!entry || entry.pageIndex === undefined || entry.pageIndex < 0) return;

        // Store spotlight target info
        pendingSpotlightOptionId = (entry.optionId !== undefined) ? entry.optionId : -1;
        pendingSpotlightLabel = entry.label || "";
        pendingSpotlightSection = entry.section || "";
        pendingSpotlightPageIndex = entry.pageIndex;
        pendingSpotlightIsSection = (entry.optionId === undefined) && (entry.isSection === true);

        // Navigate to page (this triggers page load if needed)
        if (overlayCurrentPage !== entry.pageIndex) {
            overlayCurrentPage = entry.pageIndex;
        }

        // Always try navigation (with retry for lazy-loaded widgets)
        if (pendingSpotlightOptionId >= 0 || pendingSpotlightLabel.length > 0) {
            spotlightRetryCount = 0;
            spotlightPageLoadTimer.restart();
        }
    }

    // Timer to wait for page load and widget registration
    Timer {
        id: spotlightPageLoadTimer
        interval: 150
        onTriggered: root.trySpotlight()
    }

    function trySpotlight() {
        const pageItem = overlayPagesHost.currentItem
        if (pageItem && overlayPagesHost.currentIndex === pendingSpotlightPageIndex
                && pendingSpotlightSection.length > 0
                && typeof pageItem.activateSettingsSearchSection === "function")
            pageItem.activateSettingsSearchSection(pendingSpotlightSection)

        var control = null;

        // Try by optionId first
        if (pendingSpotlightOptionId >= 0) {
            control = SettingsSearchRegistry.getControlById(pendingSpotlightOptionId);
        }

        // Fallback: search in registry by various criteria
        // IMPORTANT: for static index entries (no optionId), treat as section navigation.
        // Don't guess a specific control by fuzzy label matching.
        if (!control && (pendingSpotlightLabel.length > 0 || pendingSpotlightSection.length > 0)) {
            var labelLower = pendingSpotlightLabel.toLowerCase();
            var sectionLower = pendingSpotlightSection.toLowerCase();
            // Remove page name prefix from sectionGroup if present (supports both delimiters)
            // e.g., "Themes · Colors" or "Themes › Colors" -> "Colors"
            var sectionParts = sectionLower.split(/[·›]/).map(p => p.trim()).filter(p => p.length > 0);
            var sectionOnly = sectionParts.length > 1 ? sectionParts[sectionParts.length - 1] : sectionLower;

            for (var i = 0; i < SettingsSearchRegistry.entries.length; i++) {
                var e = SettingsSearchRegistry.entries[i];
                if (e.pageIndex !== pendingSpotlightPageIndex)
                    continue;

                var eLabelLower = (e.label || "").toLowerCase();
                var eSectionLower = (e.section || "").toLowerCase();
                var eSectionParts = eSectionLower.split(/[·›]/).map(p => p.trim()).filter(p => p.length > 0);
                var eSectionOnly = eSectionParts.length > 1 ? eSectionParts[eSectionParts.length - 1] : eSectionLower;

                if (pendingSpotlightIsSection) {
                    // Prefer matching the section title control.
                    // Registry section titles commonly appear in e.label (SettingsCardSection/CollapsibleSection).
                    if (eLabelLower === labelLower || eLabelLower === sectionOnly) {
                        control = e.control;
                        break;
                    }
                    if (eSectionOnly === sectionOnly || eSectionOnly === labelLower) {
                        control = e.control;
                        break;
                    }
                } else {
                    // Exact label match
                    if (eLabelLower === labelLower) {
                        control = e.control;
                        break;
                    }

                    // Section title match (for SettingsCardSection / CollapsibleSection)
                    if (eSectionOnly === sectionOnly || eSectionOnly === labelLower) {
                        control = e.control;
                        break;
                    }

                    // Label contains search term
                    if (labelLower.length > 2 && eLabelLower.indexOf(labelLower) >= 0) {
                        control = e.control;
                        break;
                    }

                    // Keywords contain search term
                    if (e.keywords && e.keywords.some(k => k.toLowerCase() === labelLower)) {
                        control = e.control;
                        break;
                    }
                }
            }
        }

        if (control) {
            navigateToSearchControl(control);
        } else if (spotlightRetryCount < spotlightMaxRetries) {
            spotlightRetryCount++;
            spotlightPageLoadTimer.restart();
        } else {
            // Give up after max retries - clear pending data
            pendingSpotlightOptionId = -1;
            pendingSpotlightLabel = "";
            pendingSpotlightSection = "";
            pendingSpotlightPageIndex = -1;
            pendingSpotlightIsSection = false;
        }
    }

    function navigateToSearchControl(control) {
        if (!control) return;

        // Expand the section containing the control and collapse others
        if (typeof SettingsSearchRegistry !== "undefined") {
            SettingsSearchRegistry.activateTaskSectionForControl(control);
            SettingsSearchRegistry.expandSectionForControl(control);
        }

        // Find the parent Flickable (ContentPage/StyledFlickable)
        var flick = findParentFlickable(control);
        if (!flick) {
            pendingSpotlightOptionId = -1;
            pendingSpotlightLabel = "";
            pendingSpotlightPageIndex = -1;
            return;
        }

        // Use mapToItem to get the control's position relative to the Flickable's contentItem
        var posInContent = control.mapToItem(flick.contentItem, 0, 0);
        var controlYInContent = posInContent.y;

        // Calculate target scroll position to center the control in viewport
        var viewportHeight = flick.height;
        var controlHeight = control.height;
        var targetScrollY = controlYInContent - (viewportHeight / 2) + (controlHeight / 2);

        // Clamp to valid scroll range
        var maxScroll = Math.max(0, flick.contentHeight - flick.height);
        targetScrollY = Math.max(0, Math.min(targetScrollY, maxScroll));

        // Scroll to position - set directly to bypass animation
        flick.contentY = targetScrollY;
        searchTargetControl = control;
        pendingSpotlightOptionId = -1;
        pendingSpotlightIsSection = false;
    }

    function resetSearchTarget() {
        searchTargetControl = null;
        pendingSpotlightOptionId = -1;
        pendingSpotlightLabel = "";
        pendingSpotlightSection = "";
        pendingSpotlightPageIndex = -1;
        pendingSpotlightIsSection = false;
    }

    function findParentFlickable(item) {
        var p = item ? item.parent : null;
        while (p) {
            if (p.hasOwnProperty("contentY") && p.hasOwnProperty("contentHeight") && p.hasOwnProperty("contentItem")) {
                return p;
            }
            p = p.parent;
        }
        return null;
    }

    property string _lastFamily: Config.options?.panelFamily ?? "ii"

    Connections {
        target: Config.options ?? null
        function onPanelFamilyChanged() {
            root._lastFamily = Config.options?.panelFamily ?? "ii";
            root.overlayCurrentPage = 0;
        }
    }

    // Re-run search when easy mode flips (entries from filtered pages must drop in/out)
    onEasyModeChanged: {
        if (root.overlaySearchText.length > 0) root.recomputeOverlaySearchResults();
    }

    Connections {
        target: GlobalStates
        function onSettingsOverlayOpenChanged() {
            if (GlobalStates.settingsOverlayOpen) {
                if (GlobalStates.settingsOverlayRequestedPage >= 0) {
                    root.overlayCurrentPage = GlobalStates.settingsOverlayRequestedPage
                    GlobalStates.settingsOverlayRequestedPage = -1
                }
            }
        }
    }

    function applyDevDestination(): void {
        if (!DevNavigation.currentDestination.startsWith("settings/")) return
        const key = DevNavigation.currentDestination.substring("settings/".length)
        const index = root.overlayPages.findIndex(page => page.key === key)
        if (index >= 0) root.overlayCurrentPage = index
    }

    Connections {
        target: DevNavigation
        function onCurrentDestinationChanged(): void { root.applyDevDestination() }
    }

    // settingsNav is owned by shell.qml — see the comment there.
    Connections {
        target: GlobalStates
        function onSettingsOverlayRequestedPageChanged() {
            const requested = GlobalStates.settingsOverlayRequestedPage ?? -1
            if (requested < 0 || !root.settingsOpen)
                return
            root.overlayCurrentPage = requested
            GlobalStates.settingsOverlayRequestedPage = -1
        }
    }

    Loader {
        id: panelLoader
        active: root._panelLoaded

        sourceComponent: PanelWindow {
            id: settingsPanel

            // Stay visible during the close-animation window so the exit morph
            // renders; the Loader tears down after closeAnimTimer fires.
            visible: root.settingsOpen || root._closeAnimRunning

            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:settingsOverlay"
            // Yield the layer-shell overlay while a native dialog is visible.
            WlrLayershell.layer: GlobalStates.settingsNativeDialogOpen
                ? WlrLayer.Bottom
                : PolkitService.active ? WlrLayer.Top : WlrLayer.Overlay
            WlrLayershell.keyboardFocus: root.settingsOpen
                && !GlobalStates.regionSelectorOpen
                && !GlobalStates.settingsNativeDialogOpen
                && !PolkitService.active
                ? WlrKeyboardFocus.Exclusive
                : WlrKeyboardFocus.None
            color: "transparent"

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            // Blurred backdrop — see SettingsFocus for the contract. Both overlay
            // layouts read the same setting, so the option in Settings UI means
            // the same thing whichever chrome is selected.
            readonly property int backdropBlur:
                Config.options?.settingsUi?.overlayAppearance?.backdropBlur ?? 0

            Loader {
                anchors.fill: parent
                z: -1
                active: settingsPanel.backdropBlur > 0 && Appearance.effectsEnabled
                visible: active && (GlobalStates.settingsOverlayOpen ?? false)

                sourceComponent: GlassBackground {
                    anchors.fill: parent
                    radius: 0
                    forceBackdrop: true
                    blurStrength: settingsPanel.backdropBlur / 100
                    screenX: 0
                    screenY: 0
                    screenWidth: settingsPanel.width
                    screenHeight: settingsPanel.height
                    fallbackColor: "transparent"
                    auroraTransparency: 0.35

                    opacity: (GlobalStates.settingsOverlayOpen ?? false) ? 1 : 0
                    Behavior on opacity {
                        enabled: Appearance.animationsEnabled
                        NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                    }
                }
            }

            // Global Escape key shortcut (works regardless of focus)
            Shortcut {
                sequences: ["Escape"]
                onActivated: {
                    if (root.overlaySearchText.length > 0) {
                        root.openOverlaySearchResult({});
                    } else {
                        GlobalStates.settingsOverlayOpen = false;
                    }
                }
            }

            Shortcut {
                sequences: ["Ctrl+F"]
                context: Qt.WindowShortcut
                onActivated: if (typeof overlaySearchField !== "undefined" && overlaySearchField) overlaySearchField.forceActiveFocus()
            }

            // Focus grab for Hyprland
            CompositorFocusGrab {
                id: grab
                windows: [settingsPanel]
                active: false
                onCleared: () => {
                    if (!active && !GlobalStates.settingsNativeDialogOpen)
                        GlobalStates.settingsOverlayOpen = false
                }
            }

            Connections {
                target: GlobalStates
                function onSettingsOverlayOpenChanged() {
                    grabTimer.restart()
                }
                function onSettingsNativeDialogOpenChanged() {
                    grabTimer.restart()
                }
            }

            Timer {
                id: grabTimer
                interval: 100
                onTriggered: grab.active = (GlobalStates.settingsOverlayOpen ?? false)
                    && !GlobalStates.settingsNativeDialogOpen
            }

            // ── Scrim backdrop ──
            Rectangle {
                id: scrimBg
                anchors.fill: parent
                color: Appearance.colors.colScrim
                opacity: (GlobalStates.settingsOverlayOpen ?? false) ? (Config.options?.settingsUi?.overlayAppearance?.scrimDim ?? 35) / 100 : 0
                // visible tracks opacity (not settingsOpen) so the close fade-out
                // actually renders before the Loader tears the panel down.
                visible: opacity > 0

                Behavior on opacity {
                    enabled: Appearance.animationsEnabled
                    animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                }
            }

            // Click-outside-to-close hit area — a sibling of scrimBg, not a child.
            // It used to live inside scrimBg, whose `visible: opacity > 0` goes
            // false whenever scrimDim is set to 0 (fully transparent scrim):
            // QtQuick excludes invisible items from hit-testing, so a MouseArea
            // inside an invisible parent silently stops receiving clicks. Scrim
            // dim and click-outside-to-close are independent concerns and must
            // not share one visibility flag.
            MouseArea {
                anchors.fill: parent
                visible: GlobalStates.settingsOverlayOpen ?? false
                enabled: !GlobalStates.settingsNativeDialogOpen && !PolkitService.active
                onClicked: GlobalStates.settingsOverlayOpen = false
            }

            // ── Floating settings card (no separate drop shadow — the card
            //    sits on the scrim backdrop; the panel border provides depth) ──
// ── Bottom-connected settings popup ──
            StyledRectangularShadow {
                target: settingsCard
                visible: (root.settingsOpen || root._closeAnimRunning)
                    && (Config.options?.appearance?.screenEdge?.shadow?.enabled ?? true)
                    && Number(Config.options?.appearance?.screenEdge?.shadow?.size ?? 15) > 0
                    && Number(Config.options?.appearance?.screenEdge?.shadow?.opacity ?? 0.70) > 0
                blur: Math.max(0, Math.min(32,
                    Math.round(Config.options?.appearance?.screenEdge?.shadow?.size ?? 15)))
                spread: 0
                offset: Qt.vector2d(0, 0)
                color: (Config.options?.appearance?.screenEdge?.shadow?.enabled ?? true)
                    ? ColorUtils.applyAlpha(Appearance.colors.colShadow,
                        Math.max(0, Math.min(1.0,
                            Number(Config.options?.appearance?.screenEdge?.shadow?.opacity ?? 0.70))))
                    : "transparent"
                joinBottom: true
            }

            ConnectedSurfaceJoinFlares {
                anchors.fill: parent
                bodyItem: settingsCard
                fillColor: settingsCard.color
                flareRadius: PerimeterTokens.joinFlareRadius
                progress: root._surfaceReveal
                joinBottom: true
                z: 2
            }

            Rectangle {
                id: settingsCard

                readonly property real maxCardWidth: Math.min(
                    1600,
                    Math.max(900, settingsPanel.width * 0.90),
                    Math.max(0, settingsPanel.width - 48))
                readonly property real maxCardHeight: Math.min(
                    1080,
                    Math.max(720, settingsPanel.height * 0.92),
                    Math.max(0, settingsPanel.height - 24))
                // Keep the Material panel opaque enough for readable content while
                // allowing the supported overlay background-opacity control to tune it.
                // This alpha belongs to the panel fill, never Item opacity, so child
                // content remains unaffected.
                readonly property real panelBgOpacity: Math.max(0.6,
                    Config.options?.settingsUi?.overlayAppearance?.backgroundOpacity ?? 1.0)

                anchors.horizontalCenter: parent.horizontalCenter
                y: settingsPanel.height - height
                    + (1 - root._surfaceReveal) * height
                width: maxCardWidth
                height: maxCardHeight
                radius: Appearance.rounding.windowRounding
                readonly property real attachedRadius: Math.max(0, Math.min(
                    PerimeterTokens.attachedCornerRadius, width / 2, height / 2))
                bottomLeftRadius: attachedRadius
                bottomRightRadius: attachedRadius
                Behavior on radius {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animationCurves.zzzOvershoot }
                }
                color: CF.ColorUtils.applyAlpha(
                    Appearance.colors.colLayer0Base,
                    settingsCard.panelBgOpacity)
                clip: true

                border.width: 0
                border.color: "transparent"
                Behavior on color {
                    enabled: Appearance.animationsEnabled
                    ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                }

                // Scale + fade. Exit uses elementMoveExit (snappy ~200ms accel) so
                // the close feels immediate and matches the window-mode settings;
                // enter reuses the same Behavior (200ms is smooth enough on open).
                // Instant show/hide — matches the window-mode settings UI.
                // No scale/opacity fade (the fade felt heavy and the scrim
                // backdrop already carries the transition).
                opacity: 1
                visible: root.settingsOpen || root._closeAnimRunning

                // Material-only v1.0: retired shell-wide style backdrops are not
                // instantiated in the active Settings surface.

                // Prevent clicks from closing
                MouseArea {
                    anchors.fill: parent
                    onClicked: (mouse) => mouse.accepted = true
                }

                // ── Main content ──
                ColumnLayout {
                    id: mainLayout
                    anchors {
                        fill: parent
                        margins: 16
                    }
                    z: 2
                    spacing: 0

                    // ── Title bar ──
                    Item {
                        id: overlayHeader
                        Layout.fillWidth: true
                        Layout.preferredHeight: root.navEditMode ? 58 : 44
                        Layout.leftMargin: 4
                        Layout.rightMargin: 4
                        Layout.bottomMargin: 12

                        function slotBlock(index: int): string {
                            return SettingsChromeLayout.headerOrder[index] ?? ""
                        }

                        readonly property real headerGap: root.navEditMode ? 8 : 12
                        readonly property real identityWidth: root.navEditMode ? 176 : 190
                        readonly property real actionsWidth: Math.max(112, overlayHeaderActionsRow.implicitWidth)
                        readonly property bool defaultOrder: SettingsChromeLayout.headerOrder.join(",") === "identity,search,actions"

                        function searchWidth(): real {
                            const preferred = root.navEditMode ? 390 : 420
                            const minimum = root.navEditMode ? 150 : 180
                            if (overlayHeader.defaultOrder) {
                                const side = Math.max(overlayHeader.identityWidth, overlayHeader.actionsWidth)
                                return Math.max(minimum, Math.min(preferred,
                                    overlayHeader.width - 2 * (side + overlayHeader.headerGap)))
                            }
                            return Math.max(minimum, Math.min(preferred,
                                overlayHeader.width - overlayHeader.identityWidth
                                    - overlayHeader.actionsWidth - 2 * overlayHeader.headerGap))
                        }

                        function slotWidth(index: int): real {
                            const block = overlayHeader.slotBlock(index)
                            if (block === "identity")
                                return overlayHeader.identityWidth
                            if (block === "actions")
                                return overlayHeader.actionsWidth
                            return overlayHeader.searchWidth()
                        }

                        function slotX(index: int): real {
                            const block = overlayHeader.slotBlock(index)
                            if (overlayHeader.defaultOrder) {
                                if (block === "identity")
                                    return 0
                                if (block === "actions")
                                    return Math.max(0, overlayHeader.width - overlayHeader.actionsWidth)
                                return Math.max(0, (overlayHeader.width - overlayHeader.searchWidth()) / 2)
                            }

                            const total = overlayHeader.identityWidth + overlayHeader.searchWidth()
                                + overlayHeader.actionsWidth + 2 * overlayHeader.headerGap
                            let x = Math.max(0, (overlayHeader.width - total) / 2)
                            for (let i = 0; i < index; ++i)
                                x += overlayHeader.slotWidth(i) + overlayHeader.headerGap
                            return x
                        }


                        Item {
                            anchors.fill: parent

                            Item {
                                id: overlayHeaderSlot0
                                x: overlayHeader.slotX(0)
                                width: overlayHeader.slotWidth(0)
                                height: parent.height
                            }
                            Item {
                                id: overlayHeaderSlot1
                                x: overlayHeader.slotX(1)
                                width: overlayHeader.slotWidth(1)
                                height: parent.height
                            }
                            Item {
                                id: overlayHeaderSlot2
                                x: overlayHeader.slotX(2)
                                width: overlayHeader.slotWidth(2)
                                height: parent.height
                            }
                        }

                        Item {
                            id: overlayHeaderIdentity
                            parent: SettingsChromeLayout.columnFor("identity") === 0 ? overlayHeaderSlot0
                                : SettingsChromeLayout.columnFor("identity") === 1 ? overlayHeaderSlot1
                                : overlayHeaderSlot2
                            anchors.fill: parent
                            anchors.topMargin: 4
                            anchors.bottomMargin: 4

                            RowLayout {
                                anchors.fill: parent
                                spacing: 9

                                Item {
                                    implicitWidth: 38
                                    implicitHeight: 38

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: width / 2
                                        color: Appearance.colors.colLayer1
                                        border.width: 1
                                        border.color: Appearance.colors.colPrimary
                                    }

                                    Rectangle {
                                        id: overlayAvatarMask
                                        anchors.centerIn: parent
                                        width: 34
                                        height: 34
                                        radius: width / 2
                                        visible: false
                                    }

                                    Image {
                                        id: overlayAvatarImage
                                        anchors.centerIn: parent
                                        width: 34
                                        height: 34
                                        source: Directories.userAvatarSourcePrimary
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        cache: true
                                        smooth: true
                                        mipmap: true
                                        visible: status === Image.Ready
                                        layer.enabled: visible
                                        layer.effect: GE.OpacityMask {
                                            maskSource: overlayAvatarMask
                                        }
                                        onStatusChanged: {
                                            if (status === Image.Error) {
                                                const nextSource = Directories.nextAvatarSource(source)
                                                if (nextSource.length > 0 && nextSource !== source)
                                                    source = nextSource
                                            }
                                        }
                                    }

                                    MaterialSymbol {
                                        anchors.centerIn: parent
                                        visible: overlayAvatarImage.status !== Image.Ready
                                        text: "person"
                                        iconSize: 18
                                        color: Appearance.colors.colPrimary
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 0

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: Translation.tr("Settings")
                                        font {
                                            family: Appearance.font.family.title
                                            pixelSize: Appearance.font.pixelSize.title
                                            variableAxes: Appearance.font.variableAxes.title
                                        }
                                        color: Appearance.colors.colOnLayer0
                                        elide: Text.ElideRight
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: SystemInfo.displayName || SystemInfo.username
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        color: Appearance.colors.colSubtext
                                        elide: Text.ElideRight
                                    }
                                }
                            }

                            SettingsChromeEditFrame {
                                anchors.fill: parent
                                active: root.navEditMode
                                blockId: "identity"
                                label: Translation.tr("Identity")
                                targetIndex: SettingsChromeLayout.columnFor("identity")
                            }
                        }

                        Rectangle {
                            id: overlaySearchContainer
                            parent: SettingsChromeLayout.columnFor("search") === 0 ? overlayHeaderSlot0
                                : SettingsChromeLayout.columnFor("search") === 1 ? overlayHeaderSlot1
                                : overlayHeaderSlot2
                            anchors.fill: parent
                            anchors.topMargin: root.navEditMode ? 10 : 4
                            anchors.bottomMargin: root.navEditMode ? 10 : 4
                            radius: Appearance.rounding.full
                            color: overlaySearchField.activeFocus
                                ? Appearance.colors.colLayer1
                                : Appearance.colors.colSurfaceContainerLow
                            border.width: overlaySearchField.activeFocus ? 2 : 1
                            border.color: overlaySearchField.activeFocus
                                ? Appearance.colors.colPrimary
                                : Appearance.colors.colOutlineVariant

                            Behavior on color {
                                enabled: Appearance.animationsEnabled
                                animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                            }
                            Behavior on border.color {
                                enabled: Appearance.animationsEnabled
                                animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 8
                                spacing: 8

                                MaterialSymbol {
                                    text: root.overlaySearchResults.length > 0 ? "manage_search" : "search"
                                    iconSize: Appearance.font.pixelSize.normal
                                    color: overlaySearchField.activeFocus
                                        ? Appearance.colors.colPrimary
                                        : Appearance.colors.colSubtext

                                    Behavior on color {
                                        enabled: Appearance.animationsEnabled
                                        animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                                    }
                                }

                                Item {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true

                                    StyledText {
                                        anchors.fill: parent
                                        anchors.leftMargin: 2
                                        verticalAlignment: Text.AlignVCenter
                                        visible: overlaySearchField.text.length === 0 && !overlaySearchField.activeFocus
                                        text: Translation.tr("Search settings... (Ctrl+F)")
                                        font {
                                            family: Appearance.font.family.main
                                            pixelSize: Appearance.font.pixelSize.small
                                        }
                                        color: Appearance.colors.colSubtext
                                    }

                                    TextInput {
                                        id: overlaySearchField
                                        anchors.fill: parent
                                        anchors.leftMargin: 2
                                        verticalAlignment: Text.AlignVCenter
                                        color: Appearance.colors.colOnLayer1
                                        font {
                                            family: Appearance.font.family.main
                                            pixelSize: Appearance.font.pixelSize.small
                                        }
                                        clip: true
                                        selectByMouse: true
                                        selectionColor: Appearance.colors.colPrimaryContainer
                                        selectedTextColor: Appearance.colors.colOnPrimaryContainer

                                        cursorVisible: activeFocus
                                        cursorDelegate: Rectangle {
                                            visible: overlaySearchField.cursorVisible
                                            width: 2
                                            color: Appearance.colors.colPrimary

                                            SequentialAnimation on opacity {
                                                loops: Animation.Infinite
                                                running: overlaySearchField.cursorVisible
                                                NumberAnimation { to: 0; duration: 530 }
                                                NumberAnimation { to: 1; duration: 530 }
                                            }
                                        }

                                        text: root.overlaySearchText
                                        onTextChanged: {
                                            root.overlaySearchText = text;
                                            if (text.length > 0) {
                                                searchDebounceTimer.restart();
                                            } else {
                                                // Clear immediately for clean exit morph (no debounce)
                                                root.overlaySearchResults = [];
                                            }
                                        }

                                        Keys.onPressed: (event) => {
                                            if (event.key === Qt.Key_Down && root.overlaySearchResults.length > 0) {
                                                overlayResultsList.forceActiveFocus();
                                                if (overlayResultsList.currentIndex < 0) {
                                                    overlayResultsList.currentIndex = 0;
                                                }
                                                event.accepted = true;
                                            } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && root.overlaySearchResults.length > 0) {
                                                var idx = (overlayResultsList.currentIndex >= 0 && overlayResultsList.currentIndex < root.overlaySearchResults.length)
                                                    ? overlayResultsList.currentIndex
                                                    : 0;
                                                root.openOverlaySearchResult(root.overlaySearchResults[idx]);
                                                event.accepted = true;
                                            } else if (event.key === Qt.Key_Escape) {
                                                root.openOverlaySearchResult({});
                                                event.accepted = true;
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.preferredHeight: 22
                                    Layout.preferredWidth: overlayResultsCountText.implicitWidth + 14
                                    Layout.alignment: Qt.AlignVCenter
                                    visible: root.overlaySearchText.length > 0 && root.overlaySearchResults.length > 0
                                    radius: Appearance.rounding.full
                                    color: Appearance.colors.colPrimaryContainer
                                    opacity: visible ? 1 : 0

                                    Behavior on opacity {
                                        enabled: Appearance.animationsEnabled
                                        animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                                    }

                                    StyledText {
                                        id: overlayResultsCountText
                                        anchors.centerIn: parent
                                        text: root.overlaySearchResults.length.toString()
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        font.weight: Font.Medium
                                        color: Appearance.colors.colOnPrimaryContainer
                                    }
                                }

                                RippleButton {
                                    Layout.preferredWidth: 26
                                    Layout.preferredHeight: 26
                                    Layout.alignment: Qt.AlignVCenter
                                    buttonRadius: Appearance.rounding.full
                                    visible: root.overlaySearchText.length > 0
                                    opacity: visible ? 1 : 0
                                    Behavior on opacity {
                                        enabled: Appearance.animationsEnabled
                                        animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                                    }
                                    onClicked: {
                                        overlaySearchField.text = "";
                                        overlaySearchField.forceActiveFocus();
                                    }
                                    contentItem: MaterialSymbol {
                                        anchors.centerIn: parent
                                        text: "close"
                                        iconSize: 16
                                        color: Appearance.colors.colOnSurfaceVariant
                                    }
                                }
                            }

                            SettingsChromeEditFrame {
                                anchors.fill: parent
                                active: root.navEditMode
                                blockId: "search"
                                label: Translation.tr("Search")
                                targetIndex: SettingsChromeLayout.columnFor("search")
                            }
                        }

                        Item {
                            id: overlayHeaderActions
                            parent: SettingsChromeLayout.columnFor("actions") === 0 ? overlayHeaderSlot0
                                : SettingsChromeLayout.columnFor("actions") === 1 ? overlayHeaderSlot1
                                : overlayHeaderSlot2
                            anchors.fill: parent
                            anchors.topMargin: root.navEditMode ? 10 : 4
                            anchors.bottomMargin: root.navEditMode ? 10 : 4

                            RowLayout {
                                id: overlayHeaderActionsRow
                                anchors.fill: parent
                                spacing: 4

                                RippleButton {
                                    id: easyModeToggle
                                    buttonRadius: Appearance.rounding.full
                                    implicitWidth: 36
                                    implicitHeight: 36
                                    onClicked: root.setEasyMode(!root.easyMode)
                                    contentItem: MaterialSymbol {
                                        anchors.centerIn: parent
                                        horizontalAlignment: Text.AlignHCenter
                                        text: root.easyMode ? "school" : "tune"
                                        iconSize: 20
                                        color: root.easyMode
                                            ? Appearance.colors.colPrimary
                                            : Appearance.colors.colOnSurfaceVariant
                                        Behavior on color {
                                            enabled: Appearance.animationsEnabled
                                            animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                                        }
                                    }
                                    StyledToolTip {
                                        position: "left"
                                        text: root.easyMode
                                            ? Translation.tr("Switch to Advanced mode")
                                            : Translation.tr("Switch to Easy mode")
                                    }
                                }

                                RippleButton {
                                    buttonRadius: Appearance.rounding.full
                                    implicitWidth: 36
                                    implicitHeight: 36
                                    onClicked: Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "lock", "activate"])
                                    contentItem: MaterialSymbol {
                                        anchors.centerIn: parent
                                        horizontalAlignment: Text.AlignHCenter
                                        text: "lock"
                                        iconSize: 20
                                        color: Appearance.colors.colOnSurfaceVariant
                                    }
                                }

                                RippleButton {
                                    buttonRadius: Appearance.rounding.full
                                    implicitWidth: 36
                                    implicitHeight: 36
                                    onClicked: GlobalStates.settingsOverlayOpen = false
                                    contentItem: MaterialSymbol {
                                        anchors.centerIn: parent
                                        horizontalAlignment: Text.AlignHCenter
                                        text: "close"
                                        iconSize: 20
                                        color: Appearance.colors.colOnSurfaceVariant
                                    }
                                }
                            }

                            SettingsChromeEditFrame {
                                anchors.fill: parent
                                active: root.navEditMode
                                blockId: "actions"
                                label: Translation.tr("Actions")
                                targetIndex: SettingsChromeLayout.columnFor("actions")
                            }
                        }
                    }

                    // ── Navigation + Content ──
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 10

                        // Navigation rail with labels
                        Rectangle {
                            id: navColumn
                            Layout.fillHeight: true
                            Layout.preferredWidth: root.navEditMode ? 228 : 150
                            radius: Appearance.rounding.normal
                            color: "transparent"

                            Behavior on Layout.preferredWidth {
                                enabled: Appearance.animationsEnabled
                                NumberAnimation {
                                    duration: Appearance.animation.elementResize.duration
                                    easing.type: Appearance.animation.elementResize.type
                                    easing.bezierCurve: Appearance.animation.elementResize.bezierCurve
                                }
                            }

                            Flickable {
                                id: navFlickable
                                visible: !root.navEditMode || navEditLoader.status !== Loader.Ready
                                anchors.fill: parent
                                anchors.margins: 2
                                anchors.bottomMargin: overlayNavActions.height + 6
                                contentHeight: navCol.implicitHeight
                                clip: true
                                boundsBehavior: Flickable.StopAtBounds

                                ScrollBar.vertical: StyledScrollBar {
                                    policy: ScrollBar.AlwaysOff
                                }

                                ColumnLayout {
                                    id: navCol
                                    width: parent.width
                                    spacing: 0

                                    Repeater {
                                        id: navRepeater
                                        model: root.visibleNavItems
                                        delegate: Column {
                                            id: navItem
                                            required property int index
                                            required property var modelData
                                            Layout.fillWidth: true
                                            spacing: 0
                                            readonly property color headerAccentColor: Appearance.colors.colPrimary

                                            // ── Category header ──
                                            Item {
                                                width: parent.width
                                                height: visible ? (navItem.index > 0 ? 32 : 20) : 0
                                                visible: navItem.modelData.type === "header"

                                                Behavior on height {
                                                    enabled: Appearance.animationsEnabled
                                                    animation: NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve }
                                                }

                                                StyledText {
                                                    anchors.left: parent.left
                                                    anchors.leftMargin: 12
                                                    anchors.bottom: parent.bottom
                                                    anchors.bottomMargin: 4
                                                    text: navItem.modelData.label || ""
                                                    font {
                                                        family: Appearance.font.family.main
                                                        pixelSize: Appearance.font.pixelSize.smaller
                                                        weight: Font.DemiBold
                                                        capitalization: Font.AllUppercase
                                                        letterSpacing: 1.1
                                                    }
                                                    color: navItem.headerAccentColor
                                                    opacity: 0.85

                                                    Behavior on color {
                                                        enabled: Appearance.animationsEnabled
                                                        animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                                                    }
                                                    Behavior on opacity {
                                                        enabled: Appearance.animationsEnabled
                                                        animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                                                    }
                                                }
                                            }

                                            // ── Nav button ──
                                            RippleButton {
                                                id: navBtn
                                                visible: navItem.modelData.type === "page"
                                                width: parent.width
                                                implicitHeight: visible ? 34 : 0
                                                z: 1

                                                readonly property int pageRealIndex: navItem.modelData.realIndex !== undefined ? navItem.modelData.realIndex : navItem.index

                                                rippleEnabled: true
                                                buttonRadius: Math.min(width, height) / 2
                                                toggled: overlayCurrentPage === pageRealIndex
                                                colBackground: "transparent"
                                                colBackgroundToggled: "transparent"
                                                // Keep the travelling Material selection pill visible
                                                // beneath the transparent toggled button surface.
                                                colBackgroundToggledHover: CF.ColorUtils.transparentize(
                                                    Appearance.colors.colLayer1Hover, 0.5)
                                                colBackgroundHover: Appearance.colors.colLayer1Hover

                                                onClicked: overlayCurrentPage = pageRealIndex

                                                contentItem: Item {
                                                    anchors.fill: parent

                                                    RowLayout {
                                                        anchors.fill: parent
                                                        anchors.leftMargin: 10
                                                        anchors.rightMargin: 8
                                                        spacing: 10

                                                        MaterialSymbol {
                                                            text: navItem.modelData.icon || ""
                                                            iconSize: 18
                                                            color: navBtn.toggled
                                                                ? Appearance.colors.colPrimary
                                                                : Appearance.colors.colOnSurfaceVariant
                                                            rotation: navItem.modelData.iconRotation || 0

                                                            Behavior on color {
                                                                enabled: Appearance.animationsEnabled
                                                                animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                                                            }
                                                        }

                                                        StyledText {
                                                            Layout.fillWidth: true
                                                            text: navItem.modelData.name || ""
                                                            font {
                                                                family: Appearance.font.family.main
                                                                pixelSize: Appearance.font.pixelSize.small
                                                                weight: navBtn.toggled ? Font.Medium : Font.Normal
                                                            }
                                                            color: navBtn.toggled
                                                                ? Appearance.colors.colOnLayer1
                                                                : Appearance.colors.colOnSurfaceVariant
                                                            elide: Text.ElideRight

                                                            Behavior on color {
                                                                enabled: Appearance.animationsEnabled
                                                                animation: ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // Active indicator: pill travelling behind the active item,
                                    // inside navCol so its y matches the items' coordinate space.
                                    Rectangle {
                                        id: sharedNavIndicator
                                        z: -1
                                        parent: navCol
                                        x: 0
                                        width: navCol.width
                                        radius: Appearance.rounding.small
                                        color: Appearance.colors.colPrimaryContainer

                                        Behavior on radius {
                                            enabled: Appearance.animationsEnabled
                                            NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve }
                                        }
                                        Behavior on color {
                                            enabled: Appearance.animationsEnabled
                                            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                                        }

                                        property real targetY: 0
                                        property real targetH: 0
                                        property bool hasTarget: false

                                        // Leading/trailing edges travel at different speeds, so the
                                        // pill stretches toward the target and contracts on arrival
                                        // (same morph as the bar Workspaces indicator).
                                        property real edgeTop: targetY
                                        property real edgeBottom: targetY + targetH
                                        Behavior on edgeTop {
                                            enabled: Appearance.animationsEnabled
                                            animation: NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve }
                                        }
                                        Behavior on edgeBottom {
                                            enabled: Appearance.animationsEnabled
                                            animation: NumberAnimation { duration: Math.round(Appearance.animation.elementResize.duration * 1.18); easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve }
                                        }

                                        function updatePosition() {
                                            for (var i = 0; i < navRepeater.count; i++) {
                                                var item = navRepeater.itemAt(i);
                                                if (item && item.modelData && item.modelData.type === "page" && item.modelData.realIndex === overlayCurrentPage) {
                                                    var btn = item.children[1];
                                                    if (btn && btn.visible) {
                                                        targetY = item.y + btn.y;
                                                        targetH = btn.height;
                                                        hasTarget = true;
                                                        return;
                                                    }
                                                }
                                            }
                                            hasTarget = false;
                                        }

                                        y: Math.min(edgeTop, edgeBottom)
                                        height: hasTarget ? Math.abs(edgeBottom - edgeTop) : 0
                                        opacity: hasTarget ? 1 : 0

                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.verticalCenter: parent.verticalCenter
                                            anchors.leftMargin: 4
                                            width: 3
                                            radius: 1.5
                                            height: parent.hasTarget ? parent.height * 0.5 : 0
                                            color: Appearance.colors.colPrimary
                                            Behavior on height {
                                                enabled: Appearance.animationsEnabled
                                                animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                                            }
                                        }

                                        Behavior on opacity {
                                            enabled: Appearance.animationsEnabled
                                            animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                                        }

                                        Connections {
                                            target: root
                                            function onOverlayCurrentPageChanged() { Qt.callLater(sharedNavIndicator.updatePosition); }
                                            function onVisibleNavItemsChanged() { Qt.callLater(sharedNavIndicator.updatePosition); }
                                        }
                                        Connections {
                                            target: navRepeater
                                            function onCountChanged() { Qt.callLater(sharedNavIndicator.updatePosition); }
                                        }
                                        Component.onCompleted: Qt.callLater(updatePosition)
                                    }
                                }
                            }

                            Loader {
                                id: navEditLoader
                                anchors {
                                    top: parent.top
                                    left: parent.left
                                    right: parent.right
                                    bottom: overlayNavActions.top
                                    margins: 2
                                    bottomMargin: 6
                                }
                                active: root.navEditMode
                                asynchronous: true
                                visible: status === Loader.Ready
                                opacity: visible ? 1 : 0

                                Behavior on opacity {
                                    enabled: Appearance.animationsEnabled
                                    NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
                                }

                                sourceComponent: Component {
                                    SettingsNavEditPane {
                                        currentPage: overlayCurrentPage
                                        onPageActivated: pageIndex => overlayCurrentPage = pageIndex
                                        onPageHidden: pageIndex => {
                                            if (overlayCurrentPage !== pageIndex)
                                                return
                                            Qt.callLater(() => {
                                                if (root.navPageOrder.length > 0)
                                                    overlayCurrentPage = root.navPageOrder[0]
                                            })
                                        }
                                        onDoneRequested: root.navEditMode = false
                                    }
                                }
                            }

                            ColumnLayout {
                                id: overlayNavActions
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.margins: 2
                                spacing: 2

                                RippleButton {
                                    id: overlayNavEditToggle
                                    readonly property color editSurface: Appearance.colors.colPrimaryContainer
                                    readonly property color editSurfaceHover: Appearance.colors.colPrimaryContainerHover
                                    readonly property color editForeground: Appearance.colors.colOnPrimaryContainer
                                    Layout.fillWidth: true
                                    implicitHeight: 36
                                    buttonRadius: Appearance.rounding.small
                                    toggled: root.navEditMode
                                    colBackground: "transparent"
                                    colBackgroundHover: Appearance.colors.colLayer1Hover
                                    colBackgroundToggled: editSurface
                                    colBackgroundToggledHover: editSurfaceHover
                                    onClicked: root.navEditMode = !root.navEditMode


                                    contentItem: RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 8
                                        spacing: 10

                                        MaterialSymbol {
                                            text: root.navEditMode ? "done" : "edit"
                                            iconSize: 18
                                            color: root.navEditMode
                                                ? overlayNavEditToggle.editForeground
                                                : Appearance.colors.colOnSurfaceVariant
                                        }

                                        StyledText {
                                            Layout.fillWidth: true
                                            text: root.navEditMode
                                                ? Translation.tr("Done")
                                                : Translation.tr("Edit navigation")
                                            font.pixelSize: Appearance.font.pixelSize.small
                                            color: root.navEditMode
                                                ? overlayNavEditToggle.editForeground
                                                : Appearance.colors.colOnSurfaceVariant
                                            elide: Text.ElideRight
                                        }
                                    }

                                    StyledToolTip {
                                        position: "top"
                                        text: root.navEditMode
                                            ? Translation.tr("Finish editing navigation")
                                            : Translation.tr("Reorder or hide Settings pages directly in the sidebar")
                                    }
                                }

                                RippleButton {
                                    id: overlayWindowToggle
                                    Layout.fillWidth: true
                                    implicitHeight: 36
                                    buttonRadius: Appearance.rounding.small
                                    colBackground: "transparent"
                                    colBackgroundHover: CF.ColorUtils.transparentize(
                                        Appearance.colors.colLayer1Hover, 0.5)

                                    onClicked: {
                                        Quickshell.execDetached([Quickshell.shellPath("scripts/inir"), "settings-window"])
                                        Config.setNestedValue("settingsUi.overlayMode", false)
                                        GlobalStates.settingsOverlayOpen = false
                                    }

                                    contentItem: RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 8
                                        spacing: 10

                                        MaterialSymbol {
                                            text: "open_in_new"
                                            iconSize: 18
                                            color: Appearance.colors.colOnSurfaceVariant
                                        }

                                        StyledText {
                                            Layout.fillWidth: true
                                            text: Translation.tr("Window")
                                            font {
                                                family: Appearance.font.family.main
                                                pixelSize: Appearance.font.pixelSize.small
                                            }
                                            color: Appearance.colors.colOnSurfaceVariant
                                            elide: Text.ElideRight
                                        }
                                    }

                                    StyledToolTip {
                                        position: "top"
                                        text: Translation.tr("Switch to window mode")
                                    }
                                }
                            }
                        }

                        // Content area
                        // Content area
                        Rectangle {
                            id: overlayContentContainer
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: Appearance.rounding.normal
                            color: Appearance.colors.colSurfaceContainerLow
                            border.width: 0
                            border.color: "transparent"
                            clip: true

                            // ── Page header: icon + name + description ──
                            // ── Page header: icon + name + description ──
                            Item {
                                id: overlayPageHeader
                                anchors { top: parent.top; left: parent.left; right: parent.right }
                                height: 48
                                readonly property var meta: root.overlayPages[root.overlayCurrentPage] ?? {}

                                RowLayout {
                                    id: overlayPageHeaderRow
                                    anchors.fill: parent
                                    anchors.leftMargin: 20
                                    anchors.rightMargin: 20
                                    spacing: 10

                                    MaterialShapeWrappedMaterialSymbol {
                                        text: overlayPageHeader.meta.icon ?? ""
                                        iconSize: 15
                                        Layout.alignment: Qt.AlignVCenter
                                    }

                                    StyledText {
                                        text: overlayPageHeader.meta.name ?? ""
                                        font {
                                            family: Appearance.font.family.title
                                            pixelSize: Appearance.font.pixelSize.normal
                                            weight: Font.DemiBold
                                        }
                                        color: Appearance.colors.colOnLayer1
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: overlayPageHeader.meta.desc ?? ""
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        color: Appearance.colors.colSubtext
                                        elide: Text.ElideRight
                                        opacity: 0.85
                                    }
                                }

                                // Fade-through when the page changes (content swap inside one object)
                                Connections {
                                    target: root
                                    function onOverlayCurrentPageChanged() { if (Appearance.animationsEnabled) overlayPageHeaderSwap.restart() }
                                }
                                SequentialAnimation {
                                    id: overlayPageHeaderSwap
                                    NumberAnimation { target: overlayPageHeaderRow; property: "opacity"; to: 0; duration: Appearance.animation.elementMoveFast.duration / 2; easing.type: Appearance.animation.elementMoveFast.type }
                                    NumberAnimation { target: overlayPageHeaderRow; property: "opacity"; to: 1; duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type }
                                }

                                Rectangle {
                                    anchors { bottom: parent.bottom; left: parent.left; right: parent.right; leftMargin: 16; rightMargin: 16 }
                                    height: 1
                                    color: Appearance.colors.colOutlineVariant
                                    opacity: 0
                                }
                            }

                            SettingsPageHost {
                                id: overlayPagesHost
                                anchors { top: overlayPageHeader.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
                                pages: root.overlayPages
                                requestedIndex: root.overlayCurrentPage
                                loadEnabled: Config.ready && root.settingsOpen
                            }

                            SettingsPageLoadingOverlay {
                                anchors.fill: overlayPagesHost
                                loading: overlayPagesHost.loading
                                text: Translation.tr("Loading page…")
                                z: 15
                            }

                        }
                    }
                }

                // ── Search results overlay ──
                Rectangle {
                    id: overlaySearchResultsOverlay
                    anchors.fill: parent
                    visible: root.overlaySearchText.length > 0 || overlaySearchResultsCard._cardOpacity > 0 || noResultsPill._pillOpacity > 0
                    color: "transparent"
                    z: 100

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.openOverlaySearchResult({})
                    }

                    // No-results pill (morphs in when search has no matches)
                    Rectangle {
                        id: noResultsPill
                        readonly property bool showPill: root.overlaySearchText.length > 0 && root.overlaySearchResults.length === 0
                        property real _pillOpacity: showPill ? 1 : 0
                        property real _pillScale: showPill ? 1 : 0.85

                        visible: _pillOpacity > 0
                        opacity: _pillOpacity
                        scale: _pillScale
                        transformOrigin: Item.Top

                        x: {
                            var dep = overlaySearchContainer.x + overlaySearchContainer.width + settingsCard.width;
                            var p = overlaySearchContainer.mapToItem(overlaySearchResultsOverlay, 0, 0);
                            return p.x + (overlaySearchContainer.width - width) / 2;
                        }
                        anchors.top: parent.top
                        anchors.topMargin: 56
                        width: noResultsRow.implicitWidth + 32
                        height: 44
                        radius: Math.min(width, height) / 2
                        color: Appearance.colors.colSurfaceContainerHigh
                        border.width: 0
                        border.color: "transparent"

                        Behavior on _pillOpacity {
                            enabled: Appearance.animationsEnabled
                            animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                        }
                        Behavior on _pillScale {
                            enabled: Appearance.animationsEnabled
                            animation: NumberAnimation { duration: Appearance.animation.elementMoveEnter.duration; easing.type: Easing.BezierSpline; easing.bezierCurve: Appearance.animationCurves.emphasizedDecel }
                        }
                        Behavior on width {
                            enabled: Appearance.animationsEnabled
                            animation: NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve }
                        }

                        Row {
                            id: noResultsRow
                            anchors.centerIn: parent
                            spacing: 8

                            MaterialSymbol {
                                text: "search_off"
                                iconSize: 18
                                color: Appearance.colors.colSubtext
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            StyledText {
                                text: Translation.tr("No results")
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colSubtext
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    // Results card
                    StyledRectangularShadow {
                        target: overlaySearchResultsCard
                        opacity: overlaySearchResultsCard._cardOpacity
                    }
                    Rectangle {
                        id: overlaySearchResultsCard
                        property real _cardOpacity: root.overlaySearchResults.length > 0 ? 1 : 0
                        property real _cardScale: root.overlaySearchResults.length > 0 ? 1 : 0.92
                        visible: _cardOpacity > 0 || root.overlaySearchResults.length > 0
                        opacity: _cardOpacity
                        scale: _cardScale
                        transformOrigin: Item.Top

                        Behavior on _cardOpacity {
                            enabled: Appearance.animationsEnabled
                            animation: NumberAnimation { duration: Appearance.animation.elementMoveEnter.duration; easing.type: Appearance.animation.elementMoveEnter.type; easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve }
                        }
                        Behavior on _cardScale {
                            enabled: Appearance.animationsEnabled
                            animation: NumberAnimation { duration: Appearance.animation.elementMoveEnter.duration; easing.type: Easing.BezierSpline; easing.bezierCurve: Appearance.animationCurves.emphasizedDecel }
                        }

                        width: Math.max(overlaySearchContainer.width, Math.min(parent.width - 40, 460))
                        height: Math.min(overlayResultsList.contentHeight + 16, 380)
                        // Centered under the search box, not the whole card
                        x: {
                            var dep = overlaySearchContainer.x + overlaySearchContainer.width + settingsCard.width;
                            var p = overlaySearchContainer.mapToItem(overlaySearchResultsOverlay, 0, 0);
                            return Math.max(8, Math.min(p.x + (overlaySearchContainer.width - width) / 2, parent.width - width - 8));
                        }
                        anchors.top: parent.top
                        anchors.topMargin: 56
                        radius: Appearance.rounding.normal
                        color: Appearance.colors.colLayer1
                        border.width: 1
                        border.color: Appearance.colors.colOutlineVariant

                        ListView {
                            id: overlayResultsList
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 2
                            model: root.overlaySearchResults
                            clip: true
                            currentIndex: 0
                            boundsBehavior: Flickable.StopAtBounds

                            Keys.onPressed: (event) => {
                                if (event.key === Qt.Key_Up) {
                                    if (overlayResultsList.currentIndex > 0) {
                                        overlayResultsList.currentIndex--;
                                    } else {
                                        overlaySearchField.forceActiveFocus();
                                    }
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Down) {
                                    if (overlayResultsList.currentIndex < overlayResultsList.count - 1) {
                                        overlayResultsList.currentIndex++;
                                    }
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    if (overlayResultsList.currentIndex >= 0) {
                                        root.openOverlaySearchResult(root.overlaySearchResults[overlayResultsList.currentIndex]);
                                    }
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Escape) {
                                    root.openOverlaySearchResult({});
                                    overlaySearchField.forceActiveFocus();
                                    event.accepted = true;
                                }
                            }

                            delegate: Column {
                                id: resultDelegate
                                required property var modelData
                                required property int index
                                
                                width: overlayResultsList.width
                                spacing: 0
                                
                                // Section header - show when page changes from previous result
                                Rectangle {
                                    id: sectionHeader
                                    width: parent.width
                                    height: visible ? 24 : 0
                                    color: "transparent"
                                    visible: {
                                        if (resultDelegate.index === 0) return true;
                                        var prev = root.overlaySearchResults[resultDelegate.index - 1];
                                        return prev && prev.pageIndex !== resultDelegate.modelData.pageIndex;
                                    }
                                    
                                    Row {
                                        anchors.verticalCenter: parent.verticalCenter
                                        anchors.left: parent.left
                                        anchors.leftMargin: 8
                                        spacing: 6
                                        
                                        MaterialSymbol {
                                            text: SettingsPageRegistry.iconForPage(resultDelegate.modelData.pageIndex)
                                            iconSize: 12
                                            color: Appearance.colors.colPrimary
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                        StyledText {
                                            text: resultDelegate.modelData.pageName || ""
                                            font.pixelSize: Appearance.font.pixelSize.smaller
                                            font.weight: Font.DemiBold
                                            color: Appearance.colors.colPrimary
                                        }
                                    }
                                }
                                
                                RippleButton {
                                    id: resultItem
                                    
                                    width: parent.width
                                    implicitHeight: 48
                                    buttonRadius: Appearance.rounding.small

                                    colBackground: resultDelegate.ListView.isCurrentItem
                                        ? Appearance.colors.colLayer2
                                        : "transparent"
                                    colBackgroundHover: Appearance.colors.colLayer2

                                    Keys.forwardTo: [overlayResultsList]
                                    onClicked: root.openOverlaySearchResult(resultDelegate.modelData)

                                    contentItem: RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 12
                                        anchors.rightMargin: 12
                                        spacing: 8

                                        // Section indicator
                                        Rectangle {
                                            width: 4
                                            height: 20
                                            radius: 2
                                            color: Appearance.colors.colPrimary
                                            opacity: resultDelegate.ListView.isCurrentItem ? 1 : 0.5
                                        }

                                        // Text content
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 1

                                            Text {
                                                Layout.fillWidth: true
                                                text: resultDelegate.modelData.labelHighlighted || resultDelegate.modelData.label || resultDelegate.modelData.pageName || ""
                                                textFormat: Text.StyledText
                                                font {
                                                    family: Appearance.font.family.main
                                                    pixelSize: Appearance.font.pixelSize.small
                                                    weight: Font.Medium
                                                }
                                                color: Appearance.colors.colOnLayer1
                                                elide: Text.ElideRight
                                            }

                                            // Section breadcrumb (page is in header); drop a
                                            // leading "<pageName> ·/›" prefix to avoid "Panels › Panels · Dock"
                                            StyledText {
                                                readonly property string sectionDisplay: {
                                                    var sect = resultDelegate.modelData.section || "";
                                                    var page = resultDelegate.modelData.pageName || "";
                                                    var parts = sect.split(/\s*[·›]\s*/).filter(t => t.length > 0);
                                                    if (parts.length > 1 && parts[0] === page) parts.shift();
                                                    return parts.join(" › ");
                                                }
                                                visible: sectionDisplay.length > 0 && sectionDisplay !== resultDelegate.modelData.pageName
                                                text: sectionDisplay
                                                font.pixelSize: Appearance.font.pixelSize.smaller
                                                color: Appearance.colors.colSubtext
                                                opacity: 0.8
                                            }
                                        }

                                        // Arrow
                                        MaterialSymbol {
                                            text: "arrow_forward"
                                            iconSize: 16
                                            color: Appearance.colors.colSubtext
                                            opacity: resultItem.hovered || resultDelegate.ListView.isCurrentItem ? 1 : 0
                                        }
                                    }
                                }
                            }
                        }

                        Item { Layout.fillWidth: true }
                    }
                }

                // Escape key handler + Ctrl+F
                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Escape) {
                        if (root.overlaySearchText.length > 0) {
                            root.openOverlaySearchResult({});
                        } else {
                            GlobalStates.settingsOverlayOpen = false
                        }
                        event.accepted = true
                    } else if (event.modifiers === Qt.ControlModifier) {
                        if (event.key === Qt.Key_F) {
                            overlaySearchField.forceActiveFocus();
                            event.accepted = true;
                        } else if (event.key === Qt.Key_PageDown || event.key === Qt.Key_Tab) {
                            overlayCurrentPage = root.nextNavPage(overlayCurrentPage)
                            event.accepted = true
                        } else if (event.key === Qt.Key_PageUp || event.key === Qt.Key_Backtab) {
                            overlayCurrentPage = root.prevNavPage(overlayCurrentPage)
                            event.accepted = true
                        }
                    }
                }

                // Grab focus when opened
                Connections {
                    target: GlobalStates
                    function onSettingsOverlayOpenChanged() {
                        if (GlobalStates.settingsOverlayOpen) {
                            settingsCard.forceActiveFocus()
                        }
                    }
                }
            }
        }
    }

    // ── Page definitions (same as settings.qml) ──
    property int overlayCurrentPage: 0
    property bool _navigationInitialized: false
    property int _prevPage: 0
    property int _slideDir: 1

    function _persistOverlayPage(): void {
        if (root._navigationInitialized && Persistent.ready && Persistent.states?.settings)
            Persistent.states.settings.iiPage = Math.max(0,
                Math.min(root.overlayCurrentPage, root.overlayPages.length - 1))
    }

    function initializeNavigation(): void {
        if (root._navigationInitialized || !Persistent.ready)
            return
        const persisted = Persistent.states?.settings?.iiPage ?? 0
        root.overlayCurrentPage = Math.max(0, Math.min(persisted, root.overlayPages.length - 1))
        root._prevPage = root.overlayCurrentPage
        root._navigationInitialized = true
        root._persistOverlayPage()
    }

    onOverlayCurrentPageChanged: {
        root._slideDir = root.overlayCurrentPage > root._prevPage ? 1 : -1
        root._prevPage = root.overlayCurrentPage
        root._persistOverlayPage()
        // Published for settingsNav, which shell.qml owns for both chromes.
        GlobalStates.settingsOverlayCurrentPage = root.overlayCurrentPage
    }

    Connections {
        target: Persistent
        function onReadyChanged() { root.initializeNavigation() }
    }

    Component.onCompleted: root.initializeNavigation()

    // Categories + pages come from the shared registry; the overlay resolves
    // component paths against the shell root.
    readonly property var navCategories: SettingsPageRegistry.categories

    readonly property var overlayPages: SettingsPageRegistry.pages.map(p => {
        var entry = Object.assign({}, p);
        entry.component = Quickshell.shellPath(p.component);
        return entry;
    })

    // Easy mode helpers
    readonly property bool easyMode: Config.options?.settingsUi?.easyMode ?? false

    // Nav model: category headers + page entries, filtered by easy mode
    readonly property var visibleNavItems: {
        var items = [];
        for (var c = 0; c < navCategories.length; c++) {
            var cat = navCategories[c];
            var catPages = [];
            for (var p = 0; p < cat.pages.length; p++) {
                var pageIdx = cat.pages[p];
                if (pageIdx >= overlayPages.length) continue;
                if (easyMode && overlayPages[pageIdx].essential !== true) continue;
                catPages.push(pageIdx);
            }
            if (catPages.length === 0) continue;
            items.push({ type: "header", label: cat.label });
            for (var j = 0; j < catPages.length; j++) {
                var entry = Object.assign({}, overlayPages[catPages[j]]);
                entry.type = "page";
                entry.realIndex = catPages[j];
                items.push(entry);
            }
        }
        return items;
    }

    // Ordered page indices matching nav rail order (for keyboard nav)
    readonly property var navPageOrder: visibleNavItems.filter(i => i.type === "page").map(i => i.realIndex)

    function nextNavPage(current) {
        var idx = navPageOrder.indexOf(current);
        if (idx < 0) return navPageOrder.length > 0 ? navPageOrder[0] : 0;
        return navPageOrder[(idx + 1) % navPageOrder.length];
    }
    function prevNavPage(current) {
        var idx = navPageOrder.indexOf(current);
        if (idx < 0) return navPageOrder.length > 0 ? navPageOrder[navPageOrder.length - 1] : 0;
        return navPageOrder[(idx - 1 + navPageOrder.length) % navPageOrder.length];
    }

    function setEasyMode(enabled) {
        Config.setNestedValue("settingsUi.easyMode", enabled === true);
    }

    // If user toggles easy mode while on a non-essential page, fall back to first essential one (Quick)
    Connections {
        target: Config.options?.settingsUi ?? null
        function onEasyModeChanged() {
            if (root.easyMode) {
                var current = root.overlayPages[root.overlayCurrentPage];
                if (current && current.essential !== true) {
                    root.overlayCurrentPage = 0;
                }
            }
        }
    }
}
