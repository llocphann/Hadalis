pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

/**
 * Material 3 Input Chip — a compact tag with optional icon, label, and removable close button.
 */
Item {
    id: root
    property string text
    property string chipIcon: ""
    property bool removable: true
    property bool monospace: false

    signal activated()
    signal removed()

    implicitWidth: chipBackground.implicitWidth
    implicitHeight: chipBackground.implicitHeight

    Rectangle {
        id: chipBackground
        implicitWidth: chipContent.implicitWidth + 20
        implicitHeight: 30
        radius: height / 2
        color: closeArea.containsMouse ? Appearance.colors.colErrorContainer
            : bodyArea.containsMouse
                ? Appearance.colors.colSecondaryContainerHover
                : Appearance.colors.colSecondaryContainer
        border.width: 1
        border.color: closeArea.containsMouse
            ? Appearance.colors.colError
            : bodyArea.containsMouse
                ? Qt.rgba(
                    Appearance.colors.colOnSecondaryContainer.r,
                    Appearance.colors.colOnSecondaryContainer.g,
                    Appearance.colors.colOnSecondaryContainer.b, 0.2)
                : "transparent"

        Behavior on color {
            enabled: Appearance.animationsEnabled
            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
        }
        Behavior on border.color {
            enabled: Appearance.animationsEnabled
            ColorAnimation { duration: Appearance.animation.elementMoveFast.duration }
        }
        Behavior on radius {
            enabled: Appearance.animationsEnabled
            NumberAnimation {
                duration: Appearance.animation.elementResize.duration
                easing.type: Appearance.animation.elementResize.type
                easing.bezierCurve: Appearance.animation.elementResize.bezierCurve
            }
        }
        Behavior on implicitWidth {
            enabled: Appearance.animationsEnabled
            NumberAnimation {
                duration: Appearance.animation.elementResize.duration
                easing.type: Appearance.animation.elementResize.type
                easing.bezierCurve: Appearance.animation.elementResize.bezierCurve
            }
        }

        RowLayout {
            id: chipContent
            anchors.centerIn: parent
            spacing: (root.chipIcon.length > 0 || root.removable) ? 4 : 0

            Behavior on spacing {
                enabled: Appearance.animationsEnabled
                NumberAnimation {
                    duration: Appearance.animation.elementResize.duration
                    easing.type: Appearance.animation.elementResize.type
                    easing.bezierCurve: Appearance.animation.elementResize.bezierCurve
                }
            }

            Item {
                implicitWidth: root.chipIcon.length > 0 ? leadingIcon.implicitWidth : 0
                implicitHeight: leadingIcon.implicitHeight
                opacity: root.chipIcon.length > 0 ? 1 : 0
                visible: opacity > 0
                clip: true

                Behavior on implicitWidth {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation {
                        duration: Appearance.animation.elementResize.duration
                        easing.type: Appearance.animation.elementResize.type
                        easing.bezierCurve: Appearance.animation.elementResize.bezierCurve
                    }
                }
                Behavior on opacity {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation {
                        duration: Appearance.animation.elementMoveFast.duration
                        easing.type: Appearance.animation.elementMoveFast.type
                        easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                    }
                }

                MaterialSymbol {
                    id: leadingIcon
                    anchors.centerIn: parent
                    text: root.chipIcon
                    iconSize: 16
                    color: closeArea.containsMouse
                        ? Appearance.colors.colOnErrorContainer
                        : Appearance.colors.colOnSecondaryContainer
                }
            }

            StyledText {
                text: root.text
                font.pixelSize: Appearance.font.pixelSize.smallest
                font.family: root.monospace
                    ? Appearance.font.family.monospace : Appearance.font.family.main
                color: closeArea.containsMouse
                    ? Appearance.colors.colOnErrorContainer
                    : Appearance.colors.colOnSecondaryContainer
            }

            Item {
                visible: opacity > 0
                opacity: root.removable ? 1 : 0
                implicitWidth: root.removable ? 16 : 0
                implicitHeight: 16
                clip: true

                Behavior on implicitWidth {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation {
                        duration: Appearance.animation.elementResize.duration
                        easing.type: Appearance.animation.elementResize.type
                        easing.bezierCurve: Appearance.animation.elementResize.bezierCurve
                    }
                }
                Behavior on opacity {
                    enabled: Appearance.animationsEnabled
                    NumberAnimation {
                        duration: Appearance.animation.elementMoveFast.duration
                        easing.type: Appearance.animation.elementMoveFast.type
                        easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                    }
                }

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "close"
                    iconSize: 14
                    color: closeArea.containsMouse
                        ? Appearance.colors.colOnErrorContainer
                        : Appearance.colors.colOnSecondaryContainer
                    opacity: closeArea.containsMouse ? 1 : (bodyArea.containsMouse ? 0.7 : 0.4)

                    Behavior on opacity {
                        enabled: Appearance.animationsEnabled
                        NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
                    }
                }
            }
        }

        MouseArea {
            id: bodyArea
            anchors.fill: parent
            anchors.rightMargin: root.removable ? 24 : 0
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.activated()

            Behavior on anchors.rightMargin {
                enabled: Appearance.animationsEnabled
                NumberAnimation {
                    duration: Appearance.animation.elementResize.duration
                    easing.type: Appearance.animation.elementResize.type
                    easing.bezierCurve: Appearance.animation.elementResize.bezierCurve
                }
            }
        }

        MouseArea {
            id: closeArea
            visible: root.removable
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 24
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.removed()
        }
    }
}
