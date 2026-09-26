#!/usr/bin/env python3
"""Execute production sidebar order/layout and paused/hidden media policies."""
from pathlib import Path
import re
import subprocess

root = Path(__file__).resolve().parents[1]
sidebar = (root / "modules/sidebarRight/SidebarRightContent.qml").read_text()

def block(text, marker):
    tail = text.split(marker, 1)[1]
    start = tail.index("{")
    depth = 1
    for end in range(start + 1, len(tail)):
        if tail[end] == "{": depth += 1
        elif tail[end] == "}": depth -= 1
        if depth == 0: return tail[start + 1:end]
    raise AssertionError(marker)

order = block(sidebar, "readonly property var sectionOrder:")
move = block(sidebar, "function moveSection(")
displacement = block(sidebar, "function getSectionDisplacementY(")
elastic = re.search(r"readonly property bool usesElasticPool: (.+)", sidebar)[1]
media = (root / "modules/controlPanel/MediaSection.qml").read_text()
ticker = media.split("readonly property bool positionTickerActive:", 1)[1].split("\n\n", 1)[0].strip()
cava = re.search(r"active: (root.visible && root.hasPlayer[^\n]+)", media)[1]
program = r"""
const assert = require('node:assert/strict');
const root = {_sectionDefaultOrder: ['system','sliders','toggles','widgets']};
let saved, writes = [];
const Config = {options: {sidebar: {right: {}}}, setNestedValue: (key,value) => writes.push([key,value])};
const contentColumn = {spacing: 10};
function resolveOrder() {""" + order + """}
Config.options.sidebar.right.sectionOrder = ['widgets','stale','widgets','system'];
root.sectionOrder = resolveOrder();
assert.deepEqual(root.sectionOrder, ['widgets','system','sliders','toggles']);
function moveSection(fromIdx,toIdx) {""" + move + """}
moveSection(0,3); assert.deepEqual(writes[0], ['sidebar.right.sectionOrder',['system','sliders','toggles','widgets']]);
moveSection(0,0); moveSection(-1,0); assert.equal(writes.length,1);
function offset(itemIndex,sectionDragIndex,sectionHoverIndex) {
    const _sectionHeights = [30,40,50,60];
""" + displacement + """}
assert.equal(offset(1,0,2), -40); assert.equal(offset(2,0,2), -40);
assert.equal(offset(3,0,2), 0); assert.equal(offset(0,0,2), 0);
assert.equal(offset(0,2,0), 60); assert.equal(offset(1,2,0), 60);
assert.equal(offset(1,-1,-1),0);
function fills(isElastic,contentCollapsed) { return """ + elastic + """; }
assert(fills(true,false)); assert(!fills(true,true)); assert(!fills(false,false));
const MprisPlaybackState = {Playing: 1};
const GlobalStates = {controlPanelOpen: false};
function ticks() { return """ + ticker + """; }
root.player = {playbackState: 1}; assert(!ticks());
GlobalStates.controlPanelOpen = true; assert(ticks());
root.player.playbackState = 0; assert(!ticks());
function visualizes() { return """ + cava + """; }
root.visible = true; root.hasPlayer = true; root.effectiveIsPlaying = true;
assert(visualizes()); root.effectiveIsPlaying = false; assert(!visualizes());
root.effectiveIsPlaying = true; root.visible = false; assert(!visualizes());
"""
result = subprocess.run(["node", "-e", program])
if result.returncode: raise SystemExit(result.returncode)
print("ok - production sidebar order/elastic layout and paused/hidden media lifecycles")
