#!/usr/bin/env python3
from pathlib import Path

root = Path(__file__).resolve().parents[1]
text = (root / "modules/abyss/AbyssEdgeEditor.qml").read_text()

required = [
    'property string toolbarEdge: "bottom"',
    "function toolbarEdgeScore(edge): real",
    "function bestToolbarEdge(): string",
    "function scheduleToolbarRelocation(): void",
    "function relocateToolbar(): void",
    "score += 220",
    "onDraftChanged: root.scheduleToolbarRelocation()",
    "onEditingEdgeChanged: root.scheduleToolbarRelocation()",
    "id: toolbarRelocate",
    "interval: 90",
    "edge: root.toolbarEdge",
    "root.toolbarOnHorizontalEdge",
]
for needle in required:
    assert needle in text, needle

assert 'edge: "bottom"; identity: "edgeEditor"' not in text
print("abyss edge editor toolbar relocation contract: ok")
