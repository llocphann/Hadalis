// Elastic Fill: hover-owned vacancy borrowing for related Abyss bodies.
//
// This is deliberately separate from AbyssBodyPlacement. The base allocator
// remains the sole authority for requested geometry, readable minima, activation
// order, stacking, collision resolution and eviction. Elastic Fill receives the
// resulting composition and may temporarily enlarge only the currently hovered
// member into the vertical vacancy already created by its related peer.
//
// It never persists geometry, never grows a lone surface, never expands through
// the physical Screen Edge and never overlaps another visible body's content.
function _elasticNumber(value, fallback) {
    var n=Number(value);
    return Number.isFinite(n) ? n : fallback;
}

function _elasticRect(rect) {
    return {
        x:_elasticNumber(rect?.x,0),
        y:_elasticNumber(rect?.y,0),
        width:Math.max(0,_elasticNumber(rect?.width,0)),
        height:Math.max(0,_elasticNumber(rect?.height,0))
    };
}

function _elasticArea(rect) {
    return Math.max(0,rect.width)*Math.max(0,rect.height);
}
function _elasticPanelRect(member) {
    var request=member?.request ?? {};
    var placement=member?.placement ?? {};
    var content=_elasticRect(placement.content);
    var edge=String(request?.record?.edge ?? "");
    var horizontal=edge==="top" || edge==="bottom";
    var padding=Math.max(0,_elasticNumber(request?.padding,0));
    var alongPadding=Math.min(padding,
        Math.max(0,_elasticNumber(placement.span,0))/2);
    var crossPadding=Math.min(padding,
        Math.max(0,_elasticNumber(placement.depth,0))/2);
    return {
        x:content.x-(horizontal ? alongPadding : crossPadding),
        y:content.y-(horizontal ? crossPadding : alongPadding),
        width:content.width+2*(horizontal ? alongPadding : crossPadding),
        height:content.height+2*(horizontal ? crossPadding : alongPadding)
    };
}
function _elasticDirections(owner,members) {
    // The examples this mechanism serves are orthogonal perimeter pairs:
    // Sidebar + a corner popup. Preserve their allocator positions and grow
    // only vertically toward the peer's occupied band. This makes the visible
    // result follow the real composition instead of a hard-coded popup role.
    var ownerPanel=_elasticPanelRect(owner);
    var ownerCenter=ownerPanel.y+ownerPanel.height/2;
    var peers=members.filter(function(member) {
        return member!==owner;
    });
    if (!peers.length) return [];

    var peerTop=Infinity,peerBottom=-Infinity;
    var weightedCenter=0,totalArea=0;
    peers.forEach(function(member) {
        var rect=_elasticPanelRect(member);
        var area=Math.max(1,_elasticArea(rect));
        peerTop=Math.min(peerTop,rect.y);
        peerBottom=Math.max(peerBottom,rect.y+rect.height);
        weightedCenter+=(rect.y+rect.height/2)*area;
        totalArea+=area;
    });

    var peerCenter=totalArea>0
        ? weightedCenter/totalArea : (peerTop+peerBottom)/2;
    if (peerCenter>ownerCenter+.5) return ["bottom"];
    if (peerCenter<ownerCenter-.5) return ["top"];

    var upward=Math.max(0,ownerPanel.y-peerTop);
    var downward=Math.max(0,
        peerBottom-(ownerPanel.y+ownerPanel.height));
    if (downward>upward+.5) return ["bottom"];
    if (upward>downward+.5) return ["top"];
    return [];
}
function _elasticEnvelope(members) {
    var left=Infinity,top=Infinity,right=-Infinity,bottom=-Infinity;
    for (var i=0;i<members.length;i++) {
        var rect=_elasticPanelRect(members[i]);
        left=Math.min(left,rect.x);
        top=Math.min(top,rect.y);
        right=Math.max(right,rect.x+rect.width);
        bottom=Math.max(bottom,rect.y+rect.height);
    }
    return {
        x:left,
        y:top,
        width:Math.max(0,right-left),
        height:Math.max(0,bottom-top)
    };
}

function _elasticDirectionAllowed(edge,direction) {
    // Tangent growth may use either direction. Cross-axis growth is allowed
    // only workspace-inward, never outward through the owning physical Edge.
    if (edge==="top") return direction!=="top";
    if (edge==="bottom") return direction!=="bottom";
    if (edge==="left") return direction!=="left";
    if (edge==="right") return direction!=="right";
    return false;
}

function _elasticMaximumDelta(rect,direction,envelope) {
    if (direction==="left")
        return Math.max(0,rect.x-envelope.x);
    if (direction==="right")
        return Math.max(0,
            envelope.x+envelope.width-(rect.x+rect.width));
    if (direction==="top")
        return Math.max(0,rect.y-envelope.y);
    return Math.max(0,
        envelope.y+envelope.height-(rect.y+rect.height));
}

function _elasticGrownRect(rect,direction,delta) {
    var result=_elasticRect(rect);
    if (direction==="left") {
        result.x-=delta;
        result.width+=delta;
    } else if (direction==="right") {
        result.width+=delta;
    } else if (direction==="top") {
        result.y-=delta;
        result.height+=delta;
    } else if (direction==="bottom") {
        result.height+=delta;
    }
    return result;
}

function _elasticCollides(rect,blockers,gap) {
    return blockers.some(function(other) {
        return rect.x<other.x+other.width+gap
            && rect.x+rect.width+gap>other.x
            && rect.y<other.y+other.height+gap
            && rect.y+rect.height+gap>other.y;
    });
}

