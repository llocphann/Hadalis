pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.modules.perimeter
import qs.modules.common
import qs.modules.common.perimeter

Item {
    id: root

    readonly property bool barVertical: Config.options?.bar?.vertical ?? false
    readonly property bool perimeterRequested: PerimeterCutoverPolicy.requested
    // Cut over only when the user requested perimeter, every connected output
    // validates, and every placed module source is resolvable. Invalid/corrupt
    // perimeter state therefore falls back to legacy chrome.
    readonly property bool perimeterEnabled: PerimeterCutoverPolicy.enabled
    property bool perimeterRegistrationReady: false

    function ensurePerimeterFeatures(): void {
        if (!root.perimeterRequested) {
            root.perimeterRegistrationReady = false
            return
        }
        root.perimeterRegistrationReady = PerimeterFeatureRegistry.registerAll()
        if (!root.perimeterRegistrationReady)
            console.warn("[Perimeter] Critical bootstrap could not register module sources")
    }

    Component.onCompleted: root.ensurePerimeterFeatures()
    onPerimeterRequestedChanged: root.ensurePerimeterFeatures()

    Connections {
        target: ModuleRegistry
        function onModuleRegistered(moduleId: string): void {
            // A later registration may replace a perimeter source with a stale
            // or foreign URL. Re-run the registry health check after the current
            // registration completes; registerAll() is idempotent when healthy.
            if (root.perimeterRequested)
                Qt.callLater(root.ensurePerimeterFeatures)
        }
        function onModuleUnregistered(moduleId: string): void {
            if (root.perimeterRequested)
                Qt.callLater(root.ensurePerimeterFeatures)
        }
    }

    component CriticalPanelLoader: LazyLoader {
        required property string identifier
        property bool extraCondition: true
        active: Config.ready
            && (Config.options?.enabledPanels ?? []).includes(identifier)
            && extraCondition
    }

    // Keep presentation QML behind URL boundaries. A syntax or local-type
    // failure in an optional surface must not make this critical root unavailable
    // before its LazyLoader activation policy can be evaluated.
    LazyLoader {
        active: Config.ready && root.perimeterEnabled
        source: Qt.resolvedUrl("../../perimeter/PerimeterRuntime.qml")
    }

    CriticalPanelLoader {
        identifier: "iiBackground"
        source: Qt.resolvedUrl("../../background/Background.qml")
    }
    CriticalPanelLoader {
        identifier: "iiBar"
        extraCondition: !root.perimeterEnabled && !root.barVertical
        source: Qt.resolvedUrl("../../bar/Bar.qml")
    }
    CriticalPanelLoader {
        identifier: "iiVerticalBar"
        extraCondition: !root.perimeterEnabled && root.barVertical
        source: Qt.resolvedUrl("../../verticalBar/VerticalBar.qml")
    }
    CriticalPanelLoader {
        identifier: "iiDock"
        extraCondition: !root.perimeterEnabled && (Config.options?.dock?.enable ?? true)
        source: Qt.resolvedUrl("../../dock/Dock.qml")
    }
}
