import QtQuick
import QtQuick.Controls
Slider {
    id: root
    from: 0; to: 1
    implicitHeight: 32
    background: Rectangle {
        x: root.leftPadding; y: (root.height-height)/2
        width: root.availableWidth; height: 2
        color: Qt.alpha(AbyssStyle.textColor,0.16)
        Rectangle { width: root.visualPosition*parent.width; height: 2; color: AbyssStyle.accent }
    }
    handle: Rectangle {
        x: root.leftPadding+root.visualPosition*(root.availableWidth-width)
        y: (root.height-height)/2
        width: root.pressed ? 12 : 10; height: width; radius: width/2
        color: AbyssStyle.specular
    }
}
