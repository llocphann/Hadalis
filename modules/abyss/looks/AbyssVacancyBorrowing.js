// Semantic vacancy borrowing for paired Abyss surfaces.
// The base allocator remains authoritative; this post-pass may only enlarge
// already-visible content into geometry proven free on this output.
var _vacancyPairs = [
    {role:"featureSidebar", peer:"quickNotes", automatic:"featureSidebar"},
    {role:"systemSidebar", peer:"notificationCenter", automatic:"notificationCenter"}
];

function _vacancyNumber(value, fallback) {
    var n=Number(value);
    return Number.isFinite(n) ? n : fallback;
}
function _vacancyRect(value) {
    return {
        x:_vacancyNumber(value?.x,0),
        y:_vacancyNumber(value?.y,0),
        width:Math.max(0,_vacancyNumber(value?.width,0)),
        height:Math.max(0,_vacancyNumber(value?.height,0))
    };
}
function _vacancyHorizontal(edge) {
    return edge === "top" || edge === "bottom";
}
function _vacancyPadding(request,width,height,insets) {
    var edge=String(request?.record?.edge ?? "");
    var h=_vacancyHorizontal(edge);
    var first=h ? _vacancyNumber(insets?.left,0) : _vacancyNumber(insets?.top,0);
    var last=h ? width-_vacancyNumber(insets?.right,0)
        : height-_vacancyNumber(insets?.bottom,0);
    return Math.max(0,Math.min(_vacancyNumber(request?.padding,0),
        Math.max(0,last-first)/8));
}
function _vacancyPanelRect(request,placement,width,height,insets) {
    var edge=String(request?.record?.edge ?? "");
    var h=_vacancyHorizontal(edge);
    var along=_vacancyNumber(placement?.along,0);
    var span=Math.max(0,_vacancyNumber(placement?.span,0));
    var depth=Math.max(0,_vacancyNumber(placement?.depth,0));
    var inward=Math.max(0,_vacancyNumber(placement?.inward,0));
    if (h) {
        return {x:along,
            y:edge === "top" ? _vacancyNumber(insets?.top,0)+inward
                : height-_vacancyNumber(insets?.bottom,0)-depth-inward,
            width:span,height:depth};
    }
    return {
        x:edge === "left" ? _vacancyNumber(insets?.left,0)+inward
            : width-_vacancyNumber(insets?.right,0)-depth-inward,
        y:along,width:depth,height:span
    };
}
function _vacancySafeBounds(request,width,height,insets) {
    var edge=String(request?.record?.edge ?? "");
    var h=_vacancyHorizontal(edge);
    var p=_vacancyPadding(request,width,height,insets);
    return {
        left:_vacancyNumber(insets?.left,0)+(h ? p : 0),
        top:_vacancyNumber(insets?.top,0)+(h ? 0 : p),
        right:width-_vacancyNumber(insets?.right,0)-(h ? p : 0),
        bottom:height-_vacancyNumber(insets?.bottom,0)-(h ? 0 : p)
    };
}
function _vacancyCenter(rect,axis) {
    return axis === "x" ? rect.x+rect.width/2 : rect.y+rect.height/2;
}
function _vacancyDirectionAllowed(edge,direction) {
    if (edge === "top" && direction === "top") return false;
    if (edge === "bottom" && direction === "bottom") return false;
    if (edge === "left" && direction === "left") return false;
    if (edge === "right" && direction === "right") return false;
    return true;
}
function _vacancyTowardPeer(owner,peer,direction) {
    if (direction === "top") {
        if (_vacancyCenter(peer,"y") >= _vacancyCenter(owner,"y")-.01) return 0;
        return Math.max(0,owner.y-peer.y);
    }
    if (direction === "bottom") {
        if (_vacancyCenter(peer,"y") <= _vacancyCenter(owner,"y")+.01) return 0;
        return Math.max(0,peer.y+peer.height-(owner.y+owner.height));
    }
    if (direction === "left") {
        if (_vacancyCenter(peer,"x") >= _vacancyCenter(owner,"x")-.01) return 0;
        return Math.max(0,owner.x-peer.x);
    }
    if (_vacancyCenter(peer,"x") <= _vacancyCenter(owner,"x")+.01) return 0;
    return Math.max(0,peer.x+peer.width-(owner.x+owner.width));
}
function _vacancySafeExtent(panel,bounds,direction) {
    if (direction === "top") return Math.max(0,panel.y-bounds.top);
    if (direction === "bottom") return Math.max(0,bounds.bottom-(panel.y+panel.height));
    if (direction === "left") return Math.max(0,panel.x-bounds.left);
    return Math.max(0,bounds.right-(panel.x+panel.width));
}
function _vacancyProjectionOverlaps(a,b,direction,gap) {
    if (direction === "top" || direction === "bottom")
        return a.x < b.x+b.width+gap && a.x+a.width+gap > b.x;
    return a.y < b.y+b.height+gap && a.y+a.height+gap > b.y;
}
function _vacancyBlockerExtent(content,blocker,direction,gap) {
    if (!_vacancyProjectionOverlaps(content,blocker,direction,gap)) return Infinity;
    if (direction === "top") {
        var bb=blocker.y+blocker.height;
        return bb <= content.y+.01 ? Math.max(0,content.y-bb-gap) : Infinity;
    }
    if (direction === "bottom") {
        var cb=content.y+content.height;
        return blocker.y >= cb-.01 ? Math.max(0,blocker.y-cb-gap) : Infinity;
    }
    if (direction === "left") {
        var br=blocker.x+blocker.width;
        return br <= content.x+.01 ? Math.max(0,content.x-br-gap) : Infinity;
    }
    var cr=content.x+content.width;
    return blocker.x >= cr-.01 ? Math.max(0,blocker.x-cr-gap) : Infinity;
}
function _vacancyGrow(rect,direction,delta) {
    var r=_vacancyRect(rect);
    if (direction === "top") { r.y-=delta; r.height+=delta; }
    else if (direction === "bottom") r.height+=delta;
    else if (direction === "left") { r.x-=delta; r.width+=delta; }
    else r.width+=delta;
    return r;
}
function _vacancyCollides(a,b,gap) {
    return a.x < b.x+b.width+gap && a.x+a.width+gap > b.x
        && a.y < b.y+b.height+gap && a.y+a.height+gap > b.y;
}
function _vacancyExpandedPlacement(request,base,content,direction,delta) {
    var edge=String(request?.record?.edge ?? "");
    var h=_vacancyHorizontal(edge);
    var out=Object.assign({},base,{
        content:content,vacancyBorrowed:true,
        vacancyDirection:direction,vacancyDelta:delta
    });
    if (h) {
        if (direction === "left") { out.along=base.along-delta; out.span=base.span+delta; }
        else if (direction === "right") out.span=base.span+delta;
        else out.depth=base.depth+delta;
    } else {
        if (direction === "top") { out.along=base.along-delta; out.span=base.span+delta; }
        else if (direction === "bottom") out.span=base.span+delta;
        else out.depth=base.depth+delta;
    }
    return out;
}
function _vacancyMemberForRole(role,metadata,requestById,placements) {
    var list=(metadata || []).filter(function(item) {
        var id=String(item?.id ?? "");
        var req=requestById[id], p=placements?.[id];
        return String(item?.role ?? "") === role
            && req?.open === true && p && p.visible !== false && p.content;
    });
    list.sort(function(a,b) {
        var ar=requestById[String(a.id)] || {}, br=requestById[String(b.id)] || {};
        return _vacancyNumber(br.order,0)-_vacancyNumber(ar.order,0)
            || String(a.id).localeCompare(String(b.id));
    });
    if (!list.length) return null;
    var meta=list[0], id=String(meta.id);
    return {id:id,role:role,meta:meta,request:requestById[id],placement:placements[id]};
}
function _vacancyBestCandidate(owner,peer,placements,width,height,insets,gap) {
    var panel=_vacancyPanelRect(owner.request,owner.placement,width,height,insets);
    var peerPanel=_vacancyPanelRect(peer.request,peer.placement,width,height,insets);
    var content=_vacancyRect(owner.placement.content);
    var bounds=_vacancySafeBounds(owner.request,width,height,insets);
    var edge=String(owner.request?.record?.edge ?? "");
    var dirs=["top","bottom","left","right"], best=null;
    for (var i=0;i<dirs.length;i++) {
        var dir=dirs[i];
        if (!_vacancyDirectionAllowed(edge,dir)) continue;
        var max=Math.min(_vacancyTowardPeer(panel,peerPanel,dir),
            _vacancySafeExtent(panel,bounds,dir));
        if (max < .5) continue;
        for (var id in placements) {
            if (String(id) === String(owner.id)) continue;
            var p=placements[id];
            if (!p || p.visible === false || !p.content) continue;
            max=Math.min(max,_vacancyBlockerExtent(content,_vacancyRect(p.content),dir,gap));
            if (max < .5) break;
        }
        if (max < .5) continue;
        var grown=_vacancyGrow(content,dir,max), collision=false;
        for (var blockerId in placements) {
            if (String(blockerId) === String(owner.id)) continue;
            var bp=placements[blockerId];
            if (!bp || bp.visible === false || !bp.content) continue;
            if (_vacancyCollides(grown,_vacancyRect(bp.content),gap-.01)) {
                collision=true; break;
            }
        }
        if (collision) continue;
        var gain=max*((dir === "top" || dir === "bottom") ? content.width : content.height);
        if (!best || gain > best.gain+.01)
            best={direction:dir,delta:max,content:grown,gain:gain};
    }
    return best;
}

