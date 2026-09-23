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
    readonly property int barPageIndex: 2
    readonly property int panelsPageIndex: 5

    // A renderer-specific page is shown only for its active panel family.
    // Keep historical slots in the registry so stored indices remain stable.
    readonly property bool waffleFamily: Config.options?.panelFamily === "waffle"
    function isPageApplicable(index: int): bool {
        if (index < 0 || index >= root.pages.length
                || root.isHiddenLegacyIndex(index)) return false
        if (root.waffleFamily)
            return index !== root.barPageIndex && index !== 16 && index !== 29
        return index !== 11
    }

    // Stable route keys survive page reordering and legacy numeric slot
    // retirement. The active Settings chrome navigates inside its own window
    // instead of spawning a second instance when a related-settings link runs.
    signal navigateRequested(int pageIndex, string section)
    function pageIndexForKey(key: string): int {
        const value = String(key ?? "").trim()
        if (!value) return -1
        return root.pages.findIndex((page, index) => page.key === value
            && page.devNavigationHidden !== true
            && root.isPageApplicable(index))
    }
    function navigateToKey(key: string, section: string): bool {
        const index = root.pageIndexForKey(key)
        if (index < 0) return false
        root.navigateRequested(index, String(section ?? ""))
        return true
    }
    property bool _legacyTlpPowerRedirectPending: false
    property bool _legacyDockStyleMigrationDone: false
    property bool _legacyUiLocaleMigrationDone: false
    property bool _legacyBarCornerStyleMigrationDone: false
    property bool _legacyBarBackgroundMigrationDone: false
    property bool _legacySidebarSurfaceMigrationDone: false
    property bool _legacyScreenEdgeShadowMigrationDone: false

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

    function _migrateLegacyBarCornerStyle(): void {
        if (root._legacyBarCornerStyleMigrationDone || !Config.ready)
            return

        root._legacyBarCornerStyleMigrationDone = true
        // cornerStyle is retained only as a compatibility field for persisted
        // configs. Hug is the sole supported Classic Bar surface geometry.
        if ((Config.options?.bar?.cornerStyle ?? 0) !== 0)
            Config.setNestedValue("bar.cornerStyle", 0)
    }

    function _migrateLegacyBarBackground(): void {
        if (root._legacyBarBackgroundMigrationDone || !Config.ready)
            return

        root._legacyBarBackgroundMigrationDone = true
        // The supported Hug Bar is a structural connected surface. A legacy
        // transparent-bar value removes both its endpoint shoulders and the
        // shared inward shadow, leaving popups visually detached.
        if (!(Config.options?.bar?.showBackground ?? true))
            Config.setNestedValue("bar.showBackground", true)
    }

    function _migrateLegacySidebarSurface(): void {
        if (root._legacySidebarSurfaceMigrationDone || !Config.ready)
            return

        root._legacySidebarSurfaceMigrationDone = true
        // Panel is the sole public Sidebar surface for v1.0. Keep the old
        // fields readable so persisted configs load, then normalize them away.
        if ((Config.options?.sidebar?.style ?? "panel") !== "panel")
            Config.setNestedValue("sidebar.style", "panel")
        if (Config.options?.sidebar?.cardStyle ?? false)
            Config.setNestedValue("sidebar.cardStyle", false)
    }

    function _migrateLegacyScreenEdgeShadow(): void {
        if (root._legacyScreenEdgeShadowMigrationDone || !Config.ready)
            return

        root._legacyScreenEdgeShadowMigrationDone = true
        const size = Number(Config.options?.appearance?.screenEdge?.shadow?.size ?? 15)
        const opacity = Number(Config.options?.appearance?.screenEdge?.shadow?.opacity ?? 0.70)

        // 12px / 24% was Hadalis' provisional shadow and is too weak to read on
        // dark wallpapers. Migrate only that exact legacy pair; any user-tuned
        // value is preserved. Caelestia's current ContentWindow uses blurMax=15
        // with 0.7 shadow alpha.
        if (size === 12 && Math.abs(opacity - 0.24) < 0.001) {
            Config.setNestedValue("appearance.screenEdge.shadow.size", 15)
            Config.setNestedValue("appearance.screenEdge.shadow.opacity", 0.70)
        }
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

                redirected.pageIndex = root.systemPageIndex
                redirected.pageName = root.pages[root.systemPageIndex].name
                // Battery care is integrated into the primary Power card;
                // legacy charge-limit searches land on that same visible target.
                redirected.section = Translation.tr("Power")
                redirected.label = Translation.tr("Battery & TLP")
                redirected.keywords = keywords.concat(["system", "settings", "power"])
                return redirected
            })
    }

    Component.onCompleted: {
        root._migrateLegacyPersistentPage()
        root._migrateLegacyDockStyle()
        root._migrateLegacyUiLocale()
        root._migrateLegacyBarCornerStyle()
        root._migrateLegacyBarBackground()
        root._migrateLegacySidebarSurface()
        root._migrateLegacyScreenEdgeShadow()
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
                root._migrateLegacyBarCornerStyle()
                root._migrateLegacyBarBackground()
                root._migrateLegacySidebarSurface()
                root._migrateLegacyScreenEdgeShadow()
            }
        }
    }
}
