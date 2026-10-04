.pragma library

var focusedExpressions = ["sleepy","working","thinking","sad"]
function bounded(n) { return typeof n==="number" && Number.isFinite(n) ? Math.max(-1,Math.min(1,n)) : 0 }
// Travel has priority over the pointer. A sleeping/working face keeps its
// attention; stale pointer samples never keep dragging the gaze backwards.
function resolve(moving, dx, dy, pointerFresh, px, py, baseX, baseY, expression, facing = 0) {
    const focused=focusedExpressions.includes(expression) || expression==="angry" || expression==="panicked"
    const length=Math.hypot(dx,dy)
    // A pointer behind a turned face does not pull its eyes backwards. A front
    // view sees both sides; travel keeps the route as the primary attention.
    const sameSide=Math.abs(facing)<.12 || Math.abs(px)<.14 || Math.sign(px)===Math.sign(facing)
    const sameDirection=!moving || length<.01 || (dx*px+dy*py)>=0
    if (!focused && pointerFresh && sameSide && sameDirection)
        return {x:bounded(px*.95),y:bounded(py*.85),source:"pointer"}
    if (moving)
        return {x:length>0 ? bounded(dx/length*.82) : 0,y:length>0 ? bounded(dy/length*.62) : 0,source:"travel"}
    if (focused) return {x:bounded(baseX),y:bounded(baseY),source:"activity"}
    return {x:bounded(baseX),y:bounded(baseY),source:"curiosity"}
}
