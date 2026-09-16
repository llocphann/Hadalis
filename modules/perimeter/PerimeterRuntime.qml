pragma ComponentBehavior: Bound

import qs
import qs.modules.common
import qs.modules.common.perimeter
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

    function ensureFeatureRegistry(): void {
        if (!root.active) {
            root.featuresReady = false
            return
        }
        root.featuresReady = PerimeterFeatureRegistry.registerAll()
        if (!root.featuresReady)
            console.warn("[Perimeter] Failed to register runtime module sources")
    }

    Component.onCompleted: root.ensureFeatureRegistry()
    onActiveChanged: root.ensureFeatureRegistry()

    Connections {
        target: ModuleRegistry
        function onModuleUnregistered(moduleId: string): void {
            if (root.active)
                Qt.callLater(root.ensureFeatureRegistry)
        }
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

            screen: modelData
            visible: hostActive
            updatesEnabled: hostActive
            color: "transparent"
            exclusiveZone: 0
            exclusionMode: ExclusionMode.Ignore

            WlrLayershell.namespace: "hadalis:perimeter"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

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

            mask: perimeterWindow.hostActive ? perimeterInputRegion : emptyInputRegion

            PerimeterOutputHost {
                id: outputHost
                anchors.fill: parent
                outputName: perimeterWindow.modelData?.name ?? ""
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
