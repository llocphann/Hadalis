pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.abyss.looks

// Speech lives in the existing output window; automatic messages never focus.
Item {
    id: root
    required property Item actor
    required property real outputWidth
    required property real outputHeight
    property bool allowed: false
    readonly property bool editing: visible && WullMind.conversationOpen
    width:Math.min(310,Math.max(190,outputWidth-32))
    height:content.implicitHeight+24
    x:Math.max(12,Math.min(outputWidth-width-12,actor.x+actor.width/2-width/2))
    y:actor.y-height-18>=12 ? actor.y-height-18 : Math.min(outputHeight-height-12,actor.y+actor.height+18)
    visible:allowed && actor.visible && actor.inputReady && WullMind.text.length>0
    z:240
    Rectangle {anchors.fill:parent;radius:18;color:Qt.alpha(AbyssStyle.surface,.96);border.width:1;border.color:Qt.alpha(AbyssStyle.accent,.68)}
    ColumnLayout {
        id:content
        x:12;y:12;width:parent.width-24;spacing:7
        RowLayout {
            Layout.fillWidth:true
            StyledText {text:"Wull";font.weight:Font.DemiBold;color:AbyssStyle.accent;Layout.fillWidth:true}
            DialogButton {buttonText:Translation.tr("Close");padding:6;implicitHeight:26;onClicked:WullMind.dismiss()}
        }
        StyledText {
            Layout.fillWidth:true;text:WullMind.text;textFormat:Text.PlainText
            wrapMode:Text.WordWrap;font.pixelSize:Appearance.font.pixelSize.small
        }
        Flow {
            visible:!root.editing;Layout.fillWidth:true;spacing:4
            DialogButton {buttonText:Translation.tr("Chat");padding:7;onClicked:WullMind.openChat()}
            DialogButton {buttonText:Translation.tr("Feeling good");padding:7;onClicked:WullMind.checkIn("good","steady")}
            DialogButton {buttonText:Translation.tr("Feeling tired");padding:7;onClicked:WullMind.checkIn("tired","low")}
        }
        ColumnLayout {
            visible:root.editing;Layout.fillWidth:true;spacing:6
            StyledText {Layout.fillWidth:true;wrapMode:Text.WordWrap;font.pixelSize:Appearance.font.pixelSize.smallest
                color:Appearance.colors.colSubtext
                text:WullMind.source==="local" ? Translation.tr("Local AI") : Translation.tr("Companion message")}
            MaterialTextField {
                id:message;objectName:"wullChatInput";Layout.fillWidth:true;maximumLength:1200
                enableSettingsSearch:false;placeholderText:Translation.tr("Say something to Wull…")
                onAccepted:if(WullMind.sendMessage(text))text=""
            }
            Flow {
                Layout.fillWidth:true;spacing:4
                DialogButton {buttonText:WullMind.busy ? Translation.tr("Cancel") : Translation.tr("Send")
                    padding:7
                    onClicked:{if(WullMind.busy)WullMind.cancel();else if(WullMind.sendMessage(message.text))message.text=""}}
                DialogButton {visible:!!WullMind.journal.journalPath;buttonText:Translation.tr("Open journal");padding:7;onClicked:WullMind.openJournal()}
                DialogButton {buttonText:Translation.tr("Done");padding:7;onClicked:WullMind.closeChat()}
            }
        }
    }
    onEditingChanged:if(editing)Qt.callLater(()=>message.forceActiveFocus())
    Shape {
        visible:!root.editing;width:18;height:12
        x:Math.max(18,Math.min(root.width-36,actor.x+actor.width/2-root.x-9))
        y:root.y<actor.y ? root.height-1 : -11
        rotation:root.y<actor.y ? 0 : 180
        ShapePath {strokeColor:Qt.alpha(AbyssStyle.accent,.6);strokeWidth:1;fillColor:Qt.alpha(AbyssStyle.surface,.96)
            startX:0;startY:0;PathLine{x:9;y:12}PathLine{x:18;y:0}}
    }
}
