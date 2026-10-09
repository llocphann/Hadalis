#!/usr/bin/env python3
"""Guard Screen Edge hitboxes in the non-edit host against stale Region items.

This static contract supplements the native Abyss runtime test and must not be
misrepresented as proof of Niri compositor hover acceptance.
"""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
bar = (root / "modules/abyss/bar/AbyssBar.qml").read_text()
perimeter = (root / "modules/abyss/AbyssPerimeter.qml").read_text()
editor = (root / "modules/abyss/AbyssEdgeEditor.qml").read_text()
runtime = (root / "scripts/test-abyss-runtime-contract.sh").read_text()
assert 'readonly property Region inputRegion: Region {' in bar
for token in (
    'x: Math.floor(module.x)', 'y: Math.floor(module.y)',
    'Math.ceil(module.x + module.width) - Math.floor(module.x)',
    'Math.ceil(module.y + module.height) - Math.floor(module.y)',
    'module.visible && module.enabled',
    'root.inputRegions = root.inputRegions.concat([item.inputRegion])',
    'enabled: !root.editing',
):
    assert token in bar, f"missing explicit module pointer mask contract: {token}"
assert 'Region { item: module }' not in bar
assert 'Region { regions: window.presented && field.ready && bar.visible ? bar.inputRegions : [] }' in perimeter
assert 'Region { regions: window.presented && field.ready && editor.visible ? editor.regions : [] }' in perimeter
assert 'readonly property Region inputRegion: Region { item:handle;' in editor
assert 'normal-mode pointer region must track real rendered module geometry' in runtime
assert 'normal-mode input region must recover without recreating modules' in runtime
print('ABYSS_MODULE_POINTER_REGION_SOURCE_PASS dynamic geometry/edit mask boundaries')
