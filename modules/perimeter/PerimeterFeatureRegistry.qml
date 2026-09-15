pragma Singleton

import QtQuick
import qs.modules.common.perimeter as PerimeterCore

QtObject {
    id: root

    property bool registered: false

    function registerAll() {
        if (root.registered)
            return true

        const registrations = [
            { moduleId: "workspaces", source: Qt.resolvedUrl("WorkspacesModule.qml") },
            { moduleId: "system-monitor", source: Qt.resolvedUrl("SystemMonitorModule.qml") },
            { moduleId: "weather", source: Qt.resolvedUrl("WeatherModule.qml") },
            { moduleId: "media", source: Qt.resolvedUrl("MediaModule.qml") },
            { moduleId: "dock", source: Qt.resolvedUrl("DockModule.qml") }
        ]

        for (const registration of registrations) {
            if (!PerimeterCore.ModuleRegistry.registerModule(registration.moduleId, {
                source: registration.source
            }))
                return false
        }

        root.registered = true
        return true
    }
}