function _elasticSafeDelta(rect,direction,maximum,blockers,gap) {
    if (!(maximum>0)) return 0;
    if (!_elasticCollides(
            _elasticGrownRect(rect,direction,maximum),blockers,gap))
        return maximum;

    // Expansion is monotonic: each larger trial contains the previous one.
    // A fixed iteration count makes the collision-limited result deterministic.
    var low=0,high=maximum;
    for (var i=0;i<14;i++) {
        var middle=(low+high)/2;
        if (_elasticCollides(
                _elasticGrownRect(rect,direction,middle),blockers,gap))
            high=middle;
        else
            low=middle;
    }
    return low;
}

function _elasticExpandedPlacement(request,base,rect,direction,delta) {
    var edge=String(request?.record?.edge ?? "");
    var result=Object.assign({},base,{
        content:rect,
        elasticFilled:true,
        elasticDirection:direction
    });

    // Placement fields describe the padded panel. Growing one content side by
    // N pixels grows the corresponding panel dimension by N while preserving
    // padding and the allocator's existing inward tier.
    if (direction==="left") {
        if (edge==="right")
            result.depth=base.depth+delta;
        else {
            result.along=base.along-delta;
            result.span=base.span+delta;
        }
    } else if (direction==="right") {
        if (edge==="left")
            result.depth=base.depth+delta;
        else
            result.span=base.span+delta;
    } else if (direction==="top") {
        if (edge==="bottom")
            result.depth=base.depth+delta;
        else {
            result.along=base.along-delta;
            result.span=base.span+delta;
        }
    } else if (direction==="bottom") {
        if (edge==="top")
            result.depth=base.depth+delta;
        else
            result.span=base.span+delta;
    }
    return result;
}

function _elasticOwner(members) {
    var hovered=members.filter(function(member) {
        return member.request?.elasticFillHovered === true;
    });
    if (!hovered.length) return null;

    hovered.sort(function(a,b) {
        return _elasticNumber(b.request?.elasticFillOrder,0)
                - _elasticNumber(a.request?.elasticFillOrder,0)
            || _elasticNumber(b.request?.order,0)
                - _elasticNumber(a.request?.order,0)
            || String(a.request?.id ?? "").localeCompare(
                String(b.request?.id ?? ""));
    });
    return hovered[0];
}

function resolve(requests,placements,gap) {
    if (!placements || !requests || !requests.length)
        return placements;

    gap=Math.max(0,_elasticNumber(gap,24));
    var groups={};
    for (var i=0;i<requests.length;i++) {
        var request=requests[i];
        var group=String(request?.elasticFillGroup ?? "");
        var placement=placements[request?.id];
        if (!group || !(request?.open ?? false)
                || !placement || placement.visible===false
                || !placement.content)
            continue;
        if (!groups[group]) groups[group]=[];
        groups[group].push({
            request:request,
            placement:placement
        });
    }

    // Resolve newest hover first across groups. This matters only during a
    // transient multi-hover overlap, but keeps collision ownership deterministic.
    var transactions=[];
    for (var key in groups) {
        var members=groups[key];
        if (members.length<2) continue;
        var owner=_elasticOwner(members);
        if (!owner) continue;
        transactions.push({
            key:key,
            members:members,
            owner:owner,
            order:_elasticNumber(owner.request?.elasticFillOrder,0),
            fallbackOrder:_elasticNumber(owner.request?.order,0)
        });
    }
    if (!transactions.length)
        return placements;

    transactions.sort(function(a,b) {
        return b.order-a.order
            || b.fallbackOrder-a.fallbackOrder
            || String(a.key).localeCompare(String(b.key));
    });

    var result=placements;
    var changed=false;
    for (var t=0;t<transactions.length;t++) {
        var transaction=transactions[t];
        var owner=transaction.owner;
        var base=owner.placement;
        var original=_elasticRect(base.content);
        var originalPanel=_elasticPanelRect(owner);
        var envelope=_elasticEnvelope(transaction.members);
        var directions=_elasticDirections(owner,transaction.members);
        var blockers=[];
        var source=changed ? result : placements;

        for (var id in source) {
            if (String(id)===String(owner.request.id))
                continue;
            var other=source[id];
            if (other?.visible!==false && other?.content)
                blockers.push(_elasticRect(other.content));
        }

        var best=null;
        for (var d=0;d<directions.length;d++) {
            var direction=directions[d];
            if (!_elasticDirectionAllowed(
                    String(owner.request?.record?.edge ?? ""),direction))
                continue;

            var maximum=_elasticMaximumDelta(
                originalPanel,direction,envelope);
            // Avoid tiny hover-driven breathing that does not materially expose
            // more content. Twelve logical pixels remains below stock padding.
            if (maximum<12) continue;

            var delta=_elasticSafeDelta(
                original,direction,maximum,blockers,gap);
            if (delta<12) continue;

            var grown=_elasticGrownRect(
                original,direction,delta);
            var gain=_elasticArea(grown)-_elasticArea(original);
            if (!best || gain>best.gain+0.5)
                best={
                    direction:direction,
                    delta:delta,
                    rect:grown,
                    gain:gain
                };
        }

        if (!best)
            continue;
        if (!changed) {
            result=Object.assign({},placements);
            changed=true;
        }
        result[owner.request.id]=_elasticExpandedPlacement(
            owner.request,base,best.rect,best.direction,best.delta);
    }

    // Returning the original object when inactive is intentional: losing hover
    // restores exact allocator truth without a second synthetic base snapshot.
    return result;
}
