import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import qs.modules.common
import qs.modules.common.widgets

/**
 * Two-state Dashboard tab control matching DashTodo's Unfinished/Done pills.
 *
 * The active half is a full capsule. The inactive half uses the mirrored
 * concave contact silhouette from DashTodo so sibling Dashboard cards can share
 * the same tab language without depending on Todo-specific data.
 */
Item {
    id: root

    property int currentIndex: 0
    property string leftLabel: ""
    property string rightLabel: ""
    property string leftIcon: ""
    property string rightIcon: ""
    property string leftBadgeText: ""
    property string rightBadgeText: ""
    property bool leftBadgeVisible: leftBadgeText.length > 0
    property bool rightBadgeVisible: rightBadgeText.length > 0
    property bool narrow: false
    property int controlHeight: root.narrow ? 36 : 38
    property color inactiveTextColor: Appearance.colors.colOnSurfaceVariant

    signal tabRequested(int index)

    implicitHeight: root.controlHeight
    clip: false

    readonly property real halfWidth: width / 2
    readonly property real inset: 3
    readonly property real innerHeight: height - inset * 2
    readonly property real cornerRadius: innerHeight / 2
    readonly property real arcKappa: 0.5522847498
    readonly property int iconSlotSize: root.narrow ? 17 : 18
    readonly property int tabIconSize: root.narrow ? 15 : 16
    readonly property int badgeSize: root.narrow ? 19 : 21
    readonly property real contentPadding: root.narrow ? 7 : 9
    readonly property real contentSpacing: root.narrow ? 3 : 5

    Shape {
        id: inactiveTabShape
        x: root.currentIndex === 1
            ? root.inset
            : root.halfWidth - root.cornerRadius
        y: root.inset
        width: root.halfWidth + root.cornerRadius - root.inset
        height: root.innerHeight
        z: 1
        preferredRendererType: Shape.CurveRenderer

        transform: Scale {
            origin.x: inactiveTabShape.width / 2
            origin.y: inactiveTabShape.height / 2
            xScale: root.currentIndex === 0 ? -1 : 1
            yScale: 1
        }

        ShapePath {
            strokeWidth: 0
            fillColor: {
                const hovered = root.currentIndex === 1
                    ? leftTabHover.hovered
                    : rightTabHover.hovered
                return hovered
                    ? Appearance.colors.colLayer1Hover
                    : Appearance.colors.colLayer1
            }

            startX: root.cornerRadius
            startY: 0

            PathLine {
                x: inactiveTabShape.width
                y: 0
            }

            PathCubic {
                control1X: inactiveTabShape.width
                    - root.arcKappa * root.cornerRadius
                control1Y: 0
                control2X: inactiveTabShape.width - root.cornerRadius
                control2Y: root.cornerRadius
                    - root.arcKappa * root.cornerRadius
                x: inactiveTabShape.width - root.cornerRadius
                y: root.cornerRadius
            }
            PathCubic {
                control1X: inactiveTabShape.width - root.cornerRadius
                control1Y: root.cornerRadius
                    + root.arcKappa * root.cornerRadius
                control2X: inactiveTabShape.width
                    - root.arcKappa * root.cornerRadius
                control2Y: inactiveTabShape.height
                x: inactiveTabShape.width
                y: inactiveTabShape.height
            }

            PathLine {
                x: root.cornerRadius
                y: inactiveTabShape.height
            }

            PathCubic {
                control1X: root.cornerRadius
                    - root.arcKappa * root.cornerRadius
                control1Y: inactiveTabShape.height
                control2X: 0
                control2Y: root.cornerRadius
                    + root.arcKappa * root.cornerRadius
                x: 0
                y: root.cornerRadius
            }
            PathCubic {
                control1X: 0
                control1Y: root.cornerRadius
                    - root.arcKappa * root.cornerRadius
                control2X: root.cornerRadius
                    - root.arcKappa * root.cornerRadius
                control2Y: 0
                x: root.cornerRadius
                y: 0
            }
        }
    }

    Rectangle {
        id: activeTabPill
        x: root.currentIndex === 0 ? root.inset : root.halfWidth
        y: root.inset
        width: root.halfWidth - root.inset
        height: root.innerHeight
        radius: root.cornerRadius
        z: 2
        color: (root.currentIndex === 0
                ? leftTabHover.hovered : rightTabHover.hovered)
            ? Appearance.colors.colPrimaryContainerHover
            : Appearance.colors.colPrimaryContainer

        Behavior on x {
            enabled: Appearance.animationsEnabled
            NumberAnimation {
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
                easing.bezierCurve:
                    Appearance.animation.elementMoveFast.bezierCurve
            }
        }

        Behavior on color {
            enabled: Appearance.animationsEnabled
            ColorAnimation {
                duration: Appearance.animation.elementMoveFast.duration
            }
        }
    }

    Item {
        x: 0
        width: root.halfWidth
        height: root.height
        z: 5

        HoverHandler {
            id: leftTabHover
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            onTapped: root.tabRequested(0)
        }
    }

    Item {
        x: root.halfWidth
        width: root.halfWidth
        height: root.height
        z: 5

        HoverHandler {
            id: rightTabHover
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            onTapped: root.tabRequested(1)
        }
    }

    Item {
        x: 0
        width: root.halfWidth
        height: root.height
        z: 4

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: root.contentPadding
            anchors.rightMargin: root.contentPadding
            spacing: root.contentSpacing

            Item {
                Layout.preferredWidth: root.iconSlotSize
                Layout.preferredHeight: root.iconSlotSize
                Layout.alignment: Qt.AlignVCenter

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: root.leftIcon
                    iconSize: root.tabIconSize
                    color: root.currentIndex === 0
                        ? Appearance.colors.colOnPrimaryContainer
                        : root.inactiveTextColor
                }
            }

            StyledText {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                text: root.leftLabel
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.Medium
                color: root.currentIndex === 0
                    ? Appearance.colors.colOnPrimaryContainer
                    : root.inactiveTextColor
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            Rectangle {
                visible: root.leftBadgeVisible
                Layout.preferredWidth: root.badgeSize
                Layout.preferredHeight: root.badgeSize
                Layout.alignment: Qt.AlignVCenter
                radius: height / 2
                color: root.currentIndex === 0
                    ? Appearance.colors.colPrimary
                    : Appearance.colors.colLayer2

                StyledText {
                    anchors.centerIn: parent
                    text: root.leftBadgeText
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.weight: Font.DemiBold
                    color: root.currentIndex === 0
                        ? Appearance.colors.colOnPrimary
                        : root.inactiveTextColor
                }
            }
        }
    }

    Item {
        x: root.halfWidth
        width: root.halfWidth
        height: root.height
        z: 4

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: root.contentPadding
            anchors.rightMargin: root.contentPadding
            spacing: root.contentSpacing

            Item {
                Layout.preferredWidth: root.iconSlotSize
                Layout.preferredHeight: root.iconSlotSize
                Layout.alignment: Qt.AlignVCenter

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: root.rightIcon
                    iconSize: root.tabIconSize
                    color: root.currentIndex === 1
                        ? Appearance.colors.colOnPrimaryContainer
                        : root.inactiveTextColor
                }
            }

            StyledText {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                text: root.rightLabel
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.pixelSize: Appearance.font.pixelSize.small
                font.weight: Font.Medium
                color: root.currentIndex === 1
                    ? Appearance.colors.colOnPrimaryContainer
                    : root.inactiveTextColor
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            Rectangle {
                visible: root.rightBadgeVisible
                Layout.preferredWidth: root.badgeSize
                Layout.preferredHeight: root.badgeSize
                Layout.alignment: Qt.AlignVCenter
                radius: height / 2
                color: root.currentIndex === 1
                    ? Appearance.colors.colPrimary
                    : Appearance.colors.colLayer2

                StyledText {
                    anchors.centerIn: parent
                    text: root.rightBadgeText
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.weight: Font.DemiBold
                    color: root.currentIndex === 1
                        ? Appearance.colors.colOnPrimary
                        : root.inactiveTextColor
                }
            }
        }
    }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            if (event.angleDelta.y < 0)
                root.tabRequested(1)
            else if (event.angleDelta.y > 0)
                root.tabRequested(0)
        }
    }
}
