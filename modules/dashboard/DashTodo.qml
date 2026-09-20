import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.sidebarRight.todo

/**
 * To-do card. Reuses the sidebar task widget (tabs, add dialog and actions).
 * Fills the column height.
 */
DashCard {
    id: root
    title: Translation.tr("To Do")
    icon: "checklist"
    Layout.fillHeight: true

    TodoWidget {
        Layout.fillWidth: true
        Layout.fillHeight: true
        // DashboardCanvas owns the module minimum. Do not keep an internal
        // 180px floor: it makes the empty-state center drift when the card is
        // resized below that height.
        Layout.minimumHeight: 0
    }
}
