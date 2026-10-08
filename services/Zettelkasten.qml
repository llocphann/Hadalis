pragma ComponentBehavior: Bound
pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root
    readonly property var implementation: Hadalird.session?.zettelkasten ?? (null)
    property string missingOperationError: ""
    readonly property string configuredVaultPath: root.implementation?.configuredVaultPath ?? ("")
    readonly property string folder: root.implementation?.folder ?? ("")
    readonly property string defaultType: root.implementation?.defaultType ?? ("")
    readonly property bool ready: root.implementation?.ready ?? (false)
    readonly property bool busy: root.implementation?.busy ?? (false)
    readonly property string errorCode: root.implementation?.errorCode ?? (root.missingOperationError ? "integration-unavailable" : "")
    readonly property string errorMessage: root.implementation?.errorMessage ?? (root.missingOperationError)
    readonly property string lastCreatedPath: root.implementation?.lastCreatedPath ?? ("")
    readonly property string lastCreatedFullPath: root.implementation?.lastCreatedFullPath ?? ("")
    readonly property string helperPath: root.implementation?.helperPath ?? ("")
    signal captured(var payload)
    function capture(title, body): bool {
        if (root.implementation) return root.implementation.capture(title, body)
        root.missingOperationError = "Install and enable the Hadalird integration to use this action"
        return false
    }
    function openLast(): bool {
        if (root.implementation) return root.implementation.openLast()
        root.missingOperationError = "Install and enable the Hadalird integration to use this action"
        return false
    }
    Connections {
        target: root.implementation
        function onCaptured(payload): void {root.captured(payload)}
    }
}
