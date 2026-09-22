import QtQuick
import Quickshell
import qs.services

// Registers the lifecycle of one real shell loader with Code Workflow.
// It never dereferences loader.item while loading, so async panel startup stays
// non-blocking. Source/semantic metadata lives beside the loader declaration
// instead of in a central synthetic catalog.
Scope {
    id: root

    required property var loader
    required property string panelId

    property string targetId: CodeWorkflowRuntime.targetIdForPanel(root.panelId)
    property string label: CodeWorkflowRuntime.labelForPanel(root.panelId)
    property string icon: "widgets"
    property string kind: "surface"
    property string family:
        String(root.panelId).startsWith("w") ? "waffle" : "ii"
    property string parentId: ""
    property int depth: 0
    property string sourcePath: ""
    property bool configured: true
    property bool presented: root.loader?.active === true

    property string registrationToken: ""
    readonly property string resolvedSourcePath:
        root.sourcePath.length > 0
            ? root.sourcePath
            : CodeWorkflowRuntime.relativeSourcePath(root.loader?.source ?? "")

    function lifecycleState(): string {
        if (!root.configured)
            return "disabled"
        if (root.loader?.loading === true)
            return "loading"
        if (root.loader?.active !== true)
            return "inactive"
        if (!root.presented)
            return "loaded-hidden"
        return "loaded"
    }

    function stateRank(state: string): int {
        switch (state) {
        case "loaded": return 5
        case "loaded-hidden": return 4
        case "loading": return 3
        case "inactive": return 2
        case "disabled": return 1
        default: return 0
        }
    }

    function descriptorSnapshot(): var {
        const state = root.lifecycleState()
        return {
            targetId: root.targetId,
            label: root.label,
            icon: root.icon,
            kind: root.kind,
            family: root.family,
            panelId: root.panelId,
            parentId: root.parentId,
            depth: root.depth,
            sourcePath: root.resolvedSourcePath,
            state: state,
            stateRank: root.stateRank(state)
        }
    }

    function notifyChanged(): void {
        CodeWorkflowRuntime.touchDeclaration(root.registrationToken)
    }

    Connections {
        target: root.loader
        ignoreUnknownSignals: true
        function onActiveChanged(): void { root.notifyChanged() }
        function onLoadingChanged(): void { root.notifyChanged() }
        function onSourceChanged(): void { root.notifyChanged() }
    }

    onTargetIdChanged: root.notifyChanged()
    onLabelChanged: root.notifyChanged()
    onIconChanged: root.notifyChanged()
    onKindChanged: root.notifyChanged()
    onFamilyChanged: root.notifyChanged()
    onParentIdChanged: root.notifyChanged()
    onDepthChanged: root.notifyChanged()
    onSourcePathChanged: root.notifyChanged()
    onConfiguredChanged: root.notifyChanged()
    onPresentedChanged: root.notifyChanged()

    Component.onCompleted:
        root.registrationToken = CodeWorkflowRuntime.registerDeclaration(root)
    Component.onDestruction:
        CodeWorkflowRuntime.unregisterDeclaration(
            root.registrationToken, root)
}
