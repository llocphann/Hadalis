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
    property bool _presentationRequested: false
    property int _presentationReadyFrames: 0
    property bool _presentationCold: true

    function requestPresentation(): void {
        root._presentedOpen = false
        root._presentationRequested = true
        root._presentationReadyFrames = 0
        root._presentationCold = contentLoader.status !== Loader.Ready
        _presentationTimer.restart()
    }

    function tryPresent(): void {
        if (!root._presentationRequested || !GlobalStates.dashboardOpen
                || !panelRoot.visible)
            return
        if (contentLoader.status !== Loader.Ready
                || contentLoader.width <= 0 || contentLoader.height <= 0)
            return

        root._presentationReadyFrames++
        // A freshly-created Dashboard gets two closed frames so Loader geometry
        // and the remapped layer-shell surface both settle. Warm opens need one
        // closed frame before the immutable slide transition starts.
        const requiredFrames = root._presentationCold ? 2 : 1
        if (root._presentationReadyFrames < requiredFrames)
            return

        root._presentationRequested = false
        root._presentationCold = false
        _presentationTimer.stop()
        root._presentedOpen = true
    }

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
                root.requestPresentation()
        }

        Connections {
            target: GlobalStates
            function onDashboardOpenChanged() {
                if (GlobalStates.dashboardOpen) {
                    _closeTimer.stop()
                    panelRoot.visible = true
                    root.requestPresentation()
                } else {
                    root._presentationRequested = false
                    _presentationTimer.stop()
                    root._presentedOpen = false
                    _closeTimer.restart()
                }
            }
        }

        Timer {
            id: _presentationTimer
            interval: 16
            repeat: true
            onTriggered: root.tryPresent()
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
            active: CompositorService.isHyprland
                && GlobalStates.dashboardOpen && panelRoot.visible
            onCleared: () => {
                if (!active) panelRoot.hide()
            }
        }

        // Backdrop click to close
        MouseArea {
            anchors.fill: parent
            enabled: GlobalStates.dashboardOpen
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
            // The outer iiDashboard loader is lazy before first use and retained
            // afterwards, so keep this widget tree mounted for warm reopens.
            active: true
            onStatusChanged: root.tryPresent()
            onWidthChanged: root.tryPresent()
            onHeightChanged: root.tryPresent()

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
                    width: Math.min(
                        standaloneEditToolbar.implicitWidth,
                        Math.max(1, standaloneContent.width - 32))
                    x: Math.round((parent.width - width) / 2)
                    y: 0
                }
            }
        }
    }

}
