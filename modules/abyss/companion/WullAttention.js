.pragma library

var focusedExpressions = ["sleepy","working","thinking","sad"]
function bounded(n) { return typeof n==="number" && Number.isFinite(n) ? Math.max(-1,Math.min(1,n)) : 0 }
// Travel has priority over the pointer. A sleeping/working face keeps its
// attention; stale pointer samples never keep dragging the gaze backwards.
function resolve(moving, dx, dy, pointerFresh, px, py, baseX, baseY, expression) {
    if (moving) {
        const length=Math.hypot(dx,dy)
        return {x:length>0 ? bounded(dx/length*.82) : 0,y:length>0 ? bounded(dy/length*.62) : 0,source:"travel"}
    }
    if (focusedExpressions.includes(expression))
        return {x:bounded(baseX),y:bounded(baseY),source:"activity"}
    if (pointerFresh)
        return {x:bounded(px),y:bounded(py),source:"pointer"}
    return {x:bounded(baseX),y:bounded(baseY),source:"curiosity"}
}
