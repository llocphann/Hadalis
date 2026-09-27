// Allocate content, not the joined liquid silhouette. Newer bodies keep their
// anchor; older bodies step inward before trying free space along their Edge.
// Requests never depend on animated geometry, so a reveal cannot repack peers.
function arrange(requests, width, height, insets, gap) {
    gap = gap === undefined ? 24 : Math.max(0, gap);
    var result = {}, accepted = [];
    var ordered = requests.filter(function(r) { return r && r.open && r.record; }).slice();
    ordered.sort(function(a,b) { return (b.priority || 0)-(a.priority || 0)
        || (b.order || 0)-(a.order || 0) || a.id.localeCompare(b.id); });
    ordered.forEach(function(request) {
        var base = request.record.content, edge = request.record.edge;
        var horizontal = edge === "top" || edge === "bottom";
        var reverse = edge === "bottom" || edge === "right";
        var along = horizontal ? base.x : base.y;
        var span = horizontal ? base.width : base.height;
        var depth = horizontal ? base.height : base.width;
        var positions = [along], tiers = [0];
        accepted.forEach(function(other) {
            var start = horizontal ? other.x : other.y;
            var end = start + (horizontal ? other.width : other.height);
            positions.push(start-span-gap, end+gap);
            var crossStart = horizontal ? other.y : other.x;
            var crossEnd = crossStart+(horizontal ? other.height : other.width);
            var baseCross = horizontal ? base.y : base.x;
            tiers.push(Math.max(0, reverse ? baseCross+depth-crossStart+gap : crossEnd-baseCross+gap));
        });
        positions = positions.filter(function(v,i,list) { return list.indexOf(v) === i; });
        // Keep the anchor first, then search the nearest lateral openings.
        positions = [along].concat(positions.filter(function(v) { return v !== along; })
            .sort(function(a,b) { return Math.abs(a-along)-Math.abs(b-along) || a-b; }));
        tiers = tiers.filter(function(v,i,list) { return list.indexOf(v) === i; }).sort(function(a,b) { return a-b; });
        var placement = null;
        for (var p=0;p<positions.length && !placement;p++) {
            for (var t=0;t<tiers.length && !placement;t++) {
                var cross = (horizontal ? base.y : base.x)+(reverse ? -1 : 1)*tiers[t];
                var rect = horizontal ? {x:positions[p],y:cross,width:span,height:depth}
                    : {x:cross,y:positions[p],width:depth,height:span};
                if (span <= 0 || depth <= 0 || rect.x < insets.left || rect.y < insets.top
                        || rect.x+rect.width > width-insets.right || rect.y+rect.height > height-insets.bottom) continue;
                if (accepted.some(function(other) { return rect.x < other.x+other.width+gap
                    && rect.x+rect.width+gap > other.x && rect.y < other.y+other.height+gap
                    && rect.y+rect.height+gap > other.y; })) continue;
                placement = {visible:true, along:request.record.along+positions[p]-along, inward:tiers[t], content:rect};
                accepted.push(rect);
            }
        }
        result[request.id] = placement || {visible:false,along:request.record.along,inward:0};
    });
    return result;
}
