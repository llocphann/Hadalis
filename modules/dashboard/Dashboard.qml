import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root
    property bool _presentedOpen: false
    readonly property real screenWidth: panelRoot.screen?.width ?? 1920
    readonly property real screenHeight: panelRoot.screen?.height ?? 1080
    readonly property real safePadding: Math.max(
        Appearance.sizes.hyprlandGapsOut * 2,
        Math.round(Math.min(screenWidth, screenHeight) * 0.02)
    )
    readonly property real barReservedSpace: Appearance.sizes.baseBarHeight + Appearance.sizes.hyprlandGapsOut * 2
    readonly property real topReservedSpace: safePadding
        + (!(Config.options?.bar?.bottom ?? false) ? barReservedSpace : 0)
    readonly property real bottomReservedSpace: safePadding
        + ((Config.options?.bar?.bottom ?? false) ? barReservedSpace : 0)
    readonly property real availablePanelHeight: Math.max(360, screenHeight - topReservedSpace - bottomReservedSpace)
    readonly property real availablePanelWidth: Math.max(480, screenWidth - safePadding * 2)
    readonly property real widthRatio: Math.min(0.9, Math.max(0.4, Config.options?.dashboard?.widthRatio ?? 0.72))
    readonly property real heightRatio: Math.min(0.9, Math.max(0.45, Config.options?.dashboard?.heightRatio ?? 0.72))
    readonly property real panelWidth: Math.round(Math.min(availablePanelWidth, screenWidth * widthRatio))
    readonly property real panelHeight: Math.round(Math.min(availablePanelHeight, screenHeight * heightRatio))

    PanelWindow {
        id: panelRoot

        Component.onCompleted: {
            visible = GlobalStates.dashboardOpen
            if (GlobalStates.dashboardOpen)
                Qt.callLater(() => { root._presentedOpen = GlobalStates.dashboardOpen })
        }

        Connections {
            target: GlobalStates
            function onDashboardOpenChanged() {
                if (GlobalStates.dashboardOpen) {
                    _closeTimer.stop()
                    panelRoot.visible = true
                    Qt.callLater(() => { root._presentedOpen = GlobalStates.dashboardOpen })
                } else {
                    root._presentedOpen = false
                    _closeTimer.restart()
                }
            }
        }

        Timer {
            id: _closeTimer
            interval: SurfaceMotion.duration + 16
            onTriggered: panelRoot.visible = false
        }

        function hide() {
            GlobalStates.dashboardOpen = false
        }

        exclusiveZone: 0
        implicitWidth: screen?.width ?? 1920
        implicitHeight: screen?.height ?? 1080
        WlrLayershell.namespace: "quickshell:dashboard"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: GlobalStates.dashboardOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        color: "transparent"

        anchors {
            top: true
            right: true
            bottom: true
            left: true
        }

        CompositorFocusGrab {
            id: grab
            windows: [ panelRoot ]
            active: CompositorService.isHyprland && panelRoot.visible
            onCleared: () => {
                if (!active) panelRoot.hide()
            }
        }

        // Backdrop click to close
        MouseArea {
            anchors.fill: parent
            onClicked: mouse => {
                const localPos = mapToItem(contentLoader, mouse.x, mouse.y)
                if (localPos.x < 0 || localPos.x > contentLoader.width
                        || localPos.y < 0 || localPos.y > contentLoader.height) {
                    panelRoot.hide()
                }
            }
        }

        Loader {
            id: contentLoader
            active: panelRoot.visible || (Config.options?.dashboard?.keepLoaded ?? false)

            // Shell desaturation effect
            layer.enabled: Appearance.shouldDesaturate("overlays") && contentLoader.visible
            layer.effect: ShellDesaturationEffect {}

            property real panelTranslateY: SurfaceMotion.dashboardOffset
            states: [
                State {
                    name: "open"
                    when: root._presentedOpen
                    PropertyChanges {
                        target: contentLoader
                        panelTranslateY: 0
                    }
                },
                State {
                    name: "closed"
                    when: !root._presentedOpen
                    PropertyChanges {
                        target: contentLoader
                        panelTranslateY: SurfaceMotion.dashboardOffset
                    }
                }
            ]
            transitions: [
                Transition {
                    to: "open"
                    enabled: Appearance.animationsEnabled
                    NumberAnimation {
                        target: contentLoader
                        property: "panelTranslateY"
                        duration: SurfaceMotion.duration
                        easing.type: SurfaceMotion.easingType
                    }
                },
                Transition {
                    to: "closed"
                    enabled: Appearance.animationsEnabled
                    NumberAnimation {
                        target: contentLoader
                        property: "panelTranslateY"
                        duration: SurfaceMotion.duration
                        easing.type: SurfaceMotion.easingType
                    }
                }
            ]

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: Math.round((root.topReservedSpace - root.bottomReservedSpace) / 2)

            width: root.panelWidth
            readonly property real editToolbarReserve:
                (item?.editMode ?? false)
                    ? Math.max(0, Number(item?.editToolbarHeight ?? 0) - 1)
                    : 0
            height: Math.min(root.availablePanelHeight,
                root.panelHeight + contentLoader.editToolbarReserve)

            opacity: 1
            scale: 1
            transform: Translate { y: contentLoader.panelTranslateY }

            focus: GlobalStates.dashboardOpen
            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    panelRoot.hide()
                }
            }

            sourceComponent: Item {
                id: standaloneDashboardHost

                property alias editMode: standaloneContent.editMode
                readonly property real editToolbarHeight:
                    standaloneEditToolbar.implicitHeight

                DashboardContent {
                    id: standaloneContent
                    x: 0
                    y: standaloneEditToolbar.visible
                        ? Math.max(0, standaloneEditToolbar.height - 1)
                        : 0
                    width: parent.width
                    height: Math.max(0, parent.height - y)
                    screenWidth: panelRoot.screen?.width ?? 1920
                    screenHeight: panelRoot.screen?.height ?? 1080
                }

                DashboardEditToolbar {
                    id: standaloneEditToolbar
                    z: 8
                    canvasController: standaloneContent.canvasController
                    width: Math.min(440,
                        Math.max(280, standaloneContent.width - 32))
                    x: Math.round((parent.width - width) / 2)
                    y: 0
                }
            }
        }
    }

}
