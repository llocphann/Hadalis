pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes

// Faceted crystal drawn with the same live theme ink as the AI action.
Item {
    id: root
    required property color color
    implicitWidth: 24
    implicitHeight: 28
    Shape {
        anchors.centerIn: parent
        width: 24; height: 28
        scale: Math.min(root.width/24,root.height/28)
        ShapePath {
            strokeWidth: -1; fillColor: Qt.darker(root.color,1.35)
            startX: 2; startY: 5
            PathLine {x:14;y:1} PathLine {x:23;y:10} PathLine {x:17;y:25}
            PathLine {x:11;y:27} PathLine {x:2;y:19} PathLine {x:5;y:11} PathLine {x:2;y:5}
        }
        ShapePath {
            strokeWidth: -1; fillColor: Qt.lighter(root.color,1.2)
            startX: 2; startY: 5
            PathLine {x:14;y:1} PathLine {x:10;y:11} PathLine {x:2;y:19}
            PathLine {x:5;y:11} PathLine {x:2;y:5}
        }
        ShapePath {
            strokeWidth: -1; fillColor: root.color
            startX: 14; startY: 1
            PathLine {x:23;y:10} PathLine {x:13;y:14} PathLine {x:10;y:11} PathLine {x:14;y:1}
        }
        ShapePath {
            strokeWidth: -1; fillColor: Qt.darker(root.color,1.12)
            startX: 23; startY: 10
            PathLine {x:17;y:25} PathLine {x:13;y:14} PathLine {x:23;y:10}
        }
        ShapePath {
            strokeWidth: -1; fillColor: Qt.darker(root.color,1.6)
            startX: 10; startY: 11
            PathLine {x:13;y:14} PathLine {x:17;y:25} PathLine {x:11;y:27}
            PathLine {x:2;y:19} PathLine {x:10;y:11}
        }
    }
}
