import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

GroupButton {
    id: root
    Accessible.checkable: true
    Accessible.checked: root.toggled
    horizontalPadding: 11
    verticalPadding: 6
    bounce: false
    property string buttonIcon
    property string buttonPreviewKind: ""
    property real maxTextWidth: 180
    // Opt-in only. Most segmented controls keep their centered label; callers
    // such as the TLP category browser can request a tidy left-aligned list
    // without changing alignment shell-wide.
    property bool leftAlignContent: false
    property bool leftmost: false
    property bool rightmost: false
    leftRadius: (toggled || leftmost) ? (height / 2) : Appearance.rounding.unsharpenmore
    rightRadius: (toggled || rightmost) ? (height / 2) : Appearance.rounding.unsharpenmore
    Behavior on leftRadius {
        enabled: Appearance.animationsEnabled
        animation: NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve }
    }
    Behavior on rightRadius {
        enabled: Appearance.animationsEnabled
        animation: NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve }
    }
    colBackground: Appearance.colors.colSecondaryContainer
    colBackgroundHover: Appearance.colors.colSecondaryContainerHover
    colBackgroundActive: Appearance.colors.colSecondaryContainerActive

    contentItem: RowLayout {
        spacing: root.buttonIcon?.length > 0 && root.buttonText?.length > 0 ? 4 : 0

        Behavior on spacing {
            enabled: Appearance.animationsEnabled
            animation: NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve }
        }

        Item {
            id: iconReveal
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: root.buttonIcon?.length > 0 ? materialSymbol.implicitWidth : 0
            implicitHeight: materialSymbol.implicitHeight
            opacity: root.buttonIcon?.length > 0 ? 1 : 0
            visible: opacity > 0
            clip: true

            Behavior on implicitWidth {
                enabled: Appearance.animationsEnabled
                animation: NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve }
            }
            Behavior on opacity {
                enabled: Appearance.animationsEnabled
                animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
            }

            MaterialSymbol {
                id: materialSymbol
                anchors.centerIn: parent
                text: root.buttonIcon
                iconSize: Appearance.font.pixelSize.normal
                color: root.toggled
                    ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSecondaryContainer
            }
        }

        Item {
            Layout.minimumWidth: 0
            implicitWidth: root.buttonText?.length > 0
                ? Math.min(textItem.implicitWidth, root.maxTextWidth) : 0
            implicitHeight: textMetrics.height // Force height to that of regular text
            opacity: root.buttonText?.length > 0 ? 1 : 0
            visible: opacity > 0
            clip: true

            Behavior on implicitWidth {
                enabled: Appearance.animationsEnabled
                animation: NumberAnimation { duration: Appearance.animation.elementResize.duration; easing.type: Appearance.animation.elementResize.type; easing.bezierCurve: Appearance.animation.elementResize.bezierCurve }
            }
            Behavior on opacity {
                enabled: Appearance.animationsEnabled
                animation: NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
            }

            TextMetrics {
                id: textMetrics
                font.family: Appearance.font.family.main
                text: "Abc"
            }

            StyledText {
                id: textItem
                anchors.fill: parent
                horizontalAlignment: root.leftAlignContent
                    ? Text.AlignLeft : Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
                maximumLineCount: 1
                color: root.toggled
                    ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSecondaryContainer
                text: root.buttonText
            }
        }

        // With GridLayout-forced equal button widths, this absorbs only the
        // trailing free space and leaves icon + label against the left inset.
        Item {
            visible: root.leftAlignContent
            Layout.fillWidth: root.leftAlignContent
            Layout.preferredWidth: root.leftAlignContent ? 1 : 0
        }
    }
}
