import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root
    // Settings navigation metadata belongs to this Hadalis-side wrapper.
    // Without it IntegrationsConfig page 38 fails to instantiate before its
    // optional Hadalird payload can be loaded or checked.
    property string settingsTaskSection: ""
    implicitHeight: content.item ? content.item.implicitHeight : unavailable.implicitHeight
    Loader {
        id: content
        width: parent.width
        active: Hadalird.obsidianEnabled
        source: Hadalird.settingsSource("obsidian")
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
