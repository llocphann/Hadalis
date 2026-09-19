import QtQuick
import Quickshell
import qs.modules.common

Scope {
    id: probe
    required property Item runtimeObject
    required property string targetId
    readonly property var window: runtimeObject ? runtimeObject.QsWindow.window : null
    readonly property string outputName: window?.screen?.name ?? ""
    readonly property string instanceId: outputName ? targetId + "@" + outputName : ""
    property string attachedId: ""
    property string token: ""
    property bool completed: false
    property int geometryRevision: 0
    readonly property rect geometry: {
        const transform = watcher.transform
        const windowTransform = window?.windowTransform
        const revision = geometryRevision
        if (!runtimeObject || !window || !window.screen) return Qt.rect(0,0,0,0)
        const r = window.contentItem.mapFromItem(runtimeObject, 0, 0, runtimeObject.width, runtimeObject.height)
        // Phase 0 adapter is intentionally ii horizontal Bar only. Under Wayland,
        // mapToGlobal is not an authoritative cross-layer-shell coordinate API.
        // Derive the Bar surface origin from its QML-owned anchors and output.
        const bottom = Config.options?.bar?.bottom ?? false
        return Qt.rect(r.x, r.y + (bottom ? window.screen.height - window.height : 0), r.width, r.height)
    }
    function sync() {
        if (!completed || attachedId === instanceId) return
        if (attachedId) RuntimeRegistry.detach(attachedId, probe, token)
        attachedId = instanceId
        token = attachedId ? RuntimeRegistry.attach(probe) : ""
    }
    function rectSnapshot() {
        const r = geometry
        return {x:r.x, y:r.y, width:r.width, height:r.height,
            revision:geometryRevision, dpr:window?.devicePixelRatio ?? 1,
            eligible:!!runtimeObject && runtimeObject.visible && runtimeObject.enabled
                && !!window?.visible && r.width > 0 && r.height > 0}
    }
    function safeValues() {
        if (!runtimeObject) return null
        return {width:runtimeObject.width, height:runtimeObject.height,
            visible:runtimeObject.visible, enabled:runtimeObject.enabled}
    }
    TransformWatcher {
        id: watcher
        a: probe.window?.contentItem ?? null
        b: probe.runtimeObject
        onTransformChanged: probe.geometryRevision++
    }
    onInstanceIdChanged: sync()
    Component.onCompleted: { completed = true; sync() }
    Component.onDestruction: {
        if (attachedId) RuntimeRegistry.detach(attachedId, probe, token)
    }
}
