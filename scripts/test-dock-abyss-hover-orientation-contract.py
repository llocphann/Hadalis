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

# Reordering must follow the normal pointer gesture: crossing the movement
# threshold starts drag immediately. A time-gated prime makes natural
# press-and-move gestures permanently cancel themselves before drag begins.
assert "property bool _dragGestureStarted: false" in apps
assert "&& dist2 > root.dragThreshold * root.dragThreshold" in apps
assert "root.startDrag(dockDelegate.index, appId, listPos.x, listPos.y)" in apps
assert "root.updateDrag(listPos.x, listPos.y)" in apps
assert "cancelAction: () => {" in apps
assert "root.cancelDrag()" in apps
assert "root.endDrag()" in apps
assert "root._suppressNextClick = true" in apps
assert "_dockPrimeTimer" not in apps
assert "_dragPrimed" not in apps
assert "_longPressTriggered" not in apps
assert "Long-press and drag dock icons" not in settings
assert "Drag dock icons to reorder pinned and running apps" in settings
print("dock hover/style/orientation/dashboard-toggle/drag contract: ok")
