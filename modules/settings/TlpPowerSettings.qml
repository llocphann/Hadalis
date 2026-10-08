import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root
    implicitHeight: content.item ? content.item.implicitHeight : unavailable.implicitHeight
    Loader {
        id: content
        width: parent.width
        active: Hadalird.tlpEnabled
        source: Hadalird.settingsSource("tlp")
    }
    StyledText {
        id: unavailable
        width: parent.width
        visible: !content.active
        wrapMode: Text.WordWrap
        color: Appearance.colors.colSubtext
        text: "Install Hadalird and enable this integration in Settings → Integrations."
    }
}
