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
function panel(width, height, insets, edge, along, span, depth, progress, padding, obstacles, largeSurface, depthLimitRatio, tangentFlush) {
    var h = horizontal(edge);
    var first = h ? insets.left : insets.top;
    var last = h ? width - insets.right : height - insets.bottom;
    var firstBound=first, lastBound=last;
    // Keep content out of perpendicular panels. Besides avoiding overlapping
    // controls this prevents a popup and sidebar sealing a second workspace
    // pocket at their corner. The final painter still computes one true union.
    for (var i=0;i<(obstacles || []).length;i++) {
        var other=obstacles[i];
        if (horizontal(other.edge) === h) continue;
        if (other.edge === "left" || other.edge === "top") first += other.depth + 48 * (other.progress ?? 1);
        else last -= other.depth + 48 * (other.progress ?? 1);
    }
    first = clamp(first,firstBound,lastBound);
    last = Math.max(first,Math.min(last,lastBound));
    var p = clamp(padding, 0, Math.max(0, (last-first)/8));
    // Elastic Fill may grow an outer body to the inner perimeter boundary.
    // Content keeps its normal padding; only the panel's tangent safety margin
    // is relaxed while the fill (or its return animation) is active.
    var tangentMargin=tangentFlush === true ? 0 : p;
    span = clamp(span, 0, Math.max(0, last-first-2*tangentMargin));
    along = clamp(along, first+tangentMargin,
        Math.max(first+tangentMargin,last-tangentMargin-span));
    // Ordinary bodies cannot close the workspace opening. Elastic Fill is the
    // one bounded exception: its post-allocation placement may borrow only the
    // vacancy already defined by another visible related body.
    var defaultDepthRatio=largeSurface ? 0.92 : 0.42;
    var effectiveDepthRatio=Number.isFinite(Number(depthLimitRatio))
        ? clamp(depthLimitRatio,0,1) : defaultDepthRatio;
    depth = clamp(depth, 0,
        (h ? height-insets.top-insets.bottom
            : width-insets.left-insets.right)*effectiveDepthRatio);
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
    return {edge:edge, content:content, surface:surface, depth:d, targetDepth:depth, progress:clamp(progress,0,1.035), span:span, along:along};
}
// Keep each body's readable contents at its requested size while its one union
// record reaches through the inner tier to the physical Edge.
function placedPanel(width,height,insets,edge,along,span,depth,progress,padding,obstacles,largeSurface,placement) {
    if (!placement) return panel(width,height,insets,edge,along,span,depth,progress,padding,obstacles,largeSurface);
    // Placement may reflow a body, but its allocator preserves the physical
    // anchor center. Build the actual panel at that size instead of shifting a
    // full-size record after the fact; content/input/field then share geometry.
    var placedAlong = Number.isFinite(Number(placement.along)) ? Number(placement.along) : along;
    var placedSpan = Number.isFinite(Number(placement.span)) ? Number(placement.span) : span;
    var placedDepth = Number.isFinite(Number(placement.depth)) ? Number(placement.depth) : depth;
    var elasticLimits=placement.elasticFilled === true
        || placement.elasticLimits === true;
    var depthLimit=elasticLimits ? 1 : undefined;
    var base = panel(width,height,insets,edge,placedAlong,placedSpan,placedDepth,
        progress,padding,[],largeSurface,depthLimit,elasticLimits);
    var p = clamp(progress,0,1.035), offset = placement.inward*p;
    if (horizontal(edge)) {
        base.content.y += edge === "top" ? offset : -offset;
        if (edge === "bottom") base.surface.y -= offset;
        base.surface.height += offset;
    } else {
        base.content.x += edge === "left" ? offset : -offset;
        if (edge === "right") base.surface.x -= offset;
        base.surface.width += offset;
    }
    base.depth += offset;
    base.targetDepth += placement.inward;
    if (!placement.visible) base.surface = {x:0,y:0,width:0,height:0};
    return base;
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
function distance(x, y, width, height, insets, radius, records, softness, recordRadius) {
    var d = -roundedDistance(x,y,{x:insets.left,y:insets.top,width:width-insets.left-insets.right,height:height-insets.top-insets.bottom},radius);
    for (var i=0;i<records.length;i++) {
        var rec=records[i];
        if (rec.surface.width>0 && rec.surface.height>0)
            d=smoothUnion(d,roundedDistance(x,y,rec.surface,rec.radius || recordRadius || radius),softness);
    }
    return d;
}

function barZones(layout, vertical, modules) {
    var keys=vertical ? ["top","centerTop","center","centerBottom","bottom"] : ["left","centerLeft","center","centerRight","right"];
    var seen={};
    return keys.map(function(key) {
        return (layout[key] || []).map(function(id) { return id === "sysTray" ? "tray" : id; })
            .filter(function(id) {
                if (id === "spacer" || seen[id]) return false;
                seen[id]=true;
                return modules[id === "tray" ? "sysTray" : id] !== false;
            });
    });
}

// Extend the same union record through a nearby adjacent Edge. Content geometry
// and input bounds stay unchanged; no second connector/painter is constructed.
function joinCorner(record, adjacent, width, height, insets) {
    if (!record || !record.surface || record.surface.width<=0 || record.surface.height<=0
            || !["left","right","top","bottom"].includes(adjacent)
            || horizontal(record.edge)===horizontal(adjacent)) return record;
    var surface = record.surface;
    var gap = adjacent==="left" ? surface.x-insets.left
        : adjacent==="right" ? width-insets.right-surface.x-surface.width
        : adjacent==="top" ? surface.y-insets.top
        : height-insets.bottom-surface.y-surface.height;
    if (gap>160) return record; // A separately positioned popup cannot bridge the workspace.
    surface = Object.assign({},surface);
    if (adjacent==="left") { surface.width += surface.x+50;surface.x=-50; }
    else if (adjacent==="right") surface.width=width+50-surface.x;
    else if (adjacent==="top") { surface.height += surface.y+50;surface.y=-50; }
    else surface.height=height+50-surface.y;
    return Object.assign({},record,{surface:surface,joinedEdge:adjacent});
}
