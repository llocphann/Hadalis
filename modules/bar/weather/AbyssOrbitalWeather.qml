pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.abyss.looks

// A static orbit inside the shared field: no second liquid shader or idle clock.
Item {
    id: root
    property date now: new Date()
    property int activeIndex: -1
    readonly property var hours: (Weather.data?.hourly ?? []).slice(0,8)
    readonly property var selectedHour: hours[activeIndex] ?? null
    readonly property color secondaryInk: Appearance.m3colors.darkmode
        ? AbyssStyle.textColorMuted : "#000000"
    readonly property real nodeWidth: Math.min(Math.max(1,width-16),Math.max(44,Math.min(72,48*Appearance.fontSizeScale,width*.16)))
    readonly property real nodeHeight: Math.min(Math.max(1,height-16),Math.max(54,Math.min(80,54*Appearance.fontSizeScale,height*.26)))
    readonly property real radiusX: Math.max(0,(width-nodeWidth-16)/2)
    readonly property real radiusY: Math.max(0,(height-nodeHeight-16)/2)
    implicitWidth: 360
    implicitHeight: 260
    function angle(label,index): real {
        const match=String(label ?? "").match(/^(\d{1,2}):(\d{2})/)
        const hour=match ? Number(match[1])+Number(match[2])/60 : index*24/Math.max(1,hours.length)
        return (hour-6)*Math.PI/12-Math.PI/2
    }
    Shape {
        anchors.fill:parent
        visible:root.hours.length>0
        ShapePath {
            strokeColor:Qt.alpha(AbyssStyle.accent,.3);strokeWidth:1
            strokeStyle:ShapePath.DashLine;dashPattern:[3,7];fillColor:"transparent"
            startX:root.width/2+root.radiusX;startY:root.height/2
            PathArc { x:root.width/2-root.radiusX;y:root.height/2;radiusX:root.radiusX;radiusY:root.radiusY }
            PathArc { x:root.width/2+root.radiusX;y:root.height/2;radiusX:root.radiusX;radiusY:root.radiusY }
        }
    }
    ColumnLayout {
        anchors.centerIn:parent
        width:Math.min(160,root.width*.42)
        spacing:4
        AbyssLabel {
            Layout.fillWidth:true;horizontalAlignment:Text.AlignHCenter
            text:root.selectedHour?.label ?? Qt.formatDate(root.now,"ddd, MMM d")
            font.pixelSize:Appearance.font.pixelSize.smaller;color:root.secondaryInk
        }
        RowLayout {
            Layout.alignment:Qt.AlignHCenter;spacing:6
            MaterialSymbol {
                text:Icons.getWeatherIcon(root.selectedHour?.code ?? Weather.data?.wCode,root.selectedHour?.isNight ?? Weather.isNightNow()) ?? "cloud"
                iconSize:28*Appearance.fontSizeScale;color:AbyssStyle.accent
            }
            AbyssLabel {
                text:root.selectedHour?.temp ?? Weather.data?.temp ?? "--°"
                font.pixelSize:Math.min(34*Appearance.fontSizeScale,root.width*.09);font.bold:true
            }
        }
        AbyssLabel {
            Layout.fillWidth:true;horizontalAlignment:Text.AlignHCenter
            text:root.selectedHour ? Weather.describeWeather(root.selectedHour.code) : Weather.data?.description ?? ""
            font.pixelSize:Appearance.font.pixelSize.smallest;color:root.secondaryInk
            maximumLineCount:2;elide:Text.ElideRight
        }
    }
    Repeater {
        id: nodes
        model:root.hours
        AbyssButton {
            id: node
            objectName:"abyssWeatherNode"
            required property var modelData
            required property int index
            readonly property real orbitAngle:root.angle(modelData.label,index)
            width:root.nodeWidth;height:root.nodeHeight
            x:root.width/2+Math.cos(orbitAngle)*root.radiusX-width/2
            y:root.height/2+Math.sin(orbitAngle)*root.radiusY-height/2
            leftPadding:4;rightPadding:4
            checked:root.activeIndex===index
            description:(modelData.label ?? "")+" · "+(modelData.temp ?? "--°")
            toolTipEnabled:false
            onHoveredChanged:if(hovered) root.activeIndex=index
            onActiveFocusChanged:if(activeFocus) root.activeIndex=index
            onClicked:root.activeIndex=index
            contentItem:ColumnLayout {
                spacing:1
                AbyssLabel {
                    text:node.modelData.label ?? "";Layout.alignment:Qt.AlignHCenter
                    font.pixelSize:Appearance.font.pixelSize.smallest;color:root.secondaryInk
                }
                MaterialSymbol {
                    text:Icons.getWeatherIcon(node.modelData.code,node.modelData.isNight ?? false) ?? "cloud"
                    Layout.alignment:Qt.AlignHCenter;iconSize:18*Appearance.fontSizeScale;color:AbyssStyle.accent
                }
                AbyssLabel {
                    text:node.modelData.temp ?? "--°";Layout.alignment:Qt.AlignHCenter
                    font.pixelSize:Appearance.font.pixelSize.smaller;font.bold:node.checked
                }
            }
        }
    }
    AbyssLabel {
        anchors.horizontalCenter:parent.horizontalCenter;anchors.bottom:parent.bottom
        anchors.bottomMargin:8
        visible:root.hours.length===0
        text:Translation.tr("Hourly forecast unavailable")
        font.pixelSize:Appearance.font.pixelSize.smallest;color:root.secondaryInk
    }
}
