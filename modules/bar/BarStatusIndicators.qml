import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root
    property bool vertical: false
    property color contentColor: Appearance.colors.colOnLayer0
    implicitWidth: indicators.implicitWidth
    implicitHeight: indicators.implicitHeight

    GridLayout {
        id: indicators
        anchors.centerIn: parent
        columns: root.vertical ? 1 : -1
        columnSpacing: 8 * Appearance.sizes.barModuleScale
        rowSpacing: 6 * Appearance.sizes.barModuleScale

        Revealer {
            vertical: root.vertical
            reveal: Audio.sink?.audio?.muted ?? false
            MaterialSymbol {
                text: "volume_off"
                iconSize: Math.round(Appearance.font.pixelSize.larger * Appearance.sizes.barModuleScale)
                color: root.contentColor
            }
        }
        Revealer {
            vertical: root.vertical
            reveal: Audio.micMuted
            MaterialSymbol {
                text: "mic_off"
                iconSize: Math.round(Appearance.font.pixelSize.larger * Appearance.sizes.barModuleScale)
                color: root.contentColor
            }
        }
        KeyboardStatusIndicator {
            vertical: root.vertical
            Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
            color: root.contentColor
        }
        Revealer {
            vertical: root.vertical
            reveal: Notifications.silent || Notifications.unread > 0
            NotificationUnreadCount {
                indicatorColor: root.contentColor
            }
        }
        MaterialSymbol {
            text: Network.materialSymbol
            iconSize: Math.round(Appearance.font.pixelSize.larger * Appearance.sizes.barModuleScale)
            color: root.contentColor

            HoverHandler {
                id: wifiHover
                onHoveredChanged: {
                    if (hovered) Network.refreshActiveNetworkDetails()
                }
            }
            StyledToolTip {
                extraVisibleCondition: wifiHover.hovered
                text: {
                    if (!Network.wifiEnabled)
                        return Translation.tr("Wi-Fi is disabled")
                    if (Network.ethernet)
                        return Translation.tr("Ethernet connected")
                    if (!Network.networkName)
                        return Translation.tr("Not connected")
                    const connected = Translation.tr("Connected to %1").arg(Network.networkName)
                    const details = Network.accessPointDetails(Network.active, true)
                    return details.length > 0 ? `${connected} | ${details}` : connected
                }
            }
        }
        MaterialSymbol {
            visible: BluetoothStatus.available
            text: BluetoothStatus.activeIcon
            iconSize: Math.round(Appearance.font.pixelSize.larger * Appearance.sizes.barModuleScale)
            color: root.contentColor

            HoverHandler { id: btHover }
            StyledToolTip {
                extraVisibleCondition: btHover.hovered
                text: BluetoothStatus.connectionTooltip()
            }
        }
    }
}
