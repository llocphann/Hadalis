pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.sidebarRight.events

Item {
    id: root

    property int screenWidth: 1920
    property int screenHeight: 1080
    property bool embeddedSurface: false
    property bool presentationActive: GlobalStates.dashboardOpen || GlobalStates.overviewOpen

    readonly property bool showHeader: Config.options?.dashboard?.showHeader ?? true

    property var _agendaEditEvent: null
    property var _agendaPrefillDate: null
    property bool _agendaDialogShown: false
    property bool _agendaDialogLoaded: false

    function openAgendaDialog(arg) {
        const isDate = arg instanceof Date
        root._agendaEditEvent = (arg && !isDate) ? arg : null
        root._agendaPrefillDate = isDate ? arg : null
        root._agendaDialogLoaded = true
        if (agendaDialogLoader.item) {
            if (root._agendaEditEvent) {
                agendaDialogLoader.item.loadEvent(root._agendaEditEvent)
            } else {
                agendaDialogLoader.item.resetForm()
                if (root._agendaPrefillDate)
                    agendaDialogLoader.item.eventDate = root._agendaPrefillDate
            }
        }
        root._agendaDialogShown = true
    }

    // Dashboard does not own a separate background renderer. Detached Dashboard
    // uses the same canonical Material layer-0 surface and shadow vocabulary as
    // existing ii popups/sidebars; the launcher-embedded form stays transparent
    // because OverviewDashboard already owns that same layer-0 surface.
    StyledRectangularShadow {
        target: background
        radius: background.radius
        blur: Math.max(0, Math.min(32,
            Math.round(Config.options?.appearance?.screenEdge?.shadow?.size ?? 15)))
        spread: 0
        offset: Qt.vector2d(0, 0)
        color: ColorUtils.applyAlpha(Appearance.colors.colShadow,
            Math.max(0, Math.min(1.0,
                Number(Config.options?.appearance?.screenEdge?.shadow?.opacity ?? 0.70))))
        visible: !root.embeddedSurface
            && (Config.options?.appearance?.screenEdge?.shadow?.enabled ?? true)
            && !Appearance.gameModeMinimal
    }

    Rectangle {
        id: background
        anchors.fill: parent
        clip: true
        color: root.embeddedSurface ? "transparent" : Appearance.colors.colLayer0
        radius: root.embeddedSurface ? 0 : Appearance.rounding.large
        border.width: 0
        border.color: "transparent"

        ColumnLayout {
            id: mainColumn
            readonly property bool compact:
                (Config.options?.dashboard?.appearance?.density ?? "comfortable")
                    === "compact"
            anchors.fill: parent
            anchors.margins: root.embeddedSurface
                ? 0 : (compact ? 12 : 16)
            spacing: compact ? 8 : 12

            DashboardHeader {
                id: dashboardHeader
                Layout.fillWidth: true
                visible: root.showHeader
                editMode: dashboardCanvas.editMode
                onEditModeRequested:
                    dashboardCanvas.editMode = !dashboardCanvas.editMode
            }

            DashboardCanvas {
                id: dashboardCanvas
                Layout.fillWidth: true
                Layout.fillHeight: true
                presentationActive: root.presentationActive
                showStandaloneEditButton: !root.showHeader
                onRequestEventsDialog: event => root.openAgendaDialog(event)
            }
        }

        Loader {
            id: agendaDialogLoader
            anchors.fill: parent
            z: 200
            active: root._agendaDialogLoaded
            sourceComponent: EventsDialog {}
            onLoaded: {
                item.show = Qt.binding(() => root._agendaDialogShown)
                if (root._agendaEditEvent) {
                    item.loadEvent(root._agendaEditEvent)
                } else {
                    item.resetForm()
                    if (root._agendaPrefillDate)
                        item.eventDate = root._agendaPrefillDate
                }
                item.forceActiveFocus()
            }
            Connections {
                target: agendaDialogLoader.item
                function onDismiss() {
                    root._agendaDialogShown = false
                }
            }
        }
    }
}
