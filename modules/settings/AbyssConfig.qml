import QtQuick
import qs.modules.common.widgets
import qs.modules.abyss.settings
ContentPage {
    settingsPageIndex: 2
    settingsPageName: "Abyss"
    property alias activeSection: controls.activeSection
    function activateSettingsSearchSection(section: string): void {
        const value = section.toLowerCase() === "live editor" ? "editor" : section.toLowerCase()
        if (["surface","waves","modules","popups","editor","interaction","performance"].includes(value))
            activeSection = value
    }
    AbyssStyleSettings { id: controls }
}
