// Output-local geometry, shared by presentation, reservations and tests.
function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, Number(v) || 0)); }
function edge(vertical, bottom) { return vertical ? (bottom ? "right" : "left") : (bottom ? "bottom" : "top"); }
function horizontal(edge) { return edge === "top" || edge === "bottom"; }
// Only the popup's tangent footprint reaches its owning inner Edge. Never
// capture the output-wide strip or the full content canvas hidden by reveal.
function popupInput(content,width,height,insets,edge,paintedSurface) {
    if (!content || content.width <= 0 || content.height <= 0)
        return {x:0,y:0,width:0,height:0};
    var x=content.x,y=content.y,right=x+content.width,bottom=y+content.height;
    // Feature bounds exclude the body's visual padding. Use the unjoined
    // painted footprint when supplied, trimming its off-output extrusion at
    // the owner seam below. Corner welding must not enlarge this hover lease.
    if (paintedSurface && paintedSurface.width > 0 && paintedSurface.height > 0) {
        if (horizontal(edge)) {
            x=paintedSurface.x;right=x+paintedSurface.width;
            if (edge === "top") bottom=paintedSurface.y+paintedSurface.height;
            else y=paintedSurface.y;
        } else {
            y=paintedSurface.y;bottom=y+paintedSurface.height;
            if (edge === "left") right=paintedSurface.x+paintedSurface.width;
            else x=paintedSurface.x;
        }
    }
    if (edge === "top") y=Math.min(y,insets.top);
    else if (edge === "bottom") bottom=Math.max(bottom,height-insets.bottom);
    else if (edge === "left") x=Math.min(x,insets.left);
    else if (edge === "right") right=Math.max(right,width-insets.right);
    x=clamp(x,0,width);y=clamp(y,0,height);
    right=clamp(right,x,width);bottom=clamp(bottom,y,height);
    return {x:x,y:y,width:right-x,height:bottom-y};
}
function insets(thickness, barEdge, barThickness, barShown) {
    var result = {left: thickness, top: thickness, right: thickness, bottom: thickness};
    if (barShown && barEdge in result) result[barEdge] = Math.max(thickness, barThickness);
    return result;
}
function targets(name, list, connected) {
    if (!list || !list.length) return true;
    return list.indexOf(name) >= 0 || !connected.some(function(n) { return list.indexOf(n) >= 0; });
}
function panel(width, height, insets, edge, along, span, depth, progress, padding, obstacles, largeSurface) {
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
    span = clamp(span, 0, Math.max(0, last-first-2*p));
    along = clamp(along, first+p, Math.max(first+p, last-p-span));
    // Opposing panels can never close the workspace opening.
    depth = clamp(depth, 0, (h ? height-insets.top-insets.bottom : width-insets.left-insets.right)*(largeSurface ? 0.92 : 0.42));
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

    // A resolved placement has already passed the allocator (and any temporary
    // vacancy post-pass). Trust that placement up to the output's hard safe
    // bounds instead of reapplying panel()'s normal 42/92% resting-depth cap.
    // Base allocator placements are already capped by their requested record, so
    // this is byte-for-byte equivalent while borrowing is inactive and lets the
    // existing placement Behavior restore a borrowed depth without a clamp snap.
    var h=horizontal(edge);
    var first=h ? insets.left : insets.top;
    var last=h ? width-insets.right : height-insets.bottom;
    var pad=clamp(padding,0,Math.max(0,(last-first)/8));
    var placedAlong=Number.isFinite(Number(placement.along))
        ? Number(placement.along) : along;
    var placedSpan=Number.isFinite(Number(placement.span))
        ? Number(placement.span) : span;
    var placedDepth=Number.isFinite(Number(placement.depth))
        ? Number(placement.depth) : depth;
    var placedInward=Number.isFinite(Number(placement.inward))
        ? Math.max(0,Number(placement.inward)) : 0;

    placedSpan=clamp(placedSpan,0,Math.max(0,last-first-2*pad));
    placedAlong=clamp(placedAlong,first+pad,
        Math.max(first+pad,last-pad-placedSpan));

    var crossExtent=Math.max(0,h
        ? height-insets.top-insets.bottom
        : width-insets.left-insets.right);
    placedInward=clamp(placedInward,0,crossExtent);
    // Content/input safety is enforced by the allocator/resolver. Do not
    // subtract inward from the panel depth here: legacy resting placements may
    // legitimately carry their padding beyond the inner safe-content bound,
    // and doing so changes inactive geometry. Depth itself still cannot exceed
    // one full output cross-axis.
    placedDepth=clamp(placedDepth,0,crossExtent);

    var reveal=clamp(progress,0,1.035);
    var currentDepth=placedDepth*reveal;
    var offset=placedInward*reveal;
    var x=h ? placedAlong
        : edge === "left"
            ? insets.left+offset
            : width-insets.right-currentDepth-offset;
    var y=h
        ? edge === "top"
            ? insets.top+offset
            : height-insets.bottom-currentDepth-offset
        : placedAlong;
    var crossPad=Math.min(pad,currentDepth/2);
    var content={
        x:x+(h ? pad : crossPad),
        y:y+(h ? crossPad : pad),
        width:Math.max(0,h
            ? placedSpan-2*pad
            : currentDepth-2*crossPad),
        height:Math.max(0,h
            ? currentDepth-2*crossPad
            : placedSpan-2*pad)
    };
    var reach=currentDepth+offset;
    var surface=h
        ? {
            x:placedAlong,
            y:edge === "top" ? -50 : y,
            width:placedSpan,
            height:reach+insets[edge]+50
        }
        : {
            x:edge === "left" ? -50 : x,
            y:placedAlong,
            width:reach+insets[edge]+50,
            height:placedSpan
        };
    if (reach <= 0 || placement.visible === false)
        surface={x:0,y:0,width:0,height:0};
    return {
        edge:edge,
        content:content,
        surface:surface,
        depth:reach,
        targetDepth:placedDepth+placedInward,
        progress:reveal,
        span:placedSpan,
        along:placedAlong
    };
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
    var left=insets.left>0 ? insets.left : -64, top=insets.top>0 ? insets.top : -64;
    var right=insets.right>0 ? insets.right : -64, bottom=insets.bottom>0 ? insets.bottom : -64;
    var d = -roundedDistance(x,y,{x:left,y:top,width:width-left-right,height:height-top-bottom},radius);
    for (var i=0;i<records.length;i++) {
        var rec=records[i];
        if (rec.surface.width>0 && rec.surface.height>0)
            d=smoothUnion(d,roundedDistance(x,y,rec.surface,rec.radius ?? recordRadius ?? radius),softness);
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
