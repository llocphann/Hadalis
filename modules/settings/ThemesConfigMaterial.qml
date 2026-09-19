import QtQuick
import qs.services

// Public v1.0 facade for Material-only theme settings.
// ThemesConfig owns only supported Material color/type/motion tooling. Keep a
// narrow legacy-section redirect here so stale navigation state cannot reopen
// the retired shell-wide Global Style surface.
ThemesConfig {
    id: root

    Component.onCompleted: ThemeService.normalizeGlobalStyle()

    onActiveSectionChanged: {
        if (activeSection === "style")
            activeSection = "colors"
    }
}
