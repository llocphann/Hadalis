import QtQuick
import qs.modules.dashboard
import qs.modules.abyss.looks

// Reparent only the controls into the existing output field; the Dashboard
// canvas retains its full dimensions and object identity throughout editing.
Item {
    id: root
    required property var body
    required property var canvasController
    parent: body?.parent ?? null
    objectName: "abyssDashboardEditPopup"
    z: 90
    readonly property real desiredHeight: toolbar.implicitHeight
    readonly property bool editing: canvasController?.editMode ?? false
    readonly property var contentRect: body?.targetRecord?.content
    width: Math.min(toolbar.implicitWidth,
        Math.max(1, contentRect?.width ?? 1), Math.max(1, (parent?.width ?? 1)-24))
    height: desiredHeight
    x: Math.max(12, Math.min((parent?.width ?? 0)-width-12,
        (contentRect?.x ?? 0)+((contentRect?.width ?? 0)-width)/2))
    y: Math.max(8, (contentRect?.y ?? 0)-height-(body?.padding ?? 14)+6)
    visible: editing && (body?.presented ?? false) && (body?.progress ?? 0)>.99
    enabled: visible && (body?.acceptsInput ?? false)
    AbyssParticipant {
        identity: (root.body?.identity ?? "dashboard")+"Editor"
        controller: root.body?.controller ?? null
        geometry: root.visible ? ({edge:root.body.edge,
            surface:{x:root.x-8,y:root.y-8,width:root.width+16,height:root.height+22},
            content:{x:root.x,y:root.y,width:root.width,height:root.height},
            along:root.x,span:root.width,depth:root.height,progress:1}) : null
        inputBounds: root.enabled ? Qt.rect(root.x,root.y,root.width,root.height) : Qt.rect(0,0,0,0)
    }
    DashboardEditToolbar {
        id: toolbar
        anchors.fill: parent
        canvasController: root.canvasController
        embeddedSurface: true
    }
}
