pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Wayland
import qs
import qs.services
import qs.services.deferred
import qs.modules.abyss.bar
import qs.modules.abyss.looks

Item {
    id: root
    property string outputName: ""
    signal closeRequested()
    readonly property var entries: search.text.length > 0 ? LauncherSearch.results : AppSearch.list.slice(0,80)
    readonly property var windows: CompositorService.isNiri
        ? NiriService.windows.filter(w => NiriService.workspaces[w.workspace_id]?.output === outputName)
        : ToplevelManager.toplevels.values
    function run(entry): void {
        if (!entry) return
        closeRequested()
        if (search.text.length > 0) entry.execute()
        else AppSearch.launchEntry(entry)
    }
    Component.onCompleted: { LauncherSearch.query = ""; search.forceActiveFocus() }
    Component.onDestruction: LauncherSearch.query = ""
    ColumnLayout {
        anchors.fill: parent
        spacing: AbyssStyle.sectionSpacing/2
        RowLayout {
            AbyssLabel { text: "Applications & workspaces"; font.bold: true; Layout.fillWidth: true }
            AbyssButton { glyph: "close"; description: "Close launcher"; onClicked: root.closeRequested() }
        }
        AbyssWorkspaces { Layout.fillWidth: true; Layout.preferredHeight: 36; outputName: root.outputName; vertical: false }
        RowLayout {
            Layout.fillWidth: true
            visible: search.text.length === 0 && root.windows.length > 0
            Repeater {
                model: root.windows.slice(0,4)
                AbyssButton {
                    required property var modelData
                    Layout.fillWidth: true
                    text: modelData.title || modelData.app_id || modelData.appId
                    glyph: "window"
                    onClicked: { root.closeRequested(); if (CompositorService.isNiri) NiriService.focusWindow(modelData.id); else modelData.activate() }
                }
            }
        }
        AbyssSearchField {
            id: search
            Layout.fillWidth: true
            placeholderText: "Search apps · / actions · = math · ; clipboard"
            onTextChanged: { LauncherSearch.query = text; list.currentIndex = 0 }
            onAccepted: root.run(root.entries[list.currentIndex])
            Keys.onDownPressed: list.currentIndex = Math.min(root.entries.length-1,list.currentIndex+1)
            Keys.onUpPressed: list.currentIndex = Math.max(0,list.currentIndex-1)
            Keys.onEscapePressed: root.closeRequested()
        }
        ListView {
            id: list
            Layout.fillWidth: true; Layout.fillHeight: true
            clip: true; model: root.entries; currentIndex: 0; spacing: 2
            delegate: AbyssButton {
                required property var modelData
                required property int index
                width: list.width
                text: modelData.name
                description: (modelData.name || "") + (modelData.comment ? " · "+modelData.comment : "")
                glyph: search.text.length > 0 ? "arrow_outward" : "apps"
                checked: index === list.currentIndex
                onClicked: root.run(modelData)
            }
        }
        AbyssLabel { text: "No matching results"; color: AbyssStyle.textColorMuted; visible: root.entries.length === 0 }
    }
}
