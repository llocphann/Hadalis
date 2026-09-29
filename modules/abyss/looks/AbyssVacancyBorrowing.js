// Temporary vacancy borrowing for semantically related Abyss surfaces.
// The base allocator remains authoritative; this post-pass may only enlarge one
// semantically paired member into currently free output space. Without hover the
// most recently activated eligible member borrows; final-body hover overrides it.
var _vacancyPartners = {
    featureSidebar: "quickNotes",
    quickNotes: "featureSidebar",
    systemSidebar: "notificationCenter",
    notificationCenter: "systemSidebar"
};

function _vacancyNumber(value, fallback) {
    var number = Number(value);
    return Number.isFinite(number) ? number : fallback;
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
function _vacancyPadding(request, width, height, insets) {
    var edge=String(request?.record?.edge ?? "");
    var horizontal=_vacancyHorizontal(edge);
    var first=horizontal ? _vacancyNumber(insets?.left,0)
        : _vacancyNumber(insets?.top,0);
    var last=(horizontal ? width-_vacancyNumber(insets?.right,0)
        : height-_vacancyNumber(insets?.bottom,0));
    return Math.max(0,Math.min(_vacancyNumber(request?.padding,0),
        Math.max(0,last-first)/8));
}
function _vacancyPanelRect(request, placement, width, height, insets) {
    var edge=String(request?.record?.edge ?? "");
    var horizontal=_vacancyHorizontal(edge);
    var along=_vacancyNumber(placement?.along,0);
    var span=Math.max(0,_vacancyNumber(placement?.span,0));
    var depth=Math.max(0,_vacancyNumber(placement?.depth,0));
    var inward=Math.max(0,_vacancyNumber(placement?.inward,0));
    if (horizontal) {
        return {
            x:along,
            y:edge === "top"
                ? _vacancyNumber(insets?.top,0)+inward
                : height-_vacancyNumber(insets?.bottom,0)-depth-inward,
            width:span,
            height:depth
        };
    }
    return {
        x:edge === "left"
            ? _vacancyNumber(insets?.left,0)+inward
            : width-_vacancyNumber(insets?.right,0)-depth-inward,
        y:along,
        width:depth,
        height:span
    };
}
function _vacancySafeBounds(request, width, height, insets) {
    var edge=String(request?.record?.edge ?? "");
    var horizontal=_vacancyHorizontal(edge);
    var padding=_vacancyPadding(request,width,height,insets);
    return {
        left:_vacancyNumber(insets?.left,0)+(horizontal ? padding : 0),
        top:_vacancyNumber(insets?.top,0)+(horizontal ? 0 : padding),
        right:width-_vacancyNumber(insets?.right,0)-(horizontal ? padding : 0),
        bottom:height-_vacancyNumber(insets?.bottom,0)-(horizontal ? 0 : padding)
    };
}
function _vacancyCenter(rect, axis) {
    return axis === "x" ? rect.x+rect.width/2 : rect.y+rect.height/2;
}
function _vacancyDirectionAllowed(edge, direction) {
    if (edge === "top" && direction === "top") return false;
    if (edge === "bottom" && direction === "bottom") return false;
    if (edge === "left" && direction === "left") return false;
    if (edge === "right" && direction === "right") return false;
    return true;
}
function _vacancyTowardPeer(owner, peer, direction) {
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
function _vacancySafeExtent(panel, bounds, direction) {
    if (direction === "top") return Math.max(0,panel.y-bounds.top);
    if (direction === "bottom") return Math.max(0,bounds.bottom-(panel.y+panel.height));
    if (direction === "left") return Math.max(0,panel.x-bounds.left);
    return Math.max(0,bounds.right-(panel.x+panel.width));
}
function _vacancyProjectionOverlaps(a, b, direction, gap) {
    if (direction === "top" || direction === "bottom")
        return a.x < b.x+b.width+gap && a.x+a.width+gap > b.x;
    return a.y < b.y+b.height+gap && a.y+a.height+gap > b.y;
}
function _vacancyBlockerExtent(content, blocker, direction, gap) {
    if (!_vacancyProjectionOverlaps(content,blocker,direction,gap))
        return Infinity;
    if (direction === "top") {
        var blockerBottom=blocker.y+blocker.height;
        return blockerBottom <= content.y+.01
            ? Math.max(0,content.y-blockerBottom-gap) : Infinity;
    }
    if (direction === "bottom") {
        var contentBottom=content.y+content.height;
        return blocker.y >= contentBottom-.01
            ? Math.max(0,blocker.y-contentBottom-gap) : Infinity;
    }
    if (direction === "left") {
        var blockerRight=blocker.x+blocker.width;
        return blockerRight <= content.x+.01
            ? Math.max(0,content.x-blockerRight-gap) : Infinity;
    }
    var contentRight=content.x+content.width;
    return blocker.x >= contentRight-.01
        ? Math.max(0,blocker.x-contentRight-gap) : Infinity;
}
function _vacancyGrow(rect, direction, delta) {
    var result=_vacancyRect(rect);
    if (direction === "top") { result.y-=delta; result.height+=delta; }
    else if (direction === "bottom") result.height+=delta;
    else if (direction === "left") { result.x-=delta; result.width+=delta; }
    else result.width+=delta;
    return result;
}
function _vacancyCollides(rect, other, gap) {
    return rect.x < other.x+other.width+gap
        && rect.x+rect.width+gap > other.x
        && rect.y < other.y+other.height+gap
        && rect.y+rect.height+gap > other.y;
}
function _vacancyExpandedPlacement(request, base, content, direction, delta) {
    var edge=String(request?.record?.edge ?? "");
    var horizontal=_vacancyHorizontal(edge);
    var result=Object.assign({},base,{
        content:content,
        vacancyBorrowed:true,
        vacancyDirection:direction,
        vacancyDelta:delta
    });
    if (horizontal) {
        if (direction === "left") {
            result.along=base.along-delta;
            result.span=base.span+delta;
        } else if (direction === "right") {
            result.span=base.span+delta;
        } else {
            result.depth=base.depth+delta;
        }
    } else {
        if (direction === "top") {
            result.along=base.along-delta;
            result.span=base.span+delta;
        } else if (direction === "bottom") {
            result.span=base.span+delta;
        } else {
            result.depth=base.depth+delta;
        }
    }
    return result;
}
function _vacancyMemberForRole(role, metadata, requestById, placements) {
    var candidates=(metadata || []).filter(function(item) {
        var request=requestById[String(item?.id ?? "")];
        var placement=placements?.[String(item?.id ?? "")];
        return String(item?.role ?? "") === role
            && request?.open === true
            && placement && placement.visible !== false && placement.content;
    });
    candidates.sort(function(a,b) {
        var ar=requestById[String(a.id)] || {};
        var br=requestById[String(b.id)] || {};
        return _vacancyNumber(br.order,0)-_vacancyNumber(ar.order,0)
            || String(a.id).localeCompare(String(b.id));
    });
    if (!candidates.length) return null;
    var meta=candidates[0], id=String(meta.id);
    return {id:id,meta:meta,request:requestById[id],placement:placements[id]};
}
function _vacancyBestCandidate(owner, peer, placements, width, height, insets, gap) {
    var panel=_vacancyPanelRect(owner.request,owner.placement,width,height,insets);
    var peerPanel=_vacancyPanelRect(peer.request,peer.placement,width,height,insets);
    var content=_vacancyRect(owner.placement.content);
    var bounds=_vacancySafeBounds(owner.request,width,height,insets);
    var edge=String(owner.request?.record?.edge ?? "");
    var directions=["top","bottom","left","right"];
    var best=null;
    for (var i=0;i<directions.length;i++) {
        var direction=directions[i];
        if (!_vacancyDirectionAllowed(edge,direction)) continue;
        var maximum=Math.min(
            _vacancyTowardPeer(panel,peerPanel,direction),
            _vacancySafeExtent(panel,bounds,direction));
        if (maximum < .5) continue;
        for (var id in placements) {
            if (String(id) === String(owner.id)) continue;
            var placement=placements[id];
            if (!placement || placement.visible === false || !placement.content) continue;
            maximum=Math.min(maximum,_vacancyBlockerExtent(
                content,_vacancyRect(placement.content),direction,gap));
            if (maximum < .5) break;
        }
        if (maximum < .5) continue;
        var candidateContent=_vacancyGrow(content,direction,maximum);
        var collision=false;
        for (var blockerId in placements) {
            if (String(blockerId) === String(owner.id)) continue;
            var blockerPlacement=placements[blockerId];
            if (!blockerPlacement || blockerPlacement.visible === false
                    || !blockerPlacement.content) continue;
            if (_vacancyCollides(candidateContent,
                    _vacancyRect(blockerPlacement.content),gap-.01)) {
                collision=true;
                break;
            }
        }
        if (collision) continue;
        var gain=maximum*((direction === "top" || direction === "bottom")
            ? content.width : content.height);
        if (!best || gain > best.gain+.01)
            best={direction:direction,delta:maximum,content:candidateContent,gain:gain};
    }
    return best;
}

function resolve(requests, metadata, placements, width, height, insets, gap) {
    if (!placements || !requests || !requests.length || !metadata || !metadata.length)
        return placements;
    width=Math.max(0,_vacancyNumber(width,0));
    height=Math.max(0,_vacancyNumber(height,0));
    if (width <= 0 || height <= 0) return placements;
    gap=gap === undefined ? 24 : Math.max(0,_vacancyNumber(gap,24));

    var requestById={};
    (requests || []).forEach(function(request) {
        if (request?.id !== undefined && request?.id !== null)
            requestById[String(request.id)]=request;
    });

    // Build geometry-eligible choices for both members of each semantic pair.
    // Automatic ownership follows activation order, so the surface the user
    // just opened receives available space without requiring a pointer hover.
    var transactions=[];
    ["featureSidebar","systemSidebar"].forEach(function(role) {
        var peerRole=_vacancyPartners[role];
        var sidebar=_vacancyMemberForRole(role,metadata,requestById,placements);
        var popup=_vacancyMemberForRole(peerRole,metadata,requestById,placements);
        if (!sidebar || !popup) return;
        var pairOrder=Math.max(
            _vacancyNumber(sidebar.request?.order,0),
            _vacancyNumber(popup.request?.order,0));
        [
            {owner:sidebar,peer:popup},
            {owner:popup,peer:sidebar}
        ].forEach(function(choice) {
            var candidate=_vacancyBestCandidate(choice.owner,choice.peer,
                placements,width,height,insets,gap);
            if (!candidate) return;
            transactions.push({
                pairRole:role,
                owner:choice.owner,
                peer:choice.peer,
                candidate:candidate,
                hovered:choice.owner.meta?.hovered === true,
                hoverOrder:_vacancyNumber(choice.owner.meta?.hoverOrder,0),
                requestOrder:_vacancyNumber(choice.owner.request?.order,0),
                pairOrder:pairOrder
            });
        });
    });
    if (!transactions.length) return placements;

    var hoveredTransactions=transactions.filter(function(transaction) {
        return transaction.hovered;
    });
    if (hoveredTransactions.length) {
        // A real final-body hover is a temporary explicit override. Geometry
        // eligibility is already known, so an impossible hover cannot suppress
        // another pair's valid automatic borrower.
        transactions=hoveredTransactions;
        transactions.sort(function(a,b) {
            return b.hoverOrder-a.hoverOrder
                || b.requestOrder-a.requestOrder
                || String(a.owner.id).localeCompare(String(b.owner.id));
        });
    } else {
        // No hover: the newest geometry-eligible member in each pair owns the
        // vacancy. This matches the visible user action: opening Notification
        // Center after Controls expands Notification Center immediately; opening
        // a sidebar later reverses ownership without needing hover.
        var automaticByPair={};
        transactions.forEach(function(transaction) {
            var current=automaticByPair[transaction.pairRole];
            if (!current
                    || transaction.requestOrder > current.requestOrder
                    || (transaction.requestOrder === current.requestOrder
                        && transaction.candidate.gain > current.candidate.gain+.01)
                    || (transaction.requestOrder === current.requestOrder
                        && Math.abs(transaction.candidate.gain-current.candidate.gain) <= .01
                        && String(transaction.owner.id)
                            .localeCompare(String(current.owner.id)) < 0))
                automaticByPair[transaction.pairRole]=transaction;
        });
        transactions=Object.keys(automaticByPair)
            .map(function(role) { return automaticByPair[role]; });
        transactions.sort(function(a,b) {
            return b.pairOrder-a.pairOrder
                || b.requestOrder-a.requestOrder
                || String(a.owner.id).localeCompare(String(b.owner.id));
        });
    }

    // One output owns one temporary borrower at a time. Automatic expansion and
    // hover override therefore never make multiple semantic surfaces swell.
    var transaction=transactions[0];
    var candidate=transaction.candidate;
    var result=Object.assign({},placements);
    result[transaction.owner.id]=_vacancyExpandedPlacement(
        transaction.owner.request,transaction.owner.placement,
        candidate.content,candidate.direction,candidate.delta);
    return result;
}
