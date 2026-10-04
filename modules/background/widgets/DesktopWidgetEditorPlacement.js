// Output-local resting geometry only. Candidate dimensions do not depend on
// the selected edge or toolbar children, so orientation cannot feed back into
// the next placement decision. A widget is never moved to make room.
function choose(work, widgets, selectedKey) {
    const left = Number(work?.left) || 0, top = Number(work?.top) || 0;
    const right = Math.max(left, Number(work?.right) || left);
    const bottom = Math.max(top, Number(work?.bottom) || top);
    const gap = 12, padding = 6;
    const horizontalSpan = Math.max(0, Math.min(920, right-left-24));
    const verticalSpan = Math.max(0, Math.min(650, bottom-top-24));
    const rects = [];
    for (const item of widgets ?? []) {
        const x=Number(item?.x), y=Number(item?.y);
        const width=Number(item?.width), height=Number(item?.height);
        if (![x,y,width,height].every(Number.isFinite) || width<=0 || height<=0) continue;
        rects.push({x:x-gap,y:y-gap,width:width+gap*2,height:height+gap*2,
            weight:item.key === selectedKey ? 4 : 1});
    }
    let best = null, bestScore = Infinity;
    for (const edge of ["bottom","top","left","right"]) {
        const horizontal = edge === "top" || edge === "bottom";
        const span = horizontal ? horizontalSpan : verticalSpan;
        const depth = Math.min(64, horizontal ? bottom-top : right-left);
        const first = (horizontal ? left : top)+padding;
        const last = Math.max(first,(horizontal ? right : bottom)-padding-span);
        const center = (first+last)/2;
        const positions = [center,first,last];
        for (const rect of rects) {
            const start = horizontal ? rect.x : rect.y;
            const extent = horizontal ? rect.width : rect.height;
            positions.push(Math.max(first,Math.min(last,start-span)),
                Math.max(first,Math.min(last,start+extent)));
        }
        for (const along of positions) {
            const x = horizontal ? along : edge === "left" ? left : right-depth;
            const y = horizontal ? edge === "top" ? top : bottom-depth : along;
            const width = horizontal ? span : depth, height = horizontal ? depth : span;
            let score = Math.abs(along-center)*0.00001;
            for (const rect of rects)
                score += Math.max(0,Math.min(x+width,rect.x+rect.width)-Math.max(x,rect.x))
                    * Math.max(0,Math.min(y+height,rect.y+rect.height)-Math.max(y,rect.y))*rect.weight;
            if (score < bestScore) {
                bestScore = score;
                best = {edge:edge,along:along,span:span,depth:depth,x:x,y:y,width:width,height:height};
            }
        }
    }
    return best;
}
