pragma Singleton

import QtQuick
import qs.modules.common.perimeter as PerimeterCore

QtObject {
    id: root

    property bool registered: false

    function registerAll() {
        const registrations = [
            { moduleId: "workspaces", source: Qt.resolvedUrl("WorkspacesModule.qml") },
            { moduleId: "system-monitor", source: Qt.resolvedUrl("SystemMonitorModule.qml") },
            { moduleId: "weather", source: Qt.resolvedUrl("WeatherModule.qml") },
            { moduleId: "media", source: Qt.resolvedUrl("MediaModule.qml") },
            { moduleId: "dock", source: Qt.resolvedUrl("DockModule.qml") },
            { moduleId: "thinkfan", source: Qt.resolvedUrl("ThinkFanModule.qml") }
        ]

        if (root.registered) {
            let registrationsHealthy = true
            for (const registration of registrations) {
                const current = PerimeterCore.ModuleRegistry.resolve(registration.moduleId)
                if (String(current?.source ?? "") !== String(registration.source)) {
                    registrationsHealthy = false
                    break
                }
            }
            if (registrationsHealthy)
                return true
            root.registered = false
        }

        for (const registration of registrations) {
            if (!PerimeterCore.ModuleRegistry.registerModule(registration.moduleId, {
                source: registration.source
            })) {
                root.registered = false
                return false
            }
        }

        root.registered = true
        return true
    }
}
