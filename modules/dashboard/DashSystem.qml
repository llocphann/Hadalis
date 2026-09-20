import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

/**
 * System monitor card: CPU, memory (and GPU when reported) usage bars.
 * ResourceUsage polling only runs while the card is visible (transient panel
 * pattern: ensureRunning gated on visible, auto-stops afterwards).
 */
DashCard {
    id: root
    title: Translation.tr("System")
    icon: "monitor_heart"

    readonly property bool thinkFanManaged:
        ThinkFanService.stateKnown && ThinkFanService.profile === "managed"
    readonly property bool thinkFanCanApply:
        ThinkFanService.stateKnown
        && ThinkFanService.serviceInstalled
        && !ThinkFanService.busy
        && (root.thinkFanManaged || ThinkFanService.available)

    // keepAlive while shown so values keep updating past the 15s auto-stop;
    // always released on hide/destroy. _holding guards against double counts.
    property bool _holding: false
    function _syncPolling() {
        if (visible && !_holding) {
            _holding = true
            ResourceUsage.keepAlive()
            ThinkFanService.refresh()
        } else if (!visible && _holding) {
            _holding = false
            ResourceUsage.releaseKeepAlive()
        }
    }
    onVisibleChanged: _syncPolling()
    Component.onCompleted: _syncPolling()
    Component.onDestruction: if (_holding) { _holding = false; ResourceUsage.releaseKeepAlive() }

    component UsageRow: ColumnLayout {
        id: usageRow
        property string label: ""
        property real value: 0
        Layout.fillWidth: true
        visible: root.zzzEverywhere
        spacing: 4

        ZzzStatBar {
            label: usageRow.label
            value: usageRow.value
            fillColor: usageRow.label === Translation.tr("Memory") ? Appearance.zzz.secondary
                : usageRow.label === Translation.tr("GPU") ? Appearance.zzz.tertiary
                : Appearance.zzz.accent
            textColor: root.colText
            labelColor: root.colSubtext
        }
    }

    UsageRow {
        label: Translation.tr("CPU")
        value: ResourceUsage.cpuUsage
    }
    UsageRow {
        label: Translation.tr("Memory")
        value: ResourceUsage.memoryUsedPercentage
    }
    UsageRow {
        visible: root.zzzEverywhere && ResourceUsage.gpuUsage > 0
        label: Translation.tr("GPU")
        value: ResourceUsage.gpuUsage
    }

    Item {
        visible: !root.zzzEverywhere
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 84

        RowLayout {
            id: meterRow
            anchors.centerIn: parent
            width: Math.min(parent.width, 220)
            height: Math.min(parent.height, 104)
            spacing: Math.max(10, Math.min(18, width / 12))

            component VerticalBar: ColumnLayout {
                id: bar
                required property real value
                required property string icon
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 6

                readonly property color barColor: bar.value > 0.8 ? Appearance.colors.colError
                    : bar.value > 0.6 ? Appearance.colors.colTertiary
                    : root.colAccent

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: `${Math.round(bar.value * 100)}%`
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.family: Appearance.font.family.numbers
                    color: root.colSubtext
                }

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.fillHeight: true
                    implicitWidth: 8
                    radius: 4
                    color: ColorUtils.applyAlpha(root.colSubtext, 0.18)

                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width
                        radius: parent.radius
                        height: parent.height * Math.max(0, Math.min(1, bar.value))
                        color: bar.barColor
                        Behavior on height {
                            enabled: Appearance.animationsEnabled
                            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration; easing.type: Appearance.animation.elementMoveFast.type; easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve }
                        }
                    }
                }

                MaterialSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    text: bar.icon
                    iconSize: Appearance.font.pixelSize.normal
                    color: bar.barColor
                }
            }

            VerticalBar { icon: "memory"; value: ResourceUsage.cpuUsage }
            VerticalBar { icon: "developer_board"; value: ResourceUsage.memoryUsedPercentage }
            VerticalBar { visible: ResourceUsage.gpuUsage > 0; icon: "videogame_asset"; value: ResourceUsage.gpuUsage }
        }
    }

    Rectangle {
        visible: !root.zzzEverywhere
        Layout.fillWidth: true
        implicitHeight: 1
        color: Appearance.colors.colOutlineVariant
        opacity: 0.55
    }

    RowLayout {
        id: thinkFanRow
        visible: !root.zzzEverywhere
        Layout.fillWidth: true
        spacing: 6

        Item {
            Layout.fillWidth: true
            implicitHeight: fanControl.implicitHeight

            RowLayout {
                id: fanControl
                anchors.centerIn: parent
                spacing: 4

                MaterialSymbol {
                    text: "mode_fan"
                    fill: root.thinkFanManaged ? 1 : 0
                    iconSize: Appearance.font.pixelSize.normal
                    color: root.thinkFanManaged
                        ? Appearance.colors.colPrimary
                        : root.colSubtext
                }

                StyledText {
                    text: Translation.tr("Fan")
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: root.colSubtext
                }

                StyledSwitch {
                    checked: root.thinkFanManaged
                    enabled: root.thinkFanCanApply
                    activeFocusOnTab: true
                    Accessible.name:
                        Translation.tr("Use ThinkFan managed fan control")

                    onToggled: {
                        ThinkFanService.applyProfile(
                            checked ? "managed" : "firmware")
                        checked = Qt.binding(() => root.thinkFanManaged)
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            implicitHeight: rpmMetrics.implicitHeight

            RowLayout {
                id: rpmMetrics
                anchors.centerIn: parent
                spacing: 3

                StyledText {
                    text: Translation.tr("RPM:")
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: root.colSubtext
                }
                StyledText {
                    text: ThinkFanService.fanRpm >= 0
                        ? String(ThinkFanService.fanRpm) : "—"
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.weight: Font.Medium
                    color: root.colText
                }
            }
        }

        Item {
            Layout.fillWidth: true
            implicitHeight: levelMetrics.implicitHeight

            RowLayout {
                id: levelMetrics
                anchors.centerIn: parent
                spacing: 3

                StyledText {
                    text: Translation.tr("Level:")
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    color: root.colSubtext
                }
                StyledText {
                    text: ThinkFanService.fanLevel.length > 0
                        ? ThinkFanService.fanLevel : "—"
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.weight: Font.Medium
                    color: root.colText
                }
            }
        }
    }
}
