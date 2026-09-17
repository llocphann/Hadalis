import QtQuick
import qs.services

// Public v1.0 facade for the historical ThemesConfig implementation.
// The base page still owns the mature Material color/typography/motion tooling,
// but its retired shell-wide style selector must not be reachable in v1.0.
ThemesConfig {
    id: root

    function _stripRetiredGlobalStyleUi(item): void {
        if (!item)
            return

        // SettingsTaskNavigator on this page is the only navigator whose option
        // set contains this exact section family. Filter the retired Style tab
        // without disturbing palette/type/motion controls deeper in the page.
        if (item.options !== undefined && Array.isArray(item.options)) {
            const values = item.options.map(option => option?.value ?? "")
            const themesNavigator = values.includes("colors")
                && values.includes("style")
                && values.includes("type")
                && values.includes("motion")
            if (themesNavigator) {
                item.options = item.options.filter(option => option?.value !== "style")
                if (item.summary !== undefined)
                    item.summary = Translation.tr("Colors · typography · motion · advanced")
                if (item.description !== undefined)
                    item.description = Translation.tr("Tune Material colors, typography, motion and advanced theme tooling.")
            }
        }

        // Keep historical sections loadable for compatibility, but remove them
        // from the public v1.0 surface. This also prevents legacy editor Loaders
        // from becoming active if an old persisted section value leaks through.
        if (item.settingsTaskSection !== undefined && item.settingsTaskSection === "style")
            item.visible = false

        const childList = item.children
        if (!childList)
            return
        for (let i = 0; i < childList.length; ++i)
            root._stripRetiredGlobalStyleUi(childList[i])
    }

    function _applyMaterialOnlyUi(): void {
        ThemeService.normalizeGlobalStyle()
        if (root.activeSection === "style")
            root.activeSection = "colors"
        root._stripRetiredGlobalStyleUi(root)
    }

    onActiveSectionChanged: {
        if (activeSection === "style")
            activeSection = "colors"
    }

    Timer {
        interval: 0
        repeat: false
        running: true
        onTriggered: root._applyMaterialOnlyUi()
    }
}
