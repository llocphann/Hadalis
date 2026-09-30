#!/usr/bin/env python3
from pathlib import Path

root = Path(__file__).resolve().parents[1]
editor = (root / "modules/abyss/AbyssEdgeEditor.qml").read_text()
positions = (root / "modules/abyss/settings/AbyssPositionSettings.qml").read_text()

for needle in [
    "if (root.editingPopups)",
    "edge === previewBody.edge",
    "previewBody.joinedEdge",
    "onPreviewPositionChanged: root.scheduleToolbarRelocation()",
    "onPreviewKindChanged: root.scheduleToolbarRelocation()",
    "Math.max(340,Math.min(460,root.width*.32))",
    "id: toolbarScroll",
    "interactive: !root.toolbarOnHorizontalEdge",
    "columns:root.toolbarOnHorizontalEdge ? 5 : 1",
    "columns:root.toolbarOnHorizontalEdge ? 7 : 1",
    "compactVertical:!root.toolbarOnHorizontalEdge",
]:
    assert needle in editor, needle

assert "Math.min(820,root.width*.55" not in editor
assert "property bool compactVertical: false" in positions
assert "columns:root.compactVertical ? 1 : 2" in positions
assert "columns:root.compactVertical ? 1 : 3" in positions

print("abyss editor adaptive side-toolbar contract: ok")
