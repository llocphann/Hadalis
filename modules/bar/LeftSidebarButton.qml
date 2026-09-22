import QtQuick
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

RippleButton {
    id: root
    cookieMorphing: true

    property bool showPing: false

    Accessible.name: Translation.tr("Toggle left sidebar")

    property real buttonPadding: 5 * Appearance.sizes.barModuleScale
    implicitWidth: distroIcon.width + buttonPadding * 2
    implicitHeight: distroIcon.height + buttonPadding * 2
    buttonRadius: Appearance.rounding.full
    colBackgroundHover: Appearance.colors.colLayer1Hover
    colRipple: Appearance.colors.colLayer1Active
    colBackgroundToggled: Appearance.colors.colSecondaryContainer
    colBackgroundToggledHover: Appearance.colors.colSecondaryContainerHover
    colRippleToggled: Appearance.colors.colSecondaryContainerActive
    // Spatial control: addresses whatever sidebar role occupies the left slot.
    toggled: ShellLayoutController.sidebarOpenAtSlot("left",
        root.QsWindow.window?.screen?.name ?? "")

    onClicked: {
        ShellLayoutController.toggleSidebarAtSlot("left",
            root.QsWindow.window?.screen?.name ?? "");
    }

    Connections {
        target: Ai
        function onResponseFinished() {
            if (GlobalStates.sidebarLeftOpen) return;
            root.showPing = true;
        }
    }

    Connections {
        target: Booru
        function onResponseFinished() {
            if (GlobalStates.sidebarLeftOpen) return;
            root.showPing = true;
        }
    }

    Connections {
        target: Wallhaven
        function onResponseFinished() {
            if (GlobalStates.sidebarLeftOpen) return;
            root.showPing = true;
        }
    }

    Connections {
        target: GlobalStates
        function onSidebarLeftOpenChanged() {
            root.showPing = false;
        }
    }

    CustomIcon {
        id: distroIcon
        anchors.centerIn: parent
        width: 19.5 * Appearance.sizes.barModuleScale
        height: 19.5 * Appearance.sizes.barModuleScale
        source: (Config.options?.bar?.topLeftIcon ?? 'distro') == 'distro' ? SystemInfo.distroIcon : `${Config.options?.bar?.topLeftIcon ?? 'distro'}-symbolic`
        colorize: true
        color: Appearance.colors.colOnLayer0

        Rectangle {
            opacity: root.showPing ? 1 : 0
            visible: opacity > 0
            anchors {
                bottom: parent.bottom
                right: parent.right
                bottomMargin: -2 * Appearance.sizes.barModuleScale
                rightMargin: -2 * Appearance.sizes.barModuleScale
            }
            implicitWidth: 8 * Appearance.sizes.barModuleScale
            implicitHeight: 8 * Appearance.sizes.barModuleScale
            radius: Appearance.rounding.full
            color: Appearance.colors.colTertiary
            Behavior on color {
                enabled: Appearance.animationsEnabled
                ColorAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
            }

            Behavior on opacity {
                enabled: Appearance.animationsEnabled
                animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
            }
        }
    }
}
