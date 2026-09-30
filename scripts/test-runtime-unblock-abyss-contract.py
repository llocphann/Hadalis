#!/usr/bin/env python3
from pathlib import Path
r=Path(__file__).resolve().parents[1]
cfg=(r/"modules/common/Config.qml").read_text()
body=(r/"modules/abyss/AbyssBodyHost.qml").read_text()
per=(r/"modules/abyss/AbyssPerimeter.qml").read_text()
side=(r/"modules/sidebarRight/CompactSidebarRightContent.qml").read_text()
qm=(r/"modules/abyss/content/qmldir").read_text()
assert "property bool showDashboardButton: true" in cfg
assert "!placementAvailable || placement.visible !== false" in body
assert "if (!root.open && root.progress > 0.001)" in body
assert '["wifi","bluetooth","utilities","launcher"].includes(contentKind)' in per
assert "import qs.services.deferred" in side
assert "AbyssLauncherControlsPopup 1.0 AbyssLauncherControlsPopup.qml" in qm
print("runtime unblock contracts: ok")
