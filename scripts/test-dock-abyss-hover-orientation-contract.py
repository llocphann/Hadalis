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

# Reordering is owned by RippleButton's one MouseArea. Its built-in drag
# moves a proxy; the visible delegate follows that exact delta until drop.
assert "dragTarget: !dockDelegate.isSeparator ? reorderDragProxy : null" in apps
assert "pointerDragThreshold: root.dragThreshold" in apps
assert "pointerDragAxis: root.vertical ? Drag.YAxis : Drag.XAxis" in apps
assert "onPointerDragActiveChanged:" in apps
assert "property bool _dockDragStarted: false" in apps
assert "dockDelegate._dragPressListX + reorderDragProxy.x" in apps
assert "dockDelegate._dragPressListY + reorderDragProxy.y" in apps
assert "property real _dragOffsetX: isBeingDragged ? reorderDragProxy.x : 0" in apps
assert "property real _dragOffsetY: isBeingDragged ? reorderDragProxy.y : 0" in apps
assert "root.startDrag(dockDelegate.index, appId," in apps
assert "root.updateDrag(" in apps
assert "root.endDrag()" in apps
assert "root.cancelDrag()" in apps
assert "root._suppressNextClick = true" in apps
assert "property var abyssMenuDismissPresenter: null" in apps
assert "root.abyssMenuDismissPresenter()" in apps
assert "abyssMenuDismissPresenter: () => root.closeAppMenu()" in abyss
assert "DragHandler {" not in apps
assert "_dockPrimeTimer" not in apps
assert "_dragPrimed" not in apps
assert "_longPressTriggered" not in apps
assert "Long-press and drag dock icons" not in settings
assert "Drag to reorder" not in settings
assert "enableDragReorder" not in apps
assert "enableDragReorder" not in settings
assert "property int pointerDragAxis: Drag.XAndYAxis" in ripple
assert "drag.axis: root.pointerDragAxis" in ripple

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
print("dock popup/orientation/dashboard-toggle/drag contract: ok")
