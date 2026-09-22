import QtQuick
import Quickshell
import qs.services
import qs.modules.common

Scope {
    id: root

    required property Item runtimeObject
    required property string targetId
    property string label: root.targetId
    property string icon: "account_tree"
    property string kind: "component"
    property string family: ""
    property string panelId: ""
    property string parentId: ""
    property int depth: 0
    property string sourcePath: ""

    readonly property var window: root.runtimeObject ? root.runtimeObject.QsWindow.window : null
    readonly property string outputName: root.window?.screen?.name ?? ""
    readonly property string instanceId:
        root.outputName.length > 0 ? root.targetId + "@" + root.outputName : ""

    property string attachedId: ""
    property string token: ""
    property bool completed: false
    property int geometryRevision: 0

    readonly property rect geometry: {
        const dependency = root.geometryRevision
        if (dependency < 0 || !root.runtimeObject || !root.window || !root.window.screen)
            return Qt.rect(0, 0, 0, 0)

        const mapped = root.window.contentItem.mapFromItem(
            root.runtimeObject, 0, 0,
            root.runtimeObject.width, root.runtimeObject.height)

        // Phase 0 qualified only the horizontal ii Bar adapter. Do not generalize
        // Wayland mapToGlobal into cross-layer-shell geometry authority.
        const bottom = Config.options?.bar?.bottom ?? false
        const surfaceY = bottom ? root.window.screen.height - root.window.height : 0
        return Qt.rect(mapped.x, mapped.y + surfaceY, mapped.width, mapped.height)
    }

    function sync(): void {
        if (!root.completed || root.attachedId === root.instanceId)
            return
        if (root.attachedId.length > 0)
            CodeWorkflowRuntime.detach(root.attachedId, root, root.token)
        root.attachedId = root.instanceId
        root.token = root.attachedId.length > 0 ? CodeWorkflowRuntime.attach(root) : ""
    }

    function descriptorSnapshot(): var {
        return {
            targetId: root.targetId,
            label: root.label,
            icon: root.icon,
            kind: root.kind,
            family: root.family,
            panelId: root.panelId,
            parentId: root.parentId,
            depth: root.depth,
            sourcePath: root.sourcePath,
            state: "resident",
            stateRank: 6
        }
    }

    function rectSnapshot(): var {
        const rect = root.geometry
        return {
            x: rect.x, y: rect.y, width: rect.width, height: rect.height,
            revision: root.geometryRevision,
            dpr: root.window?.devicePixelRatio ?? 1,
            barMustShow: root.window?.mustShow ?? false,
            barAutoHide: Config.options?.bar?.autoHide?.enable ?? false,
            eligible: !!root.runtimeObject
                && root.runtimeObject.visible
                && root.runtimeObject.enabled
                && !!root.window?.visible
                && rect.width > 0 && rect.height > 0
        }
    }

    function safeValues(): var {
        if (!root.runtimeObject)
            return null
        // Explicit allowlist; never serialize arbitrary QObject properties.
        return {
            width: root.runtimeObject.width,
            height: root.runtimeObject.height,
            implicitWidth: root.runtimeObject.implicitWidth ?? 0,
            implicitHeight: root.runtimeObject.implicitHeight ?? 0,
            visible: root.runtimeObject.visible,
            enabled: root.runtimeObject.enabled
        }
    }

    TransformWatcher {
        a: root.window?.contentItem ?? null
        b: root.runtimeObject
        onTransformChanged: root.geometryRevision++
    }

    onInstanceIdChanged: root.sync()
    Component.onCompleted: { root.completed = true; root.sync() }
    Component.onDestruction: {
        if (root.attachedId.length > 0)
            CodeWorkflowRuntime.detach(root.attachedId, root, root.token)
    }
}
