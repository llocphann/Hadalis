import QtQuick
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.abyss.looks

Item {
    id: root
    readonly property bool abyssMode:
        (Config.options?.panelFamily ?? "ii") === "abyss"
    property bool showAbyssMark: false
    readonly property real markSize:
        19.5 * Appearance.sizes.barModuleScale

    implicitWidth: markSize + 10 * Appearance.sizes.barModuleScale
    implicitHeight: markSize + 10 * Appearance.sizes.barModuleScale

    Item {
        id: markViewport
        anchors.centerIn: parent
        width: root.markSize
        height: root.markSize
        clip: true

        Item {
            id: distroHolder
            width: markViewport.width
            height: markViewport.height
            x: root.abyssMode && root.showAbyssMark ? -width : 0

            CustomIcon {
                anchors.fill: parent
                source: (Config.options?.bar?.topLeftIcon ?? "distro") === "distro"
                    ? SystemInfo.distroIcon
                    : `${Config.options?.bar?.topLeftIcon ?? "distro"}-symbolic`
                colorize: true
                color: Appearance.colors.colOnLayer0
            }

            Behavior on x {
                enabled: root.abyssMode && AbyssStyle.motionEnabled
                NumberAnimation {
                    duration: AbyssStyle.motionNormal
                    easing.type: Easing.InOutCubic
                }
            }
        }

        Item {
            id: abyssHolder
            width: markViewport.width
            height: markViewport.height
            x: root.abyssMode
                ? (root.showAbyssMark ? 0 : width)
                : width

            MaterialSymbol {
                anchors.centerIn: parent
                text: "waves"
                iconSize: root.markSize
                color: AbyssStyle.accent
            }

            Behavior on x {
                enabled: root.abyssMode && AbyssStyle.motionEnabled
                NumberAnimation {
                    duration: AbyssStyle.motionNormal
                    easing.type: Easing.InOutCubic
                }
            }
        }
    }

    Timer {
        interval: 2800
        repeat: true
        running: root.abyssMode && root.visible && AbyssStyle.motionEnabled
        onTriggered: root.showAbyssMark = !root.showAbyssMark
    }

    HoverHandler { id: statusHover }

    StyledToolTip {
        visible: root.abyssMode && statusHover.hovered
        delay: 250
        text: Translation.tr("Surface Performance: %1\nWave Preset: %2")
            .arg(AbyssStyle.quality)
            .arg(Config.options?.abyss?.waves?.preset ?? "balanced")
    }
}
