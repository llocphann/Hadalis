// Project requested cards into the finite Dashboard body, once per saved
// layout/viewport change. Pointer previews never re-pack neighbours.
function bounded(value, fallback, low, high) {
    return Number.isFinite(Number(value)) ? Math.max(low,Math.min(high,Number(value))) : fallback;
}
function overlaps(a,b,gap) {
    return a.x < b.x+b.width+gap-.001 && b.x < a.x+a.width+gap-.001
        && a.y < b.y+b.height+gap-.001 && b.y < a.y+a.height+gap-.001;
}
function freeRect(desired, minimum, width, height, obstacles, gap, shrink) {
    if (minimum.width > width || minimum.height > height) return null;
    var widths=shrink ? [desired.width,minimum.width] : [desired.width];
    var heights=shrink ? [desired.height,minimum.height] : [desired.height];
    var best=null, score=Infinity;
    widths.forEach(function(w) { heights.forEach(function(h) {
        var xs=[desired.x,0,width-w], ys=[desired.y,0,height-h];
        obstacles.forEach(function(other) {
            xs.push(other.x-w-gap,other.x+other.width+gap);
            ys.push(other.y-h-gap,other.y+other.height+gap);
        });
        xs.forEach(function(x) { ys.forEach(function(y) {
            var r={x:x,y:y,width:w,height:h};
            if(x<0 || y<0 || x+w>width+.001 || y+h>height+.001
                    || obstacles.some(function(other) { return overlaps(r,other,gap); })) return;
            // Prefer retaining size, then the nearest safe location.
            var cost=Math.pow(x-desired.x,2)+Math.pow(y-desired.y,2)
                +4*(Math.pow(w-desired.width,2)+Math.pow(h-desired.height,2));
            if(cost<score) { best=r;score=cost; }
        }); });
    }); });
    return best;
}
function project(entries, viewportWidth, viewportHeight, minimums, gap, reference) {
    // Old persisted scroll-workspace references must never enlarge this body.
    var width=Math.max(1,viewportWidth), height=Math.max(1,viewportHeight);
    var rects={}, obstacles=[], overflow=[];
    entries.filter(function(entry) { return entry.visible !== false; }).forEach(function(entry) {
        var min=minimums[entry.id] || {width:200,height:80};
        var w=Math.min(width,Math.max(min.width,bounded(entry.w,.3,.05,1)*width));
        var h=Math.min(height,Math.max(min.height,bounded(entry.h,.2,.05,1)*height));
        var desired={x:Math.min(width-w,bounded(entry.x,0,0,1)*width),
            y:Math.min(height-h,bounded(entry.y,0,0,1)*height),width:w,height:h};
        var best=freeRect(desired,min,width,height,obstacles,gap,true);
        if(!best) { overflow.push(entry.id);return; }
        rects[entry.id]=best;obstacles.push(best);
    });
    return {width:width,height:height,rects:rects,overflow:overflow};
}
