// Output-local geometry, shared by presentation, reservations and tests.
function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, Number(v) || 0)); }
function edge(vertical, bottom) { return vertical ? (bottom ? "right" : "left") : (bottom ? "bottom" : "top"); }
function horizontal(edge) { return edge === "top" || edge === "bottom"; }
function insets(thickness, barEdge, barThickness, barShown) {
    var result = {left: thickness, top: thickness, right: thickness, bottom: thickness};
    if (barShown && barEdge in result) result[barEdge] = Math.max(thickness, barThickness);
    return result;
}
function targets(name, list, connected) {
    if (!list || !list.length) return true;
    return list.indexOf(name) >= 0 || !connected.some(function(n) { return list.indexOf(n) >= 0; });
}
function panel(width, height, insets, edge, along, span, depth, progress, padding, obstacles) {
    var h = horizontal(edge);
    var first = h ? insets.left : insets.top;
    var last = h ? width - insets.right : height - insets.bottom;
    // Keep content out of perpendicular panels. Besides avoiding overlapping
    // controls this prevents a popup and sidebar sealing a second workspace
    // pocket at their corner. The final painter still computes one true union.
    for (var i=0;i<(obstacles || []).length;i++) {
        var other=obstacles[i];
        if (horizontal(other.edge) === h) continue;
        if (other.edge === "left" || other.edge === "top") first += other.depth + 48;
        else last -= other.depth + 48;
    }
    last = Math.max(first,last);
    var p = clamp(padding, 0, Math.max(0, (last-first)/8));
    span = clamp(span, 0, Math.max(0, last-first-2*p));
    along = clamp(along, first+p, Math.max(first+p, last-p-span));
    // Opposing panels can never close the workspace opening.
    depth = clamp(depth, 0, (h ? height-insets.top-insets.bottom : width-insets.left-insets.right)*0.42);
    var d = depth * clamp(progress, 0, 1.035);
    var x = h ? along : edge === "left" ? insets.left : width-insets.right-d;
    var y = h ? edge === "top" ? insets.top : height-insets.bottom-d : along;
    var crossPad = Math.min(p,d/2);
    var content = {x:x+(h?p:crossPad), y:y+(h?crossPad:p), width:Math.max(0,h?span-2*p:d-2*crossPad), height:Math.max(0,h?d-2*crossPad:span-2*p)};
    // The geometry extends through its owner to the physical screen boundary.
    // There is no detached component fill, endpoint patch or alpha overlap.
    var surface = h ? {x:along, y:edge==="top"?-50:y, width:span, height:d+insets[edge]+50}
        : {x:edge==="left"?-50:x, y:along, width:d+insets[edge]+50, height:span};
    if (d <= 0) surface = {x:0,y:0,width:0,height:0};
    return {edge:edge, content:content, surface:surface, depth:depth, span:span, along:along};
}
function roundedDistance(x, y, rect, radius) {
    var r = Math.min(radius, rect.width/2, rect.height/2);
    var qx = Math.abs(x-rect.x-rect.width/2)-rect.width/2+r;
    var qy = Math.abs(y-rect.y-rect.height/2)-rect.height/2+r;
    return Math.hypot(Math.max(qx,0),Math.max(qy,0))+Math.min(Math.max(qx,qy),0)-r;
}
function smoothUnion(a, b, k) {
    if (k <= 0) return Math.min(a,b);
    var h = Math.max(k-Math.abs(a-b),0)/k;
    return Math.min(a,b)-h*h*k*0.25;
}
function distance(x, y, width, height, insets, radius, records, softness) {
    var d = -roundedDistance(x,y,{x:insets.left,y:insets.top,width:width-insets.left-insets.right,height:height-insets.top-insets.bottom},radius);
    for (var i=0;i<records.length;i++) {
        var rec=records[i];
        if (rec.surface.width>0 && rec.surface.height>0)
            d=smoothUnion(d,roundedDistance(x,y,rec.surface,rec.radius || radius),softness);
    }
    return d;
}
