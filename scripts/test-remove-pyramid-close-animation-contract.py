#!/usr/bin/env python3
"""Pyramid close stays on the shared placement/reveal geometry path."""
from pathlib import Path
import subprocess

r = Path(__file__).resolve().parents[1]
h = (r / "modules/abyss/AbyssBodyHost.qml").read_text()
c = (r / "modules/abyss/AbyssSurfaceController.qml").read_text()
g = (r / "modules/abyss/looks/AbyssGeometry.js").read_text()

for retired in ("pyramidCloseInward", "pyramidCloseTarget"):
    assert retired not in h
    assert retired not in c
assert "closeInward" not in g
assert "readonly property bool placementVisible: placement?.visible !== false" in h

# Exercise the real geometry instead of pinning this contract to one implementation
# spelling. A resolved placement must retract only through the shared progress
# scalar, preserve its tangent allocation, and reach zero without a close-only
# target or inward override.
program = g + r"""
const assert=require("node:assert/strict");
const edgeInsets={left:16,right:16,top:16,bottom:16};
const placement={
    visible:true,evicted:false,along:180,inward:120,
    span:420,depth:280,shrunk:false
};
const snapshot=JSON.stringify(placement);
function frame(progress) {
    return placedPanel(1200,900,edgeInsets,"left",180,420,280,
        progress,14,[],true,placement);
}
const full=frame(1);
const middle=frame(.4);
const closed=frame(0);

assert.equal(JSON.stringify(placement),snapshot,
    "presentation geometry must not mutate allocator placement");
assert.equal(full.along,placement.along);
assert.equal(middle.along,placement.along);
assert.equal(full.span,placement.span);
assert.equal(middle.span,placement.span);
assert(Math.abs(full.depth-(placement.depth+placement.inward))<1e-6);
assert(Math.abs(middle.depth-full.depth*.4)<1e-6,
    "close frame must follow the shared reveal scalar");
assert(middle.content.width>0 && middle.content.width<full.content.width);
assert.equal(closed.depth,0);
assert.equal(closed.surface.width,0);
assert.equal(closed.surface.height,0);
console.log("pyramid close animation experiments removed: ok");
"""
raise SystemExit(subprocess.run(["node", "-e", program], cwd=r).returncode)
