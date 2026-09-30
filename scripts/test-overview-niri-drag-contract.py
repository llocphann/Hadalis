#!/usr/bin/env python3
"""Behavioral Niri Overview visual-identity and drag regression."""
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
ov = (ROOT / "modules/overview/OverviewNiriWidget.qml").read_text(encoding="utf-8")
niri = (ROOT / "services/NiriService.qml").read_text(encoding="utf-8")
waffle = (ROOT / "modules/waffle/taskview/WaffleTaskViewContent.qml").read_text(encoding="utf-8")
js = ROOT / "modules/overview/NiriOverviewModel.js"
for token in (
    'import "NiriOverviewModel.js" as OverviewModel',
    "OverviewModel.buildWindowItems(",
    "values: windowSpace.windowItems.map(record => record.id)",
    "readonly property int windowId: modelData",
    "OverviewModel.findWindowRecord(windowSpace.windowItems, windowItem.windowId)",
    "readonly property var windowData: windowRecord?.window ?? null",
    "const cache = WindowPreviewService.previewCache",
    "WindowPreviewService.getPreviewUrl(windowItem.windowId)",
    "AppSearch.getIconSource(windowItem.windowData.app_id",
    "root.resetDragState()",
    "draggedWindowId !== windowItem.windowId",
    "NiriService.moveWindowToWorkspaceById(\n                                        draggedWindowId, targetWorkspace, false)",
):
    assert token in ov, f"missing visual/drag invariant: {token}"
preview_delegate = ov.split("delegate: Item {", 1)[1].split("id: focusedWorkspaceIndicator", 1)[0]
for old in (
    "pendingWorkspaceSlot", "dragCleanupTimer", 'property string previewUrl: ""',
    "onPreviewUpdated(updatedId", "onCaptureComplete()", "Behavior on x {", "Behavior on y {",
    'objectProp: "id"', "localGeometryAnimationReady",
    "Qt.callLater(() => windowSpace.rebuildWindowItems())",
):
    assert old not in preview_delegate, f"retired visual patch remains: {old}"
assert '"window_id": windowId' in niri and '"focus": focus === undefined ? false : focus' in niri
assert '"--window-id", windowId.toString()' in waffle and '"--focus", "false"' in waffle

# Execute the SAME QML-imported pure JS projection in Node. Assert that
# repeated A->B->A drags, source column reflow and model reordering never
# change a sibling's window/app identity.
program = r"""
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const context = {};
vm.createContext(context);
vm.runInContext(fs.readFileSync(process.argv[1], 'utf8'), context);
const ws = [{id: 2, idx: 2}, {id: 3, idx: 3}];
const w = (id, app_id, workspace_id, col) => ({
    id, app_id, workspace_id, layout: {pos_in_scrolling_layout: [col, 1]}
});
const project = windows => context.buildWindowItems(windows, ws, 0, 2);
const states = [
    [w(41, 'kitty', 2, 1), w(4, 'ChatGPT', 3, 1)],
    [w(41, 'kitty', 3, 2), w(4, 'ChatGPT', 3, 1)],
    [w(4, 'ChatGPT', 3, 1), w(41, 'kitty', 2, 1)],
    [w(41, 'kitty', 3, 1), w(4, 'ChatGPT', 2, 1)],
    [w(4, 'ChatGPT', 3, 1), w(41, 'kitty', 2, 1)],
];
for (const windows of states) {
    const records = project(windows);
    assert.equal(records.length, 2);
    assert.equal(new Set(Array.from(records, r => r.id)).size, 2);
    for (const window of windows) {
        const record = context.findWindowRecord(records, window.id);
        assert.ok(record);
        assert.equal(record.id, window.id);
        assert.equal(record.window.id, window.id);
        assert.equal(record.window.app_id, window.app_id);
        assert.equal(record.window.workspace_id, window.workspace_id);
        assert.equal(record.window.layout.pos_in_scrolling_layout[0],
                     window.layout.pos_in_scrolling_layout[0]);
    }
}
assert.equal(context.findWindowRecord(project(states[0]), 999), null);
assert.equal(project([]).length, 0);
assert.equal(project([states[0][0], states[0][0]]).length, 1);
console.log('Niri Overview authoritative identity/reflow: PASS (5 states)');
"""
subprocess.run(["node", "-e", program, str(js)], check=True)
print("Niri Overview drag/render contracts: PASS")
