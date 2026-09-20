import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

/**
 * Shared Material card surface for Dashboard modules.
 *
 * Dashboard cards deliberately use the same M3 surface-container vocabulary as
 * existing Weather/Sidebar cards. Global shell-style renderers do not own this
 * background; they may still influence content-specific typography elsewhere.
 */
Rectangle {
    id: root

    property string title: ""
    property string icon: ""
    default property alias content: inner.data

    readonly property bool compact:
        (Config.options?.dashboard?.appearance?.density ?? "comfortable")
            === "compact"
    readonly property real cardOpacity: Math.max(0.3, Math.min(1,
        Config.options?.dashboard?.appearance?.cardOpacity ?? 1))
    readonly property bool showTitle:
        Config.options?.dashboard?.appearance?.showCardTitles ?? true
    readonly property real pad: compact ? 8 : 12

    // Compatibility properties consumed by a few Dashboard content components.
    // They no longer select the card background: Material owns the surface.
    readonly property bool inirEverywhere: Appearance.inirEverywhere
    readonly property bool auroraEverywhere: Appearance.auroraEverywhere
    readonly property bool zzzEverywhere: Appearance.zzzEverywhere

    readonly property color colText: Appearance.colors.colOnSurface
    readonly property color colSubtext: Appearance.colors.colOnSurfaceVariant
    readonly property color colAccent: Appearance.colors.colPrimary

    Layout.fillWidth: true
    implicitHeight: contentColumn.implicitHeight + root.pad * 2

    radius: Appearance.rounding.small
    color: root.cardOpacity >= 0.999
        ? Appearance.colors.colSurfaceContainerHigh
        : ColorUtils.applyAlpha(
            Appearance.colors.colSurfaceContainerHigh,
            root.cardOpacity * Appearance.colors.colSurfaceContainerHigh.a)
    border.width: 0
    border.color: "transparent"
    clip: true

    Behavior on color {
        enabled: Appearance.animationsEnabled
        ColorAnimation {
            duration: Appearance.animation.elementMoveFast.duration
            easing.type: Appearance.animation.elementMoveFast.type
            easing.bezierCurve:
                Appearance.animation.elementMoveFast.bezierCurve
        }
    }

    ColumnLayout {
        id: contentColumn
        anchors.fill: parent
        anchors.margins: root.pad
        spacing: root.compact ? 6 : 8

        RowLayout {
            visible: root.title.length > 0 && root.showTitle
            Layout.fillWidth: true
            spacing: 8

            MaterialSymbol {
                visible: root.icon.length > 0
                text: root.icon
                iconSize: Appearance.font.pixelSize.larger
                color: root.colAccent
            }

            StyledText {
                Layout.fillWidth: true
                text: root.title
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.Medium
                color: root.colText
                elide: Text.ElideRight
            }
        }

        ColumnLayout {
            id: inner
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8

            // Non-filling children sit naturally in the center of their card;
            // full-width/full-height widgets keep ownership of their alignment.
            Component.onCompleted: {
                for (let i = 0; i < inner.children.length; i++) {
                    const child = inner.children[i]
                    if (child.Layout
                            && child.Layout.fillWidth !== true
                            && child.Layout.fillHeight !== true
                            && child.Layout.alignment === 0) {
                        child.Layout.alignment =
                            Qt.AlignHCenter | Qt.AlignVCenter
                    }
                }
            }
        }
    }
}
