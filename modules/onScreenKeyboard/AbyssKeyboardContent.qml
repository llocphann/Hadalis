pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.abyss.looks
import qs.services.deferred
Item {
 id:root
 property var participant:null
 property string outputName:""
 property bool pinned:Config.options?.osk?.pinnedOnStartup ?? false
 property bool open:participant?.open ?? false
 implicitWidth:keyboard.implicitWidth+70
 implicitHeight:Math.max(keyboard.implicitHeight,200)
 onOpenChanged:if(!open)Ydotool.releaseAllKeys()
 Component.onDestruction:if(open)Ydotool.releaseAllKeys()
 Item {
  anchors.centerIn:parent
  width:root.implicitWidth;height:root.implicitHeight
  scale:Math.min(1,root.width/width,root.height/height)
  RowLayout {
   anchors.fill:parent;spacing:12
   ColumnLayout {
    Layout.preferredWidth:48;Layout.fillHeight:true;spacing:8
    AbyssButton {objectName:"oskPin";glyph:root.pinned ? "lock" : "keep";checked:root.pinned;description:"Lock keyboard position";onClicked:root.pinned=!root.pinned}
    AbyssButton {glyph:"flip_to_front";checked:Config.options?.osk?.keepOnTop ?? false;description:"Keep keyboard above other popups";onClicked:Config.setNestedValue("osk.keepOnTop",!(Config.options?.osk?.keepOnTop ?? false))}
    AbyssButton {objectName:"oskClose";glyph:"keyboard_hide";description:"Close keyboard";onClicked:GlobalStates.oskOpen=false}
    Item {
     objectName:"oskDrag";Layout.fillWidth:true;Layout.fillHeight:true;Layout.minimumHeight:50
     opacity:root.pinned ? .25 : .8
     MaterialSymbol {anchors.centerIn:parent;text:"drag_indicator";color:AbyssStyle.textColorMuted;iconSize:24}
     DragHandler {
      enabled:!root.pinned;target:null
      onActiveChanged:if(active)root.participant?.beginKeyboardDrag();else root.participant?.finishKeyboardDrag()
      onTranslationChanged:if(active)root.participant?.moveKeyboardDrag(translation.x,translation.y)
     }
    }
   }
   OskContent {id:keyboard;Layout.fillWidth:true}
  }
 }
}