function resolve(requests,metadata,placements,width,height,insets,gap) {
    if (!placements || !requests?.length || !metadata?.length) return placements;
    width=Math.max(0,_vacancyNumber(width,0));
    height=Math.max(0,_vacancyNumber(height,0));
    if (width <= 0 || height <= 0) return placements;
    gap=gap === undefined ? 24 : Math.max(0,_vacancyNumber(gap,24));

    var requestById={};
    requests.forEach(function(req) {
        if (req?.id !== undefined && req?.id !== null)
            requestById[String(req.id)]=req;
    });

    var plans=[];
    _vacancyPairs.forEach(function(pair) {
        var first=_vacancyMemberForRole(pair.role,metadata,requestById,placements);
        var second=_vacancyMemberForRole(pair.peer,metadata,requestById,placements);
        if (!first || !second) return;

        var choices=[first,second].map(function(owner) {
            var peer=owner.id === first.id ? second : first;
            var candidate=_vacancyBestCandidate(owner,peer,placements,width,height,insets,gap);
            return candidate ? {
                owner:owner,peer:peer,candidate:candidate,
                hovered:owner.meta?.hovered === true,
                hoverOrder:_vacancyNumber(owner.meta?.hoverOrder,0),
                requestOrder:_vacancyNumber(owner.request?.order,0)
            } : null;
        }).filter(function(x) { return x !== null; });
        if (!choices.length) return;

        var hovered=choices.filter(function(x) { return x.hovered; });
        hovered.sort(function(a,b) {
            return b.hoverOrder-a.hoverOrder || b.requestOrder-a.requestOrder
                || String(a.owner.id).localeCompare(String(b.owner.id));
        });

        var ordered=[];
        if (hovered.length) {
            ordered=hovered.slice();
        } else {
            var preferred=choices.find(function(x) { return x.owner.role === pair.automatic; });
            if (preferred) ordered.push(preferred);
        }
        choices.slice().sort(function(a,b) {
            return b.requestOrder-a.requestOrder || b.candidate.gain-a.candidate.gain
                || String(a.owner.id).localeCompare(String(b.owner.id));
        }).forEach(function(x) {
            if (ordered.indexOf(x) < 0) ordered.push(x);
        });

        plans.push({
            pairRole:pair.role,choices:ordered,
            hasHover:hovered.length > 0,
            hoverOrder:hovered.length ? hovered[0].hoverOrder : 0,
            pairOrder:Math.max(_vacancyNumber(first.request?.order,0),
                _vacancyNumber(second.request?.order,0))
        });
    });
    if (!plans.length) return placements;

    // Priority matters only when expanded rectangles compete. Independent pairs
    // remain expanded together.
    plans.sort(function(a,b) {
        return Number(b.hasHover)-Number(a.hasHover)
            || b.hoverOrder-a.hoverOrder || b.pairOrder-a.pairOrder
            || String(a.pairRole).localeCompare(String(b.pairRole));
    });

    var accepted=[], result=null;
    plans.forEach(function(plan) {
        var chosen=null;
        for (var i=0;i<plan.choices.length;i++) {
            var candidate=plan.choices[i];
            var conflict=accepted.some(function(other) {
                return _vacancyCollides(candidate.candidate.content,
                    other.candidate.content,gap-.01);
            });
            if (!conflict) { chosen=candidate; break; }
        }
        if (!chosen) return;
        if (!result) result=Object.assign({},placements);
        result[chosen.owner.id]=_vacancyExpandedPlacement(
            chosen.owner.request,chosen.owner.placement,
            chosen.candidate.content,chosen.candidate.direction,chosen.candidate.delta);
        accepted.push(chosen);
    });
    return result || placements;
}
