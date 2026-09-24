import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root
    implicitWidth: distroIcon.width + 10 * Appearance.sizes.barModuleScale
    implicitHeight: distroIcon.height + 10 * Appearance.sizes.barModuleScale

    CustomIcon {
        id: distroIcon
        anchors.centerIn: parent
        width: 19.5 * Appearance.sizes.barModuleScale
        height: 19.5 * Appearance.sizes.barModuleScale
        source: (Config.options?.bar?.topLeftIcon ?? "distro") === "distro"
            ? SystemInfo.distroIcon
            : `${Config.options?.bar?.topLeftIcon ?? "distro"}-symbolic`
        colorize: true
        color: Appearance.colors.colOnLayer0
    }
}
