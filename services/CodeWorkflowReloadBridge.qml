import QtQuick
import Quickshell

Scope {
    id: bridge
    reloadableId: "code-workflow-reload-bridge"

    property bool persistenceReady: false
    property bool restoring: false

    PersistentProperties {
        id: persisted
        reloadableId: "code-workflow-transaction-state"

        // Primitive-only persistence. The JSON contains semantic command identity,
        // hashes, artifact paths and phase strings; never QObject/QJSValue/ranges.
        property string stateJson: ""

        // loaded fires after every reload stage, including when old state was
        // matched; reloaded is intentionally not used to avoid double recovery.
        onLoaded: bridge.restorePersistedState()
    }

    function restorePersistedState(): void {
        const encoded = String(persisted.stateJson ?? "")
        bridge.restoring = true
        if (encoded.length > 0)
            CodeWorkflowTransaction.restoreReloadStateJson(encoded)
        bridge.restoring = false
        bridge.persistenceReady = true
        persisted.stateJson = CodeWorkflowTransaction.reloadStateJson
    }

    Connections {
        target: CodeWorkflowTransaction

        function onReloadStateJsonChanged(): void {
            if (!bridge.persistenceReady || bridge.restoring)
                return
            persisted.stateJson = CodeWorkflowTransaction.reloadStateJson
        }
    }
}
