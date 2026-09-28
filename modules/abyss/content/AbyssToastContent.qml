pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs
import qs.modules.common
import qs.modules.common.widgets

// Presentation adapter only. ToastManager still owns queueing, debounce,
// cooldown, suppression and last-toast retract timing.
Item {
    id: root
    readonly property var manager: GlobalStates.toastManager
    readonly property real desiredWidth: Math.max(260,
        Math.min(520, toastColumn.implicitWidth))
    readonly property real desiredHeight: Math.max(44,
        Math.min(700, toastColumn.implicitHeight))
    implicitWidth: desiredWidth
    implicitHeight: desiredHeight

    ColumnLayout {
        id: toastColumn
        anchors.fill: parent
        spacing: root.manager?.toastSpacing ?? 8

        Repeater {
            model: root.manager?.toasts ?? []

            delegate: ToastNotification {
                required property var modelData
                required property int index
                Layout.alignment: Qt.AlignRight
                connectedSurface: true
                title: modelData.title
                message: modelData.message
                icon: modelData.icon
                isError: modelData.isError
                duration: modelData.duration
                source: modelData.source
                accentColor: modelData.accentColor
                opacity: 1
                scale: 1
                onDismissed: root.manager?.dismissToast(modelData.id)
            }
        }
    }
}
