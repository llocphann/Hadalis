pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    property int screenWidth: 1920
    property int screenHeight: 1080
    readonly property bool compactMode: Config.options?.controlPanel?.compactMode ?? true
    readonly property bool islandStyle:
        (Config.options?.controlPanel?.style ?? "panel") === "island"
    readonly property bool showMediaSection:
        Config.options?.controlPanel?.showMediaSection ?? true
    readonly property bool showWeatherSection:
        Config.options?.controlPanel?.showWeatherSection ?? true
    readonly property bool showWallpaperSection:
        Config.options?.controlPanel?.showWallpaperSection ?? true
    readonly property bool showSystemSection:
        Config.options?.controlPanel?.showSystemSection ?? true
    readonly property bool showSlidersSection:
        Config.options?.controlPanel?.showSlidersSection ?? true
    readonly property bool showQuickActionsSection:
        Config.options?.controlPanel?.showQuickActionsSection ?? true

    implicitHeight: background.implicitHeight

    // Stagger section entry only when the panel transitions closed -> open.
    property int _entranceCascade: GlobalStates.controlPanelOpen ? 99 : -1

    Timer {
        id: entranceCascadeTimer
        interval: 45
        repeat: true
        onTriggered: {
            if (root._entranceCascade < 7)
                root._entranceCascade++
            else
                stop()
        }
    }

    Connections {
        target: GlobalStates
        function onControlPanelOpenChanged(): void {
            if (!GlobalStates.controlPanelOpen)
                return
            root._entranceCascade = -1
            entranceCascadeTimer.start()
        }
    }

    StyledRectangularShadow {
        target: background
        visible: !root.islandStyle && !Appearance.gameModeMinimal
    }

    RicelinSurface {
        anchors.fill: background
        visible: root.islandStyle
        glassEnabled: true
        screen: root.QsWindow?.window?.screen ?? null
    }

    Rectangle {
        id: background
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        implicitHeight: flickable.contentHeight + (root.compactMode ? 20 : 24)

        color: root.islandStyle ? "transparent" : Appearance.colors.colLayer0
        radius: root.islandStyle
            ? (Config.options?.appearance?.island?.radius ?? 18)
            : Appearance.rounding.large
        border.width: root.islandStyle ? 0 : 1
        border.color: Appearance.colors.colLayer0Border
        clip: true

        Behavior on color {
            enabled: Appearance.animationsEnabled
            ColorAnimation {
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }
        }

        Behavior on radius {
            enabled: Appearance.animationsEnabled
            NumberAnimation {
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }
        }

        Behavior on border.width {
            enabled: Appearance.animationsEnabled
            NumberAnimation {
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }
        }

        Flickable {
            id: flickable
            anchors.fill: parent
            anchors.margins: root.compactMode ? 10 : 12
            clip: true
            contentWidth: width
            contentHeight: contentLayout.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            flickDeceleration: 3000

            Behavior on contentY {
                enabled: Appearance.animationsEnabled
                NumberAnimation {
                    duration: Appearance.animation.scroll.duration
                    easing.type: Appearance.animation.scroll.type
                    easing.bezierCurve: Appearance.animation.scroll.bezierCurve
                }
            }

            ColumnLayout {
                id: contentLayout
                width: flickable.width
                spacing: root.compactMode ? 4 : 6

                ProfileHeader {
                    opacity: root._entranceCascade >= 0 ? 1 : 0
                    Behavior on opacity {
                        enabled: Appearance.animationsEnabled
                        NumberAnimation {
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                DateTimeHeader {
                    opacity: root._entranceCascade >= 1 ? 1 : 0
                    Behavior on opacity {
                        enabled: Appearance.animationsEnabled
                        NumberAnimation {
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                Loader {
                    Layout.fillWidth: true
                    active: root.showMediaSection
                    asynchronous: true
                    opacity: root._entranceCascade >= 2 ? 1 : 0
                    Behavior on opacity {
                        enabled: Appearance.animationsEnabled
                        NumberAnimation {
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Easing.OutCubic
                        }
                    }
                    sourceComponent: Component {
                        MediaSection {}
                    }
                }

                Loader {
                    Layout.fillWidth: true
                    active: root.showWallpaperSection
                    asynchronous: true
                    opacity: root._entranceCascade >= 3 ? 1 : 0
                    Behavior on opacity {
                        enabled: Appearance.animationsEnabled
                        NumberAnimation {
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Easing.OutCubic
                        }
                    }
                    sourceComponent: Component {
                        WallpaperSection {}
                    }
                }

                Loader {
                    Layout.fillWidth: true
                    active: root.showWeatherSection
                    asynchronous: true
                    opacity: root._entranceCascade >= 4 ? 1 : 0
                    Behavior on opacity {
                        enabled: Appearance.animationsEnabled
                        NumberAnimation {
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Easing.OutCubic
                        }
                    }
                    sourceComponent: Component {
                        WeatherSection {}
                    }
                }

                Loader {
                    Layout.fillWidth: true
                    active: root.showSystemSection
                    asynchronous: true
                    opacity: root._entranceCascade >= 5 ? 1 : 0
                    Behavior on opacity {
                        enabled: Appearance.animationsEnabled
                        NumberAnimation {
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Easing.OutCubic
                        }
                    }
                    sourceComponent: Component {
                        SystemSection {}
                    }
                }

                Loader {
                    Layout.fillWidth: true
                    active: root.showSlidersSection
                    asynchronous: true
                    opacity: root._entranceCascade >= 6 ? 1 : 0
                    Behavior on opacity {
                        enabled: Appearance.animationsEnabled
                        NumberAnimation {
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Easing.OutCubic
                        }
                    }
                    sourceComponent: Component {
                        SlidersSection {}
                    }
                }

                Loader {
                    Layout.fillWidth: true
                    active: root.showQuickActionsSection
                    asynchronous: true
                    opacity: root._entranceCascade >= 7 ? 1 : 0
                    Behavior on opacity {
                        enabled: Appearance.animationsEnabled
                        NumberAnimation {
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Easing.OutCubic
                        }
                    }
                    sourceComponent: Component {
                        QuickActionsSection {}
                    }
                }

                Item {
                    Layout.preferredHeight: 2
                }
            }

            WheelHandler {
                onWheel: event => {
                    const delta = event.angleDelta.y / 3
                    flickable.contentY = Math.max(0, Math.min(
                        flickable.contentHeight - flickable.height,
                        flickable.contentY - delta))
                }
            }
        }
    }
}
