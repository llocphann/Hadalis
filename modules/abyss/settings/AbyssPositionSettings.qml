pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.common
import qs.modules.common.widgets
import "../looks/AbyssPresentation.js" as Presentation

ColumnLayout {
    id: root
    Layout.fillWidth: true
    spacing: 8
    property string kind: "popup"
    property string outputName: ""
    readonly property var position: Presentation.resolve(Config.options?.abyss?.positions,kind,outputName)
    function change(key,value): void {
        const values=Object.assign({edge:"source",alignment:"source",position:.5},position,{[key]:value})
        Config.setNestedValue("abyss.positions",Presentation.save(Config.options?.abyss?.positions,kind,outputName,values))
    }
    RowLayout {
        StyledComboBox {
            Layout.fillWidth:true
            textRole:"label";valueRole:"value"
            model:[{label:"All bar popups",value:"popup"},{label:"Calendar",value:"clock"},
                {label:"System resources",value:"resources"},{label:"Battery",value:"battery"},
                {label:"Media popup",value:"media"},{label:"Weather",value:"weather"},
                {label:"Workspaces",value:"workspaces"},{label:"System tray",value:"tray"},
                {label:"All OSDs / IPC indicators",value:"osd"},{label:"Volume OSD",value:"volume"},
                {label:"Brightness OSD",value:"brightness"},{label:"Microphone OSD",value:"mic"},
                {label:"Media OSD",value:"mediaOsd"},{label:"Keyboard OSD",value:"keyboardLayout"},
                {label:"Voice Search OSD",value:"voiceSearch"},{label:"Settings",value:"settings"},
                {label:"Dashboard",value:"dashboard"},{label:"Overview",value:"overview"},
                {label:"Clipboard",value:"clipboard"},{label:"Controls",value:"controls"},
                {label:"Left sidebar",value:"leftPanel"},{label:"Right sidebar",value:"rightPanel"},
                {label:"Quick Notes & Timers",value:"quickNotes"},{label:"Notification center",value:"notificationCenter"},{label:"Notification popups",value:"notifications"},
                {label:"Session menu",value:"session"},{label:"Cheatsheet",value:"cheatsheet"},
                {label:"Shell update",value:"update"},{label:"Dialogs",value:"dialog"}]
            currentIndex:model.findIndex(p => p.value===root.kind)
            onActivated:root.kind=currentValue
        }
        StyledComboBox {
            Layout.fillWidth:true
            textRole:"label";valueRole:"value"
            model:[{label:"All outputs",value:""}].concat(Quickshell.screens.map(s => ({label:s.name,value:s.name})))
            currentIndex:Math.max(0,model.findIndex(p => p.value===root.outputName))
            onActivated:root.outputName=currentValue
        }
    }
    RowLayout {
        StyledComboBox {
            Layout.fillWidth:true
            textRole:"label";valueRole:"value"
            model:[{label:"Follow source edge",value:"source"},{label:"Top Edge",value:"top"},
                {label:"Right Edge",value:"right"},{label:"Bottom Edge",value:"bottom"},{label:"Left Edge",value:"left"}]
            currentIndex:Math.max(0,model.findIndex(p => p.value===(root.position.edge ?? "source")))
            onActivated:root.change("edge",currentValue)
        }
        StyledComboBox {
            Layout.fillWidth:true
            textRole:"label";valueRole:"value"
            model:[{label:"Follow source position",value:"source"},{label:"Align start",value:"start"},
                {label:"Align center",value:"center"},{label:"Align end",value:"end"},{label:"Custom position",value:"custom"}]
            currentIndex:Math.max(0,model.findIndex(p => p.value===(root.position.alignment ?? "source")))
            onActivated:root.change("alignment",currentValue)
        }
        RippleButton {
            buttonText:"Reset position";implicitWidth:140;implicitHeight:38
            onClicked:Config.setNestedValue("abyss.positions",Presentation.save(Config.options?.abyss?.positions,root.kind,root.outputName,null))
        }
    }
    WindowDialogSlider {
        text:"Position along Edge";Layout.fillWidth:true
        visible:root.position.alignment==="custom"
        from:0;to:100;stepSize:1;value:(root.position.position ?? .5)*100
        onMoved:root.change("position",value/100)
    }
    SettingsNote { text:"Positions follow the source unless overridden. Each popup or IPC indicator can use any Edge, globally or per output; content and input are clamped inside that output." }
}
