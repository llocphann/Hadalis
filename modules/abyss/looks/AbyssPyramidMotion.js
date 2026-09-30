// Presentation-only helpers for Pyramid Popup v2.
//
// This file never allocates resting tiers. AbyssBodyPlacement remains the sole
// resting-layout authority; these helpers only build visual snapshots/reveal
// records from already-resolved placements.
function _number(value, fallback) {
    var n=Number(value);
    return Number.isFinite(n) ? n : fallback;
}
function cloneRect(rect) {
    if (!rect) return {x:0,y:0,width:0,height:0};
    return {x:_number(rect.x,0),y:_number(rect.y,0),
        width:Math.max(0,_number(rect.width,0)),
        height:Math.max(0,_number(rect.height,0))};
}
function clonePlacement(placement) {
    if (!placement) return null;
    return {
        visible:placement.visible !== false,
        evicted:placement.evicted === true,
        along:_number(placement.along,0),
        inward:Math.max(0,_number(placement.inward,0)),
        span:Math.max(0,_number(placement.span,0)),
        depth:Math.max(0,_number(placement.depth,0)),
        shrunk:placement.shrunk === true,
        content:cloneRect(placement.content)
    };
}
function cloneRecord(record) {
    if (!record) return null;
    return {
        edge:String(record.edge ?? ""),
        along:_number(record.along,0),
        span:Math.max(0,_number(record.span,0)),
        depth:Math.max(0,_number(record.depth,0)),
        targetDepth:Math.max(0,_number(record.targetDepth,record.depth ?? 0)),
        progress:_number(record.progress,1),
        surface:cloneRect(record.surface),
        content:cloneRect(record.content)
    };
}
function mix(a,b,t) {
    return _number(a,0)+(_number(b,0)-_number(a,0))*t;
}
function interpolateRect(from,to,t) {
    return {
        x:mix(from?.x,to?.x,t), y:mix(from?.y,to?.y,t),
        width:Math.max(0,mix(from?.width,to?.width,t)),
        height:Math.max(0,mix(from?.height,to?.height,t))
    };
}
function interpolateRecord(from,to,progress) {
    if (!to) return cloneRecord(from);
    if (!from) return cloneRecord(to);
    var t=Math.max(0,Math.min(1,_number(progress,1)));
    var result=cloneRecord(to);
    result.progress=t;
    result.surface=interpolateRect(from.surface,to.surface,t);
    result.content=interpolateRect(from.content,to.content,t);
    // Keep semantic geometry consumers in lockstep with the visible envelope.
    // Geometry.panel() exposes depth as the *current* Edge-normal reach while
    // targetDepth remains the resting maximum. Leaving depth at the full value
    // made obstacle consumers reserve a fully-open popup for the entire tail.
    result.depth=Math.max(0,mix(from.depth,to.depth,t));
    // Tangent identity is always the final popup's own identity. Never
    // interpolate from another popup's along/span, which was the source of the
    // old Screen-Edge travel artifact.
    result.along=_number(to.along,0);
    result.span=Math.max(0,_number(to.span,0));
    return result;
}
function collapsedRecord(full,lower) {
    if (!full) return null;
    var result=cloneRecord(full);
    var surface=cloneRect(full.surface);
    var content=cloneRect(full.content);
    var edge=String(full.edge ?? "");
    var targetSurface=cloneRect(surface);
    var targetContent=cloneRect(content);

    if (lower?.surface) {
        var peer=cloneRect(lower.surface);
        if (edge==="top") {
            var bottom=peer.y+peer.height;
            targetSurface.height=Math.max(0,
                Math.min(surface.height,bottom-surface.y));
            targetContent.y=bottom;
            targetContent.height=0;
        } else if (edge==="bottom") {
            var top=peer.y;
            var endY=surface.y+surface.height;
            targetSurface.y=Math.max(surface.y,Math.min(endY,top));
            targetSurface.height=Math.max(0,endY-targetSurface.y);
            targetContent.y=top;
            targetContent.height=0;
        } else if (edge==="left") {
            var right=peer.x+peer.width;
            targetSurface.width=Math.max(0,
                Math.min(surface.width,right-surface.x));
            targetContent.x=right;
            targetContent.width=0;
        } else if (edge==="right") {
            var left=peer.x;
            var endX=surface.x+surface.width;
            targetSurface.x=Math.max(surface.x,Math.min(endX,left));
            targetSurface.width=Math.max(0,endX-targetSurface.x);
            targetContent.x=left;
            targetContent.width=0;
        }
    } else {
        // Lowest tier collapses only its workspace-facing depth. Keep the
        // Screen-Edge owner strip as the invisible/redundant origin so reveal
        // motion is strictly normal to the Edge and never grows tangentially.
        var ownerExtent=0;
        if (edge==="top" || edge==="bottom")
            ownerExtent=Math.max(0,surface.height-_number(full.depth,0));
        else
            ownerExtent=Math.max(0,surface.width-_number(full.depth,0));

        if (edge==="top") {
            targetSurface.height=ownerExtent;
            targetContent.y=surface.y+ownerExtent;
            targetContent.height=0;
        } else if (edge==="bottom") {
            targetSurface.y=surface.y+Math.max(0,surface.height-ownerExtent);
            targetSurface.height=ownerExtent;
            targetContent.y=targetSurface.y;
            targetContent.height=0;
        } else if (edge==="left") {
            targetSurface.width=ownerExtent;
            targetContent.x=surface.x+ownerExtent;
            targetContent.width=0;
        } else if (edge==="right") {
            targetSurface.x=surface.x+Math.max(0,surface.width-ownerExtent);
            targetSurface.width=ownerExtent;
            targetContent.x=targetSurface.x;
            targetContent.width=0;
        }
    }

    // Geometry.placedPanel() has one invariant on every Edge:
    // surfaceCross = ownerExtent + currentDepth. Reconstruct the collapsed
    // current depth from that invariant so obstacle/layout consumers see the
    // same Edge-normal reach as the rendered snapshot.
    var fullCross=(edge==="top" || edge==="bottom")
        ? surface.height : surface.width;
    var collapsedCross=(edge==="top" || edge==="bottom")
        ? targetSurface.height : targetSurface.width;
    var ownerExtent=Math.max(0,fullCross-_number(full.depth,0));
    result.depth=Math.max(0,collapsedCross-ownerExtent);
    result.progress=0;
    result.surface=targetSurface;
    result.content=targetContent;
    return result;
}
