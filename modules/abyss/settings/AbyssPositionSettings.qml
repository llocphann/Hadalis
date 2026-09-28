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
    property var positions: Config.options?.abyss?.positions ?? []
    property bool commitImmediately: true
    property bool outputSelectionEnabled: true
    property var allowedKinds: []
    signal positionsEdited(var positions,string kind,string outputName,var values)
    readonly property var position: Presentation.resolve(positions,kind,outputName)
    function apply(values): void {
        const next=Presentation.save(positions,kind,outputName,values)
        if(commitImmediately) Config.setNestedValue("abyss.positions",next)
        else positionsEdited(next,kind,outputName,values)
    }
    function change(key,value): void {
        const values=Object.assign({edge:"source",alignment:"source",position:.5},position,{[key]:value})
        apply(values)
    }
    readonly property var inputRegions: [kindRegion,outputRegion,edgeRegion,alignmentRegion]
    readonly property Region kindRegion: Region { item:kindChoice.popup.contentItem;width:kindChoice.popup.visible ? kindChoice.popup.contentItem.width : 0 }
    readonly property Region outputRegion: Region { item:outputChoice.popup.contentItem;width:outputChoice.popup.visible ? outputChoice.popup.contentItem.width : 0 }
    readonly property Region edgeRegion: Region { item:edgeChoice.popup.contentItem;width:edgeChoice.popup.visible ? edgeChoice.popup.contentItem.width : 0 }
    readonly property Region alignmentRegion: Region { item:alignmentChoice.popup.contentItem;width:alignmentChoice.popup.visible ? alignmentChoice.popup.contentItem.width : 0 }
    RowLayout {
        StyledComboBox {
            id:kindChoice
            Layout.fillWidth:true
            textRole:"label";valueRole:"value"
            model:[{label:"All bar popups",value:"popup"},{label:"Calendar",value:"clock"},
                {label:"System resources",value:"resources"},{label:"Battery",value:"battery"},
                {label:"Media popup",value:"media"},{label:"Weather",value:"weather"},
                {label:"Wi-Fi connections",value:"wifi"},{label:"Bluetooth devices",value:"bluetooth"},
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
                {label:"Shell update",value:"update"},{label:"Dialogs",value:"dialog"}].filter(option=>!root.allowedKinds.length || root.allowedKinds.includes(option.value))
            currentIndex:model.findIndex(p => p.value===root.kind)
            onActivated:root.kind=currentValue
        }
        StyledComboBox {
            id:outputChoice
            enabled:root.outputSelectionEnabled
            Layout.fillWidth:true
            textRole:"label";valueRole:"value"
            model:[{label:"All outputs",value:""}].concat(Quickshell.screens.map(s => ({label:s.name,value:s.name})))
            currentIndex:Math.max(0,model.findIndex(p => p.value===root.outputName))
            onActivated:root.outputName=currentValue
        }
    }
    RowLayout {
        StyledComboBox {
            id:edgeChoice
            Layout.fillWidth:true
            textRole:"label";valueRole:"value"
            model:[{label:"Follow source edge",value:"source"},{label:"Top Edge",value:"top"},
                {label:"Right Edge",value:"right"},{label:"Bottom Edge",value:"bottom"},{label:"Left Edge",value:"left"}]
            currentIndex:Math.max(0,model.findIndex(p => p.value===(root.position.edge ?? "source")))
            onActivated:root.change("edge",currentValue)
        }
        StyledComboBox {
            id:alignmentChoice
            Layout.fillWidth:true
            textRole:"label";valueRole:"value"
            model:[{label:"Follow source position",value:"source"},{label:"Align start",value:"start"},
                {label:"Align center",value:"center"},{label:"Align end",value:"end"},{label:"Custom position",value:"custom"}]
            currentIndex:Math.max(0,model.findIndex(p => p.value===(root.position.alignment ?? "source")))
            onActivated:root.change("alignment",currentValue)
        }
        RippleButton {
            buttonText:"Reset position";implicitWidth:140;implicitHeight:38
            onClicked:root.apply(null)
        }
    }
    WindowDialogSlider {
        text:"Position along Edge";Layout.fillWidth:true
        visible:root.position.alignment==="custom"
        from:0;to:100;stepSize:1;value:(root.position.position ?? .5)*100
        valueText:Math.round(value)+" %"
        onMoved:root.change("position",value/100)
    }
    SettingsNote { text:"Positions follow the source unless overridden. Each popup or IPC indicator can use any Edge, globally or per output; content and input are clamped inside that output." }
}
