pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.services.deferred
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.abyss.looks

Item {
    id: root
    property string outputName: ""
    property bool confirmClear: false
    signal closeRequested()
    readonly property var rows: {
        const query = search.text.toLowerCase()
        const pins = Cliphist.pinned.map(text => ({pin:true, value:text, preview:Cliphist.pinPreview(text)}))
        const history = Cliphist.entries.map(entry => ({pin:false, value:entry, preview:String(entry).slice(String(entry).indexOf("\t")+1)}))
        return pins.concat(history).filter(row => row.preview.toLowerCase().includes(query))
    }
    function copyRow(row): void {
        if (!row) return
        if (row.pin) Quickshell.clipboardText = row.value
        else Cliphist.copy(row.value)
        closeRequested()
    }
    Component.onCompleted: { Cliphist.refresh(); search.forceActiveFocus() }
    ColumnLayout {
        anchors.fill: parent
        spacing: AbyssStyle.sectionSpacing/2
        RowLayout {
            AbyssLabel { text: "Clipboard"; font.bold: true; Layout.fillWidth: true }
            AbyssButton {
                text: root.confirmClear ? "Confirm clear" : "Clear history"
                enabled: Cliphist.entries.length > 0
                onClicked: { if (root.confirmClear) { Cliphist.wipe(); root.confirmClear = false } else root.confirmClear = true }
            }
            AbyssButton { glyph: "close"; description: "Close clipboard"; onClicked: root.closeRequested() }
        }
        AbyssSearchField {
            id: search
            Layout.fillWidth: true
            placeholderText: "Search history and pins"
            onTextChanged: { list.currentIndex = 0; root.confirmClear = false }
            onAccepted: root.copyRow(root.rows[list.currentIndex])
            Keys.onDownPressed: list.currentIndex = Math.min(root.rows.length-1,list.currentIndex+1)
            Keys.onUpPressed: list.currentIndex = Math.max(0,list.currentIndex-1)
            Keys.onEscapePressed: root.closeRequested()
        }
        ListView {
            id: list
            Layout.fillWidth: true; Layout.fillHeight: true
            clip: true
            model: root.rows
            currentIndex: 0
            spacing: 4
            delegate: RowLayout {
                id: row
                required property var modelData
                required property int index
                width: list.width
                readonly property bool imageEntry: !modelData.pin && Cliphist.entryIsImage(modelData.value)
                CliphistImage {
                    objectName:"abyssClipboardImage"
                    visible:row.imageEntry
                    Layout.preferredWidth:visible ? Math.min(180,implicitWidth) : 0
                    Layout.preferredHeight:visible ? implicitHeight : 0
                    maxWidth:180;maxHeight:108
                    entry:row.imageEntry ? row.modelData.value : ""
                    TapHandler {onTapped:root.copyRow(row.modelData)}
                }
                AbyssButton {
                    Layout.fillWidth: true
                    text: row.imageEntry ? "Copied image" : row.modelData.preview
                    glyph: row.modelData.pin ? "keep" : row.imageEntry ? "image" : "content_paste"
                    checked: row.index === list.currentIndex
                    onClicked: root.copyRow(row.modelData)
                }
                AbyssButton {
                    glyph: row.modelData.pin ? "keep_off" : "keep"
                    description: row.modelData.pin ? "Unpin" : "Pin text"
                    enabled: row.modelData.pin || Cliphist.isPinnable(row.modelData.value)
                    onClicked: {
                        if (row.modelData.pin) Cliphist.unpin(row.modelData.value)
                        else {
                            const pinnedText = Cliphist.pinnedTextFor(row.modelData.value)
                            if (pinnedText.length) Cliphist.unpin(pinnedText)
                            else Cliphist.pinEntry(row.modelData.value)
                        }
                    }
                }
                AbyssButton { visible: !row.modelData.pin; glyph: "delete"; description: "Delete entry"; onClicked: Cliphist.deleteEntry(row.modelData.value) }
            }
        }
        AbyssLabel { visible: root.rows.length === 0; text: "No matching clipboard entries"; color: Appearance.m3colors.darkmode ? AbyssStyle.textColorMuted : "#1a1a1a" }
    }
}
