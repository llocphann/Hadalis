// Responsive working space for mature Dashboard cards. This projection runs on
// saved-layout/viewport changes, never on pointer frames. It does not mutate the
// saved layout; an intentional edit persists its current coordinate space.
function bounded(value, fallback, low, high) {
    return Number.isFinite(Number(value)) ? Math.max(low,Math.min(high,Number(value))) : fallback;
}
function overlaps(a,b,gap) {
    return a.x < b.x+b.width+gap-.001 && b.x < a.x+a.width+gap-.001
        && a.y < b.y+b.height+gap-.001 && b.y < a.y+a.height+gap-.001;
}
function project(entries, viewportWidth, viewportHeight, minimums, gap, reference) {
    var width=Math.max(1,viewportWidth,bounded(reference?.width,0,0,16384));
    var height=Math.max(1,viewportHeight,bounded(reference?.height,0,0,16384));
    var visible=entries.filter(function(entry) { return entry.visible !== false; });
    // Keep the requested proportions while satisfying every card's minimum.
    // On narrow surfaces the working space scrolls instead of crushing cards.
    visible.forEach(function(entry) {
        var min=minimums[entry.id] || {width:200,height:80};
        width=Math.max(width,min.width/bounded(entry.w,.3,.05,1));
        height=Math.max(height,min.height/bounded(entry.h,.2,.05,1));
    });
    width=Math.ceil(width);height=Math.ceil(height);
    var initialHeight=height, rects={}, obstacles=[];
    visible.forEach(function(entry) {
        var min=minimums[entry.id] || {width:200,height:80};
        var w=Math.max(min.width,bounded(entry.w,.3,.05,1)*width);
        var h=Math.max(min.height,bounded(entry.h,.2,.05,1)*initialHeight);
        var desired={x:Math.min(width-w,bounded(entry.x,0,0,1)*width),
            y:Math.min(initialHeight-h,bounded(entry.y,0,0,1)*initialHeight),width:w,height:h};
        var fits=function(rect) { return rect.x>=0 && rect.y>=0 && rect.x+w<=width+.001 && rect.y+h<=height+.001
            && !obstacles.some(function(other) { return overlaps(rect,other,gap); }); };
        var best=fits(desired) ? desired : null, score=Infinity;
        if(!best) {
            var xs=[desired.x,0,width-w], ys=[desired.y,0,height-h];
            obstacles.forEach(function(other) {
                xs.push(other.x-w-gap,other.x+other.width+gap);
                ys.push(other.y-h-gap,other.y+other.height+gap);
            });
            xs.forEach(function(x) { ys.forEach(function(y) {
                var candidate={x:x,y:y,width:w,height:h};
                var distance=Math.pow(x-desired.x,2)+Math.pow(y-desired.y,2);
                if(distance<score && fits(candidate)) { best=candidate;score=distance; }
            }); });
        }
        if(!best) {
            // Even corrupt/overfull old layouts have a finite safe projection.
            // Append space; never shrink another card or publish an overlap.
            best={x:desired.x,y:height+gap,width:w,height:h};
            height=best.y+h;
        }
        rects[entry.id]=best;obstacles.push(best);
    });
    return {width:width,height:Math.ceil(height),rects:rects};
}
