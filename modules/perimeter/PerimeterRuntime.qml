pragma ComponentBehavior: Bound

import qs
import qs.modules.common
import qs.modules.common.perimeter
import qs.services
import QtQuick
import Quickshell
import Quickshell.Wayland

Scope {
    id: root

    property bool active: true
    property bool featuresReady: false
    property real slotSpacing: 8
    property real topInset: 0
    property real bottomInset: 0
    property real leftInset: 0
    property real rightInset: 0
    readonly property var runtimeOutputNames: Quickshell.screens
        .map(screen => String(screen?.name ?? ""))
        .filter(name => name.length > 0)

    function ensureFeatureRegistry(): void {
        if (!root.active) {
            root.featuresReady = false
            return
        }
        root.featuresReady = PerimeterFeatureRegistry.registerAll()
        if (!root.featuresReady)
            console.warn("[Perimeter] Failed to register runtime module sources")
    }

    function outputHasModule(outputName: string, moduleId: string): bool {
        const name = String(outputName ?? "")
        const module = String(moduleId ?? "")
        if (!name || !module || !PerimeterConfig.validate(name))
            return false
        for (const slotId of PerimeterTopology.slotIds) {
            for (const instanceId of PerimeterConfig.slotInstanceIds(name, slotId)) {
                const descriptor = PerimeterConfig.instanceDescriptor(name, instanceId)
                if (String(descriptor?.moduleId ?? "") === module)
                    return true
            }
        }
        return false
    }

    function outputsWithModule(moduleId: string): var {
        // Sidebar semantic routing still honors sidebar.screenList. Perimeter
        // placement controls where a module exists; screenList controls which
        // connected outputs are eligible to present the singular sidebar state.
        const allowed = GlobalStates.connectedOutputNames(
            Config.options?.sidebar?.screenList ?? [])
        return root.runtimeOutputNames.filter(name => allowed.includes(name)
            && root.outputHasModule(name, moduleId))
    }

    function syncSidebarRoute(featureRole: bool): void {
        const open = featureRole
            ? GlobalStates.sidebarLeftOpen : GlobalStates.sidebarRightOpen
        if (!open)
            return

        // Global sidebar state can be toggled independently through IPC/keybinds.
        // Never route or retain a perimeter presentation for a panel the user has
        // disabled in enabledPanels; doing so can leave an invisible Overlay/focus
        // surface even though the owning legacy panel is intentionally disabled.
        if (!PerimeterPresentationPolicy.sidebarSurfaceEnabled(featureRole)) {
            if (featureRole)
                GlobalStates.closeSidebarLeft()
            else
                GlobalStates.closeSidebarRight()
            return
        }

        const moduleId = featureRole ? "left-sidebar" : "right-sidebar"
        const eligible = root.outputsWithModule(moduleId)
        if (eligible.length === 0) {
            if (featureRole)
                GlobalStates.closeSidebarLeft()
            else
                GlobalStates.closeSidebarRight()
            return
        }

        const currentOutput = featureRole
            ? GlobalStates.sidebarLeftPresentationOutput
            : GlobalStates.sidebarRightPresentationOutput
        if (eligible.includes(currentOutput))
            return

        const resolved = GlobalStates.resolveOutputName("", eligible)
        if (!resolved) {
            if (featureRole)
                GlobalStates.closeSidebarLeft()
            else
                GlobalStates.closeSidebarRight()
            return
        }

        if (featureRole)
            GlobalStates.openSidebarLeft(resolved)
        else
            GlobalStates.openSidebarRight(resolved)
    }

    function syncSidebarRoutes(): void {
        if (!root.active)
            return
        root.syncSidebarRoute(true)
        root.syncSidebarRoute(false)
    }

    Component.onCompleted: {
        root.ensureFeatureRegistry()
        Qt.callLater(root.syncSidebarRoutes)
    }
    onActiveChanged: {
        root.ensureFeatureRegistry()
        if (root.active)
            Qt.callLater(root.syncSidebarRoutes)
    }
    onRuntimeOutputNamesChanged: {
        if (root.active)
            Qt.callLater(root.syncSidebarRoutes)
    }

    Connections {
        target: ModuleRegistry
        function onModuleRegistered(moduleId: string): void {
            // registerModule() can overwrite a healthy source with a stale or
            // foreign URL. Re-check the feature registry after that write settles.
            if (root.active)
                Qt.callLater(root.ensureFeatureRegistry)
        }
        function onModuleUnregistered(moduleId: string): void {
            if (root.active)
                Qt.callLater(root.ensureFeatureRegistry)
        }
    }

    Connections {
        target: Config
        function onRevisionChanged(): void {
            if (root.active)
                Qt.callLater(root.syncSidebarRoutes)
        }
    }

    Connections {
        target: GlobalStates
        function onSidebarLeftOpenChanged(): void {
            if (GlobalStates.sidebarLeftOpen)
                Qt.callLater(() => root.syncSidebarRoute(true))
        }
        function onSidebarRightOpenChanged(): void {
            if (GlobalStates.sidebarRightOpen)
                Qt.callLater(() => root.syncSidebarRoute(false))
        }
        function onSidebarLeftPresentationOutputChanged(): void {
            if (GlobalStates.sidebarLeftOpen)
                Qt.callLater(() => root.syncSidebarRoute(true))
        }
        function onSidebarRightPresentationOutputChanged(): void {
            if (GlobalStates.sidebarRightOpen)
                Qt.callLater(() => root.syncSidebarRoute(false))
        }
    }

    // Layer-shell exclusive zones require an unambiguous edge (1 or 3 anchors).
    // Keep compositor work-area reservation in tiny click-through windows instead
    // of applying it to the four-anchor fullscreen visual/input host.
    component EdgeReservationWindow: PanelWindow {
        required property ShellScreen modelData
        required property string edge

        readonly property string outputName: String(modelData?.name ?? "")
        readonly property bool horizontal: edge === "top" || edge === "bottom"
        readonly property int zone: PerimeterReservationPolicy.zoneForOutputEdge(
            outputName, edge)
        readonly property bool mapped: root.active
            && root.featuresReady
            && PerimeterCutoverPolicy.enabled
            && Config.ready
            && !GlobalStates.screenLocked
            && !GlobalStates.widgetEditMode
            && zone > 0

        screen: modelData
        visible: mapped
        updatesEnabled: mapped
        color: "transparent"
        exclusiveZone: zone
        implicitWidth: horizontal ? 0 : 1
        implicitHeight: horizontal ? 1 : 0

        WlrLayershell.namespace: "hadalis:perimeter-reserve-" + edge
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        anchors {
            top: edge === "top" || edge === "left" || edge === "right"
            bottom: edge === "bottom" || edge === "left" || edge === "right"
            left: edge === "left" || edge === "top" || edge === "bottom"
            right: edge === "right" || edge === "top" || edge === "bottom"
        }

        Item {
            id: emptyReservationInput
            width: 0
            height: 0
            visible: false
        }
        mask: Region { item: emptyReservationInput }
    }

    Variants {
        model: root.active && root.featuresReady ? Quickshell.screens : []
        EdgeReservationWindow { edge: "top" }
    }

    Variants {
        model: root.active && root.featuresReady ? Quickshell.screens : []
        EdgeReservationWindow { edge: "bottom" }
    }

    Variants {
        model: root.active && root.featuresReady ? Quickshell.screens : []
        EdgeReservationWindow { edge: "left" }
    }

    Variants {
        model: root.active && root.featuresReady ? Quickshell.screens : []
        EdgeReservationWindow { edge: "right" }
    }

    Variants {
        model: root.active && root.featuresReady ? Quickshell.screens : []

        PanelWindow {
            id: perimeterWindow

            required property ShellScreen modelData
            readonly property bool hostActive: root.active
                && root.featuresReady
                && Config.ready
                && !GlobalStates.screenLocked
            readonly property string outputName: modelData?.name ?? ""
            readonly property bool leftSidebarPresented: hostActive
                && PerimeterPresentationPolicy.sidebarSurfaceEnabled(true)
                && GlobalStates.sidebarLeftOpen
                && GlobalStates.sidebarLeftPresentationOutput === outputName
            readonly property bool rightSidebarPresented: hostActive
                && PerimeterPresentationPolicy.sidebarSurfaceEnabled(false)
                && GlobalStates.sidebarRightOpen
                && GlobalStates.sidebarRightPresentationOutput === outputName
            readonly property bool sidebarPresented:
                leftSidebarPresented || rightSidebarPresented
            readonly property bool hasChrome: outputHost.configValid && (
                outputHost.topStartOccupied
                || outputHost.topCenterOccupied
                || outputHost.topEndOccupied
                || outputHost.leftCenterOccupied
                || outputHost.rightCenterOccupied
                || outputHost.bottomStartOccupied
                || outputHost.bottomCenterOccupied
                || outputHost.bottomEndOccupied)
            readonly property bool mapped: hostActive && hasChrome

            screen: modelData
            visible: mapped
            updatesEnabled: mapped
            color: "transparent"
            exclusiveZone: 0
            exclusionMode: ExclusionMode.Ignore

            WlrLayershell.namespace: "hadalis:perimeter"
            // ShellIiPanelsImpl already owns the full-screen Top-layer sidebar
            // backdrop. Elevate only while a perimeter sidebar is presented so
            // sidebar content stays above that backdrop without moving ordinary
            // perimeter chrome to Overlay for the rest of the session.
            WlrLayershell.layer: sidebarPresented
                ? WlrLayer.Overlay : WlrLayer.Top
            // Base perimeter chrome must never steal keyboard focus. A presented
            // sidebar, however, contains text fields and other focusable controls;
            // allow those controls to request focus only on the owning output.
            WlrLayershell.keyboardFocus: sidebarPresented
                ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            Item {
                id: emptyInputArea
                width: 0
                height: 0
                visible: false
            }

            Region {
                id: emptyInputRegion
                item: emptyInputArea
            }

            Region {
                id: perimeterInputRegion
                Region { item: outputHost.topStartOccupied ? outputHost.topStartSlot : emptyInputArea }
                Region { item: outputHost.topCenterOccupied ? outputHost.topCenterSlot : emptyInputArea }
                Region { item: outputHost.topEndOccupied ? outputHost.topEndSlot : emptyInputArea }
                Region { item: outputHost.leftCenterOccupied ? outputHost.leftCenterSlot : emptyInputArea }
                Region { item: outputHost.rightCenterOccupied ? outputHost.rightCenterSlot : emptyInputArea }
                Region { item: outputHost.bottomStartOccupied ? outputHost.bottomStartSlot : emptyInputArea }
                Region { item: outputHost.bottomCenterOccupied ? outputHost.bottomCenterSlot : emptyInputArea }
                Region { item: outputHost.bottomEndOccupied ? outputHost.bottomEndSlot : emptyInputArea }
            }

            mask: perimeterWindow.mapped ? perimeterInputRegion : emptyInputRegion

            CompositorFocusGrab {
                windows: [perimeterWindow]
                active: perimeterWindow.mapped
                    && perimeterWindow.sidebarPresented
                    && CompositorService.isHyprland
                onCleared: () => {
                    if (perimeterWindow.leftSidebarPresented
                            && !GlobalStates.sidebarLeftHoldOpen)
                        GlobalStates.closeSidebarLeft()
                    if (perimeterWindow.rightSidebarPresented)
                        GlobalStates.closeSidebarRight()
                }
            }

            PerimeterOutputHost {
                id: outputHost
                anchors.fill: parent
                outputName: perimeterWindow.outputName
                hostEnabled: perimeterWindow.hostActive
                slotSpacing: root.slotSpacing
                topInset: root.topInset
                bottomInset: root.bottomInset
                leftInset: root.leftInset
                rightInset: root.rightInset
            }
        }
    }
}
