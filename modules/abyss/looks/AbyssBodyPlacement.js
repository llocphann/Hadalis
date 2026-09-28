// Allocate content around its physical Edge anchor. The allocator never searches
// laterally for a different anchor: it keeps the requested anchor center, stacks
// peers inward, then shrinks/reflows only as far as the host's readable minimum.
// If even that cannot fit, the lower-priority body is temporarily evicted. Its
// host keeps the loaded draft and animates the previous geometry closed.
function _number(value, fallback) {
    var number = Number(value);
    return Number.isFinite(number) ? number : fallback;
}
function _steps(full, minimum) {
    full = Math.max(0, _number(full, 0));
    minimum = Math.max(0, Math.min(full, _number(minimum, full)));
    if (full <= 0) return [0];
    var values = [full, Math.max(minimum, full * .88),
        Math.max(minimum, full * .74), minimum];
    return values.filter(function(value, index, list) {
        return list.findIndex(function(other) { return Math.abs(other-value) < .5; }) === index;
    });
}
function _candidateSizes(fullSpan, fullDepth, minSpan, minDepth) {
    var spans = _steps(fullSpan, minSpan), depths = _steps(fullDepth, minDepth);
    var result = [];
    spans.forEach(function(span) {
        depths.forEach(function(depth) {
            result.push({span:span, depth:depth,
                cost:(fullSpan > 0 ? 1-span/fullSpan : 0)
                    +(fullDepth > 0 ? 1-depth/fullDepth : 0)});
        });
    });
    result.sort(function(a,b) {
        return a.cost-b.cost || (b.span*b.depth)-(a.span*a.depth);
    });
    return result;
}
function _contentRect(request, span, depth, inward, width, height, insets) {
    var record = request.record, edge = record.edge;
    var horizontal = edge === "top" || edge === "bottom";
    var reverse = edge === "bottom" || edge === "right";
    var fullContentSpan = horizontal ? record.content.width : record.content.height;
    var inferredPadding = Math.max(0, (record.span-fullContentSpan)/2);
    var padding = Math.max(0, _number(request.padding, inferredPadding));
    var alongPadding = Math.min(padding, span/2);
    var crossPadding = Math.min(padding, depth/2);
    var anchorCenter = record.along + record.span/2;
    var along = anchorCenter-span/2;
    var contentSpan = Math.max(0, span-2*alongPadding);
    var contentDepth = Math.max(0, depth-2*crossPadding);
    var x, y;
    if (horizontal) {
        x = along+alongPadding;
        y = edge === "top"
            ? insets.top+crossPadding+inward
            : height-insets.bottom-depth+crossPadding-inward;
        return {x:x,y:y,width:contentSpan,height:contentDepth};
    }
    x = edge === "left"
        ? insets.left+crossPadding+inward
        : width-insets.right-depth+crossPadding-inward;
    y = along+alongPadding;
    return {x:x,y:y,width:contentDepth,height:contentSpan};
}
function _within(rect, width, height, insets) {
    return rect.width > 0 && rect.height > 0
        && rect.x >= insets.left-.01 && rect.y >= insets.top-.01
        && rect.x+rect.width <= width-insets.right+.01
        && rect.y+rect.height <= height-insets.bottom+.01;
}
function _collides(rect, accepted, gap) {
    return accepted.some(function(other) {
        return rect.x < other.x+other.width+gap
            && rect.x+rect.width+gap > other.x
            && rect.y < other.y+other.height+gap
            && rect.y+rect.height+gap > other.y;
    });
}
function _tiers(request, span, depth, accepted, gap, width, height, insets) {
    var base = _contentRect(request,span,depth,0,width,height,insets);
    var edge = request.record.edge;
    var horizontal = edge === "top" || edge === "bottom";
    var reverse = edge === "bottom" || edge === "right";
    var tiers = [0];
    accepted.forEach(function(other) {
        var baseAlongStart = horizontal ? base.x : base.y;
        var baseAlongEnd = baseAlongStart+(horizontal ? base.width : base.height);
        var otherAlongStart = horizontal ? other.x : other.y;
        var otherAlongEnd = otherAlongStart+(horizontal ? other.width : other.height);
        if (baseAlongStart >= otherAlongEnd+gap || baseAlongEnd+gap <= otherAlongStart)
            return;
        var baseCrossStart = horizontal ? base.y : base.x;
        var baseCrossEnd = baseCrossStart+(horizontal ? base.height : base.width);
        var otherCrossStart = horizontal ? other.y : other.x;
        var otherCrossEnd = otherCrossStart+(horizontal ? other.height : other.width);
        var tier = reverse
            ? baseCrossEnd-otherCrossStart+gap
            : otherCrossEnd-baseCrossStart+gap;
        if (tier > 0) tiers.push(tier);
    });
    return tiers.filter(function(value,index,list) {
        return list.findIndex(function(other) { return Math.abs(other-value) < .5; }) === index;
    }).sort(function(a,b) { return a-b; });
}
function _anchorCenter(request) {
    return _number(request?.record?.along,0)
        + _number(request?.record?.span,0)/2;
}
function _samePyramidAnchor(a,b) {
    return a?.stackPolicy === "pyramid"
        && b?.stackPolicy === "pyramid"
        && a?.record?.edge === b?.record?.edge
        && Math.abs(_anchorCenter(a)-_anchorCenter(b)) <= 2;
}
function _requestedArea(request) {
    var record=request?.record;
    if (!record) return 0;
    return Math.max(0,_number(record.span,0))
        * Math.max(0,_number(record.targetDepth,record.depth || 0));
}
function arrange(requests, width, height, insets, gap) {
    gap = gap === undefined ? 24 : Math.max(0, gap);
    var result = {}, accepted = [];
    var ordered = Array.from(requests || []).filter(function(request) {
        return request && request.open && request.record;
    });
    ordered.sort(function(a,b) {
        // Pyramid is a resting-layout policy only: at one physical anchor the
        // largest popup owns the Edge tier and smaller peers stack inward.
        if (_samePyramidAnchor(a,b)) {
            var areaDelta=_requestedArea(b)-_requestedArea(a);
            if (Math.abs(areaDelta)>.5) return areaDelta;
        }
        return (b.priority || 0)-(a.priority || 0)
            || (b.order || 0)-(a.order || 0)
            || String(a.id).localeCompare(String(b.id));
    });
    ordered.forEach(function(request) {
        var record = request.record;
        var fullSpan = Math.max(0,_number(record.span,0));
        var fullDepth = Math.max(0,_number(record.targetDepth,record.depth || 0));
        var minSpan = Math.max(0,Math.min(fullSpan,_number(request.minSpan,fullSpan)));
        var minDepth = Math.max(0,Math.min(fullDepth,_number(request.minDepth,fullDepth)));
        var placement = null;
        var sizes = _candidateSizes(fullSpan,fullDepth,minSpan,minDepth);
        for (var s=0; s<sizes.length && !placement; s++) {
            var size = sizes[s];
            var tiers = _tiers(request,size.span,size.depth,accepted,gap,width,height,insets);
            for (var t=0; t<tiers.length && !placement; t++) {
                var rect = _contentRect(request,size.span,size.depth,tiers[t],
                    width,height,insets);
                if (!_within(rect,width,height,insets) || _collides(rect,accepted,gap))
                    continue;
                var anchorCenter = record.along+record.span/2;
                placement = {
                    visible:true,
                    evicted:false,
                    along:anchorCenter-size.span/2,
                    inward:tiers[t],
                    span:size.span,
                    depth:size.depth,
                    shrunk:size.span < fullSpan-.5 || size.depth < fullDepth-.5,
                    content:rect
                };
                accepted.push(rect);
            }
        }
        result[request.id] = placement || {
            visible:false,
            evicted:true,
            along:record.along,
            inward:0,
            span:fullSpan,
            depth:fullDepth,
            shrunk:false
        };
    });
    return result;
}
