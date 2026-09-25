import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import Quickshell

Item {
    id: root
    readonly property var focusedWindow: {
        const wins = NiriService.windows
        for (var i = 0; i < wins.length; ++i) {
            const w = wins[i]
            if (w && w.is_focused)
                return w
        }
        return null
    }

    function shortenText(str, maxLen) {
        if (!str)
            return ""
        const s = str.toString()
        if (s.length <= maxLen)
            return s
        return s.slice(0, maxLen - 3) + "..."
    }

    property string displayAppName: {
        const w = root.focusedWindow
        if (w) {
            const base = w.app_id || w.appId || Translation.tr("Desktop")
            return root.shortenText(base, 40)
        }
        return Translation.tr("Desktop")
    }

    property string displayTitle: {
        const w = root.focusedWindow
        if (w?.title)
            return root.shortenText(w.title, 80)
        const wsNum = NiriService.getCurrentWorkspaceNumber()
        return root.shortenText(`${Translation.tr("Workspace")} ${wsNum}`, 80)
    }

    // Terminal spinners and browser progress titles can change many times per
    // second. Keep app/focus identity reactive, but do not keep dirtying an
    // auto-hidden Bar (or an inactive taskbar replacement) just to settle text.
    property bool presentationActive: true
    readonly property bool titlePresentationActive:
        root.presentationActive && root.visible
    property string stableDisplayTitle: displayTitle
    Component.onCompleted: stableDisplayTitle = displayTitle
    onDisplayTitleChanged: {
        if (root.titlePresentationActive)
            titleSettleTimer.restart()
    }
    onTitlePresentationActiveChanged: {
        if (!root.titlePresentationActive) {
            titleSettleTimer.stop()
            return
        }
        // Reveal with the newest title immediately; no stale 180 ms frame.
        root.stableDisplayTitle = root.displayTitle
    }
    Timer {
        id: titleSettleTimer
        interval: 180
        repeat: false
        onTriggered: root.stableDisplayTitle = root.displayTitle
    }

    // Intentionally NOT binding implicitWidth to colLayout.implicitWidth:
    // the bar wrapper assigns this item its width via Layout.fillWidth, and the
    // texts elide to fit. Binding to content width would let a long title push
    // the whole bar around on every title change.
    implicitWidth: 0
    clip: true
    // Natural content width, exposed so a content-sized host (e.g. a centre
    // pill, which gives no fill slack) can grant a sensible, clamped width.
    readonly property real contentImplicitWidth: Math.max(
        appNameText.implicitWidth,
        titleText.visible ? titleText.implicitWidth : 0
    )

    readonly property bool showTitle: Config.options?.bar?.activeWindow?.showTitle ?? true

    property color titleColor: Appearance.colors.colOnLayer0
    property color appNameColor: Appearance.colors.colSubtext

    // Lock both rows to baselines derived from the configured UI font. Emoji,
    // Nerd Font symbols and other fallback glyphs may report taller bounds, but
    // they can no longer move either row or change the gap between them.
    readonly property real rowOverlap: root.showTitle ? 2 * Appearance.sizes.barModuleScale : 0
    readonly property real textBlockHeight: root.showTitle
        ? appNameMetrics.height + titleMetrics.height - root.rowOverlap
        : appNameMetrics.height
    readonly property real textBlockTop: Math.round((root.height - root.textBlockHeight) / 2)
    readonly property real appNameBaseline: root.textBlockTop + appNameMetrics.ascent
    readonly property real titleBaseline: root.appNameBaseline
        + appNameMetrics.descent
        - root.rowOverlap
        + titleMetrics.ascent

    FontMetrics {
        id: appNameMetrics
        font: appNameText.font
    }

    FontMetrics {
        id: titleMetrics
        font: titleText.font
    }

    StyledText {
        id: appNameText
        width: root.width
        y: root.appNameBaseline - baselineOffset
        maximumLineCount: 1
        wrapMode: Text.NoWrap
        font.pixelSize: Math.round(Appearance.font.pixelSize.smaller * Appearance.sizes.barModuleScale)
        color: root.appNameColor
        elide: Text.ElideRight
        text: root.displayAppName
    }

    StyledText {
        id: titleText
        width: root.width
        y: root.titleBaseline - baselineOffset
        visible: root.showTitle
        maximumLineCount: 1
        wrapMode: Text.NoWrap
        font.pixelSize: Math.round(Appearance.font.pixelSize.small * Appearance.sizes.barModuleScale)
        color: root.titleColor
        elide: Text.ElideRight
        text: root.stableDisplayTitle
    }

}
