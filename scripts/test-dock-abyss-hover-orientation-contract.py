#!/usr/bin/env python3
from pathlib import Path
r=Path(__file__).resolve().parents[1]
apps=(r/"modules/dock/DockApps.qml").read_text()
btn=(r/"modules/dock/DockAppButton.qml").read_text()
ctx=(r/"modules/common/widgets/ContextMenu.qml").read_text()
menu=(r/"modules/dock/DockContextMenu.qml").read_text()
abyss=(r/"modules/abyss/content/AbyssDockContent.qml").read_text()
dock=(r/"modules/dock/Dock.qml").read_text()
settings=(r/"modules/settings/DockConfig.qml").read_text()
ripple=(r/"modules/common/widgets/RippleButton.qml").read_text()
qmldir=(r/"modules/dock/qmldir").read_text()
assert "signal closeAllContextMenus(var exceptOwner)" in apps
assert "function refreshAxisLayout(): void" in apps
assert "listView.forceLayout()" in apps
assert "root.appListRoot.closeAllContextMenus(root)" in btn
assert "if (exceptOwner !== root)" in btn
assert "property color panelFallbackColor" in ctx
assert "AbyssStyle.surfaceDeep" in menu and "AbyssStyle.accent" in menu
assert "showDashboardButton" in abyss
assert dock.count("showDashboardButton") >= 2
assert "Show Dashboard icon" in settings

# Dock icon ordering is configured in Settings. Runtime pointer-drag state was
# retired so there is one ordering source of truth instead of competing paths.
for token in (
    "dragActive",
    "startDrag(",
    "updateDrag(",
    "endDrag(",
    "cancelDrag()",
    "dropTargetIndex",
    "reorderDragProxy",
    "_dockDragStarted",
    "insertionLine",
    "abyssMenuDismissPresenter",
    "_suppressNextClick",
):
    assert token not in apps
assert "pointerDragAxis" not in ripple
assert "drag.axis: Drag.XAndYAxis" in ripple
assert "Drag to reorder" not in settings
assert "enableDragReorder" not in apps
assert "enableDragReorder" not in settings
assert "function movePinnedApp(fromIndex: int, delta: int): void" in settings
assert 'Config.setNestedValue("dock.pinnedApps", values)' in settings
assert 'title: Translation.tr("Pinned app order")' in settings
assert 'text: "arrow_upward"' in settings
assert 'text: "arrow_downward"' in settings
assert "const pinnedOrder = new Map()" in apps
assert "if (aPinned && bPinned)" in apps
assert "return aPinned ? -1 : 1" in apps

# Dock hover is now one app-popup interaction. Legacy Dock window-preview
# surfaces and their Settings controls must stay retired.
assert "root.showContextMenu(true)" in btn
assert "hoverPreviewRequested" not in btn
assert "hoverPreviewDismissed" not in btn
assert "Config.options?.dock?.hoverPreview" not in btn
assert "DockPreview {" not in apps
assert "showPreviewPopup" not in apps
assert "dockPreviewPopup" not in apps
assert 'Translation.tr("Window preview")' not in settings
assert 'Translation.tr("Show preview on hover")' not in settings
assert 'Config.setNestedValue("dock.hoverPreview"' not in settings
assert 'Config.setNestedValue("dock.hoverPreviewDelay"' not in settings
assert "DockPreview 1.0" not in qmldir
assert "DockWindowPreview 1.0" not in qmldir
print("dock popup/orientation/dashboard-toggle/settings-order contract: ok")
