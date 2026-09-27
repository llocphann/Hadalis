import QtQuick
import qs.modules.settings

// The mature rail/card is reparented here; no second settings page tree.
Item {
    id: root
    property string outputName: ""
    SettingsOverlay { embeddedHost: root }
}
