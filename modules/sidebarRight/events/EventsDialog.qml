pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

WindowDialog {
    id: root
    backgroundHeight: 600
    contentSpacing: root.embeddedPresentation ? 4 : 16
    embeddedBackgroundColor: Appearance.angelEverywhere
        ? Appearance.angel.colGlassPopup
        : Appearance.inirEverywhere ? Appearance.inir.colLayer1
        : Appearance.auroraEverywhere ? Appearance.aurora.colDialogSurface
        : Appearance.colors.colSurfaceContainerHigh

    component EventSectionHeader: WindowDialogSectionHeader {
        color: Appearance.colors.colOnSurfaceVariant
        font.pixelSize: root.embeddedPresentation
            ? Appearance.font.pixelSize.small
            : Appearance.font.pixelSize.large
        font.weight: Font.Medium
    }

    property var editingEvent: null
    property bool isEditing: editingEvent !== null

    // Form state
    property string eventTitle: ""
    property string eventDescription: ""
    property date eventDate: new Date()
    // eventTime remains the start-time compatibility property.
    property string eventTime: "12:00"
    property string eventEndTime: "13:00"
    property bool allDay: false
    property string eventCategory: "general"
    property string eventPriority: "normal"
    property int reminderMinutes: 15
    property string recurrence: "none"

    function focusEditor(): void {
        Qt.callLater(() => titleField.forceActiveFocus())
    }

    function resetForm(): void {
        root.editingEvent = null
        root.eventTitle = ""
        root.eventDescription = ""
        root.eventDate = new Date()
        root.eventTime = "12:00"
        root.eventEndTime = "13:00"
        root.allDay = false
        root.eventCategory = "general"
        root.eventPriority = "normal"
        root.reminderMinutes = 15
        root.recurrence = "none"
    }

    function loadEvent(event: var): void {
        root.editingEvent = event
        root.eventTitle = event.title || ""
        root.eventDescription = event.description || ""
        const startSource = event.startDate || event.dateTime
        const startDt = new Date(startSource)
        const safeStart = isNaN(startDt.getTime()) ? new Date() : startDt
        const endDt = event.endDate
            ? new Date(event.endDate)
            : new Date(safeStart.getTime() + 60 * 60 * 1000)
        const safeEnd = isNaN(endDt.getTime())
            ? new Date(safeStart.getTime() + 60 * 60 * 1000) : endDt
        root.eventDate = safeStart
        root.eventTime = safeStart.getHours().toString().padStart(2, '0')
            + ":" + safeStart.getMinutes().toString().padStart(2, '0')
        root.eventEndTime = safeEnd.getHours().toString().padStart(2, '0')
            + ":" + safeEnd.getMinutes().toString().padStart(2, '0')
        root.allDay = event.allDay === true
        root.eventCategory = event.category || "general"
        root.eventPriority = event.priority || "normal"
        root.reminderMinutes = event.reminderMinutes ?? 15
        root.recurrence = event.recurrence || "none"
    }

    function saveEvent(): bool {
        if (!Events.ready || root.eventTitle.trim() === "") return false

        const startParts = root.eventTime.split(":")
        const endParts = root.eventEndTime.split(":")
        const startDateTime = new Date(root.eventDate)
        const endDateTime = new Date(root.eventDate)

        if (root.allDay) {
            startDateTime.setHours(0, 0, 0, 0)
            endDateTime.setHours(0, 0, 0, 0)
            endDateTime.setDate(endDateTime.getDate() + 1)
        } else {
            startDateTime.setHours(
                parseInt(startParts[0]) || 0,
                parseInt(startParts[1]) || 0, 0, 0)
            endDateTime.setHours(
                parseInt(endParts[0]) || 0,
                parseInt(endParts[1]) || 0, 0, 0)
            // Treat an end time at/before the start as crossing midnight.
            if (endDateTime.getTime() <= startDateTime.getTime())
                endDateTime.setDate(endDateTime.getDate() + 1)
        }

        const startIso = startDateTime.toISOString()
        const endIso = endDateTime.toISOString()

        if (root.isEditing) {
            return Events.updateEvent(root.editingEvent.id, {
                title: root.eventTitle.trim(),
                description: root.eventDescription.trim(),
                dateTime: startIso,
                startDate: startIso,
                endDate: endIso,
                allDay: root.allDay,
                category: root.eventCategory,
                priority: root.eventPriority,
                reminderMinutes: root.reminderMinutes,
                recurrence: root.recurrence,
                notified: false,
                reminderNotified: false
            })
        }

        return Events.addEvent(
            root.eventTitle.trim(),
            root.eventDescription.trim(),
            startIso,
            root.eventCategory,
            root.eventPriority,
            root.reminderMinutes,
            root.recurrence,
            endIso,
            root.allDay
        ) !== null
    }

    WindowDialogTitle {
        Layout.leftMargin: root.embeddedPresentation ? 6 : 0
        Layout.rightMargin: root.embeddedPresentation ? 6 : 0
        text: root.isEditing ? Translation.tr("Edit Event") : Translation.tr("New Event")
        font.pixelSize: root.embeddedPresentation
            ? Appearance.font.pixelSize.normal
            : Appearance.font.pixelSize.title
        font.weight: root.embeddedPresentation ? Font.DemiBold : Font.Medium
    }

    WindowDialogSeparator {
        visible: !root.embeddedPresentation
    }

    // Scrollable content
    Flickable {
        Layout.fillWidth: true
        Layout.fillHeight: true

        contentHeight: formColumn.implicitHeight
            + (root.embeddedPresentation ? 4 : 16)
        Layout.leftMargin: root.embeddedPresentation ? 6 : 0
        Layout.rightMargin: root.embeddedPresentation ? 6 : 0
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }

        Column {
            id: formColumn
            width: parent.width
            spacing: root.embeddedPresentation ? 0 : 4

            // ─── Basic Info Section ───────────────────────────────────
            EventSectionHeader {
                visible: !root.embeddedPresentation
                text: Translation.tr("Basic Info")
            }

            WindowDialogSeparator {
                visible: !root.embeddedPresentation
                Layout.topMargin: -22
            }

            Column {
                width: parent.width
                spacing: root.embeddedPresentation ? 4 : 8
                topPadding: root.embeddedPresentation ? 2 : 8

                MaterialTextField {
                    id: titleField
                    width: parent.width - (root.embeddedPresentation ? 8 : 16)
                    implicitHeight: root.embeddedPresentation ? 40 : 56
                    anchors.horizontalCenter: parent.horizontalCenter
                    placeholderText: Translation.tr("Event title") + " *"
                    placeholderTextColor: Appearance.colors.colOnSurface
                    color: Appearance.colors.colOnSurface
                    renderType: Text.QtRendering
                    font.weight: Font.Medium
                    font.hintingPreference: Font.PreferFullHinting
                    text: root.eventTitle
                    onTextChanged: root.eventTitle = text
                }

                MaterialTextField {
                    width: parent.width - (root.embeddedPresentation ? 8 : 16)
                    implicitHeight: root.embeddedPresentation ? 40 : 56
                    anchors.horizontalCenter: parent.horizontalCenter
                    placeholderText: Translation.tr("Description (optional)")
                    text: root.eventDescription
                    onTextChanged: root.eventDescription = text
                }
            }

            // ─── Date & Time Section ──────────────────────────────────
            EventSectionHeader {
                visible: !root.embeddedPresentation
                text: Translation.tr("Date & Time")
                topPadding: root.embeddedPresentation ? 0 : 16
            }

            WindowDialogSeparator {
                visible: !root.embeddedPresentation
                Layout.topMargin: -22
            }

            Column {
                width: parent.width
                spacing: root.embeddedPresentation ? 3 : 6
                topPadding: root.embeddedPresentation ? 3 : 0

                // Embedded Calendar already owns the date grid above this sheet.
                // Modal owners keep the self-contained picker.
                DatePicker {
                    visible: !root.embeddedPresentation
                    width: parent.width
                    compact: false
                    selectedDate: root.eventDate
                    onDateSelected: (date) => { root.eventDate = date }
                }

                RowLayout {
                    visible: root.embeddedPresentation
                    width: parent.width - 8
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 6

                    MaterialSymbol {
                        text: "calendar_month"
                        iconSize: 16
                        color: Appearance.colors.colPrimary
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: Qt.formatDate(root.eventDate, "ddd, dd MMM yyyy")
                        color: Appearance.colors.colOnSurface
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.Medium
                    }
                }

                RowLayout {
                    width: parent.width - 8
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 8

                    MaterialSymbol {
                        text: "event_available"
                        iconSize: 16
                        color: Appearance.colors.colOnSurfaceVariant
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: Translation.tr("All day")
                        color: Appearance.colors.colOnSurface
                        font.pixelSize: Appearance.font.pixelSize.small
                    }

                    StyledSwitch {
                        scale: 0.58
                        checked: root.allDay
                        onToggled: root.allDay = checked
                    }
                }

                RowLayout {
                    visible: !root.allDay
                    width: parent.width
                    spacing: root.embeddedPresentation ? 4 : 8

                    ConfigTimeInput {
                        Layout.fillWidth: true
                        icon: "schedule"
                        text: Translation.tr("Start")
                        value: root.eventTime
                        onTimeChanged: (newTime) => { root.eventTime = newTime }
                    }

                    ConfigTimeInput {
                        Layout.fillWidth: true
                        icon: "schedule"
                        text: Translation.tr("End")
                        value: root.eventEndTime
                        onTimeChanged: (newTime) => {
                            root.eventEndTime = newTime
                        }
                    }
                }
            }

            // Repeat is part of scheduling, so keep it next to date/time rather
            // than burying it below category/priority/reminder settings.
            EventSectionHeader {
                text: Translation.tr("Repeat")
                topPadding: root.embeddedPresentation ? 5 : 16
            }

            WindowDialogSeparator {
                visible: !root.embeddedPresentation
                Layout.topMargin: -22
            }

            ConfigSelectionArray {
                anchors {
                    left: parent.left
                    right: parent.right
                    leftMargin: 8
                    rightMargin: 8
                }
                enableSettingsSearch: false
                options: [
                    // "Event" maps to the existing one-time/non-recurring
                    // storage value instead of inventing an incompatible mode.
                    { displayName: Translation.tr("Event"), icon: "event", value: "none" },
                    { displayName: Translation.tr("Daily"), icon: "today", value: "daily" },
                    { displayName: Translation.tr("Weekly"), icon: "date_range", value: "weekly" },
                    { displayName: Translation.tr("Monthly"), icon: "calendar_month", value: "monthly" },
                    { displayName: Translation.tr("Yearly"), icon: "event_repeat", value: "yearly" }
                ]
                currentValue: root.recurrence
                onSelected: (newValue) => { root.recurrence = newValue }
            }

            // ─── Category Section ─────────────────────────────────────
            EventSectionHeader {
                text: Translation.tr("Category")
                topPadding: root.embeddedPresentation ? 6 : 16
            }

            WindowDialogSeparator {
                visible: !root.embeddedPresentation
                Layout.topMargin: -22
            }

            ConfigSelectionArray {
                anchors {
                    left: parent.left
                    right: parent.right
                    leftMargin: 8
                    rightMargin: 8
                }
                enableSettingsSearch: false
                options: [
                    { displayName: Translation.tr("General"), icon: "event", value: "general" },
                    { displayName: Translation.tr("Birthday"), icon: "cake", value: "birthday" },
                    { displayName: Translation.tr("Meeting"), icon: "groups", value: "meeting" },
                    { displayName: Translation.tr("Deadline"), icon: "flag", value: "deadline" },
                    { displayName: Translation.tr("Reminder"), icon: "notifications", value: "reminder" }
                ]
                currentValue: root.eventCategory
                onSelected: (newValue) => { root.eventCategory = newValue }
            }

            // ─── Priority Section ─────────────────────────────────────
            EventSectionHeader {
                text: Translation.tr("Priority")
                topPadding: root.embeddedPresentation ? 6 : 16
            }

            WindowDialogSeparator {
                visible: !root.embeddedPresentation
                Layout.topMargin: -22
            }

            ConfigSelectionArray {
                anchors {
                    left: parent.left
                    right: parent.right
                    leftMargin: 8
                    rightMargin: 8
                }
                enableSettingsSearch: false
                options: [
                    { displayName: Translation.tr("Low"), icon: "arrow_downward", value: "low" },
                    { displayName: Translation.tr("Normal"), icon: "remove", value: "normal" },
                    { displayName: Translation.tr("High"), icon: "priority_high", value: "high" }
                ]
                currentValue: root.eventPriority
                onSelected: (newValue) => { root.eventPriority = newValue }
            }

            // ─── Reminder Section ─────────────────────────────────────
            EventSectionHeader {
                text: Translation.tr("Reminder")
                topPadding: root.embeddedPresentation ? 6 : 16
            }

            WindowDialogSeparator {
                visible: !root.embeddedPresentation
                Layout.topMargin: -22
            }

            ConfigSelectionArray {
                anchors {
                    left: parent.left
                    right: parent.right
                    leftMargin: 8
                    rightMargin: 8
                }
                enableSettingsSearch: false
                options: [
                    { displayName: Translation.tr("None"), icon: "notifications_off", value: 0 },
                    { displayName: Translation.tr("5 min"), icon: "alarm", value: 5 },
                    { displayName: Translation.tr("15 min"), icon: "alarm", value: 15 },
                    { displayName: Translation.tr("1 hour"), icon: "alarm", value: 60 },
                    { displayName: Translation.tr("1 day"), icon: "alarm", value: 1440 }
                ]
                currentValue: root.reminderMinutes
                onSelected: (newValue) => { root.reminderMinutes = newValue }
            }

            // Bottom padding
            Item {
                width: 1
                height: root.embeddedPresentation ? 4 : 16
            }
        }
    }

    WindowDialogSeparator {
        visible: !root.embeddedPresentation
    }

    WindowDialogButtonRow {
        Layout.leftMargin: root.embeddedPresentation ? 4 : -8
        Layout.rightMargin: root.embeddedPresentation ? 4 : -8
        Layout.bottomMargin: root.embeddedPresentation ? 2 : 0

        DialogButton {
            visible: root.isEditing
            enabled: Events.ready
            padding: root.embeddedPresentation ? 10 : 14
            implicitHeight: root.embeddedPresentation ? 32 : 36
            buttonText: Translation.tr("Delete")
            onClicked: {
                if (Events.removeEvent(root.editingEvent.id)) {
                    root.resetForm()
                    root.dismiss()
                }
            }
        }

        Item { Layout.fillWidth: true }

        DialogButton {
            padding: root.embeddedPresentation ? 10 : 14
            implicitHeight: root.embeddedPresentation ? 32 : 36
            buttonText: Translation.tr("Cancel")
            onClicked: {
                root.resetForm()
                root.dismiss()
            }
        }

        DialogButton {
            padding: root.embeddedPresentation ? 10 : 14
            implicitHeight: root.embeddedPresentation ? 32 : 36
            buttonText: root.isEditing ? Translation.tr("Save") : Translation.tr("Add Event")
            enabled: Events.ready && root.eventTitle.trim() !== ""
            onClicked: {
                if (root.saveEvent()) {
                    root.resetForm()
                    root.dismiss()
                }
            }
        }
    }
}
