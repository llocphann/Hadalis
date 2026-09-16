pragma Singleton
import QtQuick
import Quickshell
import qs.services
import qs.modules.common

/**
 * Public Settings registry facade.
 *
 * SettingsPageRegistryData intentionally keeps historical indices so persisted
 * settings-page values remain loadable. Retired feature pages are hidden here
 * and redirected to live pages only when an old direct index is opened.
 */
Singleton {
    id: root

    readonly property var retiredFeaturePageIndexes: [18, 19, 21, 27]
    readonly property int retiredTlpPageIndex: 28
    readonly property int systemPageIndex: 1
    readonly property int panelsPageIndex: 5
    property bool _legacyTlpPowerRedirectPending: false
    property bool _legacyDockStyleMigrationDone: false
    property bool _legacyUiLocaleMigrationDone: false

    function isRetiredFeaturePage(index: int): bool {
        return root.retiredFeaturePageIndexes.includes(index)
    }

    readonly property var pages: SettingsPageRegistryData.pages.map((page, index) => {
        if (root.isRetiredFeaturePage(index)) {
            const panelsPage = SettingsPageRegistryData.pages[root.panelsPageIndex]
            return Object.assign({}, panelsPage, {
                devNavigationHidden: true
            })
        }
        if (index !== root.retiredTlpPageIndex)
            return page
        const systemPage = SettingsPageRegistryData.pages[root.systemPageIndex]
        return Object.assign({}, page, {
            name: systemPage.name,
            icon: systemPage.icon,
            desc: systemPage.desc,
            essential: systemPage.essential,
            component: systemPage.component,
            devNavigationHidden: true
        })
    })

    function isHiddenLegacyIndex(index: int): bool {
        return index === root.retiredTlpPageIndex || root.isRetiredFeaturePage(index)
    }

    readonly property var defaultCategories: SettingsPageRegistryData.defaultCategories.map(category => ({
        label: category.label,
        pages: category.pages.filter(index => !root.isHiddenLegacyIndex(index))
    }))

    readonly property var categories: SettingsPageRegistryData.categories.map(category => ({
        label: category.label,
        pages: category.pages.filter(index => !root.isHiddenLegacyIndex(index))
    }))

    readonly property var hiddenPages: SettingsPageRegistryData.hiddenPages.filter(
        index => !root.isHiddenLegacyIndex(index))

    readonly property var _arrangement: ({ groups: root.categories, hidden: root.hiddenPages })

    function _migrateLegacyPersistentPage(): void {
        if (!Persistent.ready || !Persistent.states?.settings)
            return

        const current = Number(Persistent.states.settings.iiPage ?? -1)
        if (root.isRetiredFeaturePage(current)) {
            Persistent.states.settings.iiPage = root.panelsPageIndex
            return
        }
        if (current !== root.retiredTlpPageIndex)
            return

        Persistent.states.settings.iiPage = root.systemPageIndex
        root._legacyTlpPowerRedirectPending = true
    }

    function _migrateLegacyDockStyle(): void {
        if (root._legacyDockStyleMigrationDone || !Config.ready)
            return

        root._legacyDockStyleMigrationDone = true
        if ((Config.options?.dock?.style ?? "panel") !== "panel")
            Config.setNestedValue("dock.style", "panel")
    }

    function _migrateLegacyUiLocale(): void {
        if (root._legacyUiLocaleMigrationDone || !Config.ready)
            return

        root._legacyUiLocaleMigrationDone = true
        if ((Config.options?.language?.ui ?? "en_US") !== "en_US")
            Config.setNestedValue("language.ui", "en_US")
    }

    function consumeLegacyTlpPowerRedirect(): bool {
        if (!root._legacyTlpPowerRedirectPending)
            return false
        root._legacyTlpPowerRedirectPending = false
        return true
    }

    function iconForPage(idx) {
        return (idx >= 0 && idx < root.pages.length)
            ? (root.pages[idx].icon || "settings") : "settings"
    }

    function searchIndex(): var {
        return SettingsPageRegistryData.searchIndex()
            .filter(entry => !root.isRetiredFeaturePage(entry.pageIndex))
            .map(entry => {
                if (entry.pageIndex !== root.retiredTlpPageIndex)
                    return entry

                const redirected = Object.assign({}, entry)
                const keywords = Array.isArray(entry.keywords) ? entry.keywords : []
                const chargeCareEntry = keywords.includes("threshold")
                    || keywords.includes("conservation")

                redirected.pageIndex = root.systemPageIndex
                redirected.pageName = root.pages[root.systemPageIndex].name
                redirected.section = chargeCareEntry
                    ? Translation.tr("Power") + " · " + Translation.tr("Battery Care")
                    : Translation.tr("Power")
                redirected.label = chargeCareEntry
                    ? Translation.tr("Hardware-aware charge care")
                    : Translation.tr("Battery and TLP power management")
                redirected.keywords = keywords.concat(["system", "settings", "power"])
                return redirected
            })
    }

    Component.onCompleted: {
        root._migrateLegacyPersistentPage()
        root._migrateLegacyDockStyle()
        root._migrateLegacyUiLocale()
    }

    Connections {
        target: Persistent
        function onReadyChanged(): void {
            if (Persistent.ready)
                root._migrateLegacyPersistentPage()
        }
    }

    Connections {
        target: Config
        function onReadyChanged(): void {
            if (Config.ready) {
                root._migrateLegacyDockStyle()
                root._migrateLegacyUiLocale()
            }
        }
    }
}
