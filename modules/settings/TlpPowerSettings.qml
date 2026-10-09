import QtQuick
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root
    property string settingsTaskSection: "power"
    property int selectedCategoryIndex: 0
    readonly property var navigationCategories: content.item?.navigationCategories ?? ([])

    onSelectedCategoryIndexChanged: {
        if (content.item && content.item.selectedCategoryIndex !== root.selectedCategoryIndex)
            content.item.selectedCategoryIndex = root.selectedCategoryIndex
    }
    implicitHeight: content.item ? content.item.implicitHeight : unavailable.implicitHeight
    Loader {
        id: content
        width: parent.width
        active: Hadalird.tlpEnabled
        source: Hadalird.settingsSource("tlp")
        onLoaded: item.selectedCategoryIndex = root.selectedCategoryIndex
    }
    Connections {
        target: content.item
        function onSelectedCategoryIndexChanged(): void {
            if (content.item)
                root.selectedCategoryIndex = content.item.selectedCategoryIndex
        }
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
