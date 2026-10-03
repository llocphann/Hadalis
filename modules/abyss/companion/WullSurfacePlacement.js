// Production Wull placement against the REAL output-specific Abyss Bar layout.
// Pure, bounded 1-D interval solver; no compositor, mouse or paint side effects.
// When all nearby slots are occupied, caller MUST hide the companion instead
// of reverting to a physical-edge position over foreground Bar modules.
function finite(n) { return typeof n === "number" && Number.isFinite(n); }

function slot(options) {
    if (!options || typeof options !== "object")
        return {qualified:false, reason:"INVALID_INPUT"};
    const edge = options.edge;
    const validEdges = ["top","right","bottom","left"];
    if (!validEdges.includes(edge)
        || !finite(options.extent) || options.extent < 1
        || !finite(options.footprint) || options.footprint <= 0
        || !finite(options.desired)
        || !Array.isArray(options.records)
        || !Array.isArray(options.reservations)
        || options.records.length + options.reservations.length > 512)
        return {qualified:false, reason:"INVALID_INPUT"};
    const distance = options.clearance === undefined ? 18 : options.clearance;
    const side = options.sideGuard === undefined ? 16 : options.sideGuard;
    const first = options.cornerStart === undefined ? 0 : options.cornerStart;
    const last = options.cornerEnd === undefined ? 0 : options.cornerEnd;
    const maxShift = options.maxShift === undefined ? options.extent
        : options.maxShift;
    if (![distance,side,first,last,maxShift].every(finite)
        || distance < 0 || side < 0 || first < 0 || last < 0
        || maxShift < 0 || distance > options.extent
        || first > options.extent || last > options.extent
        || options.footprint > options.extent)
        return {qualified:false, reason:"INVALID_INPUT"};
    const half = options.footprint * 0.5;
    const minimum = first + half + side;
    const maximum = options.extent - last - half - side;
    if (minimum > maximum)
        return {qualified:false, reason:"INSUFFICIENT_EDGE"};
    const blockers = options.records.concat(options.reservations);
    let ranges = [[minimum,maximum]];
    let occupied = 0;
    for (const rec of blockers) {
        if (!rec || typeof rec !== "object"
            || !validEdges.includes(rec.edge)
            || !finite(rec.along) || !finite(rec.span)
            || rec.span < 0 || ![true,false,undefined].includes(rec.active))
            return {qualified:false, reason:"UNVERIFIED_RECORD"};
        if (rec.edge !== edge || rec.active === false || rec.span === 0)
            continue;
        occupied++;
        // Exclude every center whose footprint would overlap a reserved
        // module with less than the explicit requested clearance.
        const blockedFrom = rec.along - half - distance;
        const blockedTo = rec.along + rec.span + half + distance;
        if (!finite(blockedFrom) || !finite(blockedTo))
            return {qualified:false, reason:"UNVERIFIED_RECORD"};
        const next = [];
        for (const interval of ranges) {
            const lo = interval[0], hi = interval[1];
            if (blockedTo <= lo || blockedFrom >= hi) {
                next.push(interval);
                continue;
            }
            // At an EXACT gap equality the footprint is safely tangent.
            if (blockedFrom >= lo && blockedFrom <= hi)
                next.push([lo,blockedFrom]);
            if (blockedTo >= lo && blockedTo <= hi)
                next.push([blockedTo,hi]);
        }
        ranges = next;
        if (!ranges.length)
            break;
    }
    if (!ranges.length)
        return {qualified:false, reason:"NO_FREE_SEGMENT",
                occupiedOnEdge:occupied};
    const wanted = Math.max(minimum,Math.min(maximum,options.desired));
    let best = null;
    for (const interval of ranges) {
        const center = Math.max(interval[0],Math.min(interval[1],wanted));
        const shift = Math.abs(center - wanted);
        if (!best || shift < best.shift - 1e-8
            || (Math.abs(shift-best.shift) <= 1e-8
                && center < best.center))
            best = {center:center,shift:shift,interval:interval};
    }
    if (!best || best.shift > maxShift)
        return {qualified:false, reason:"NO_NEARBY_CLEARANCE",
                occupiedOnEdge:occupied};
    return {qualified:true, reason:"SOURCE_GEOMETRY_CANDIDATE",
            center:best.center, displacement:best.shift,
            footprint:options.footprint, occupiedOnEdge:occupied,
            freeInterval:best.interval.slice()};
}

// Walking stays in ONE verified free interval, including every intermediate
// position. Never interpolate across a bar module to reach another free slot.
function wander(placement, current, fraction, scale) {
    if (!placement || !placement.qualified || !Array.isArray(placement.freeInterval)
        || placement.freeInterval.length !== 2 || !finite(current)
        || !finite(fraction) || !finite(scale) || scale <= 0)
        return {qualified:false};
    const lo=placement.freeInterval[0], hi=placement.freeInterval[1];
    if (!finite(lo) || !finite(hi) || lo > hi || current < lo || current > hi)
        return {qualified:false};
    const limit=160*scale;
    let target=Math.max(current-limit,Math.min(current+limit,
        lo+(hi-lo)*Math.max(0,Math.min(1,fraction))));
    target=Math.max(lo,Math.min(hi,target));
    const distance=Math.abs(target-current);
    if (distance < 12*scale) return {qualified:false};
    return {qualified:true,center:target,direction:target>=current?1:-1,
        duration:Math.round(distance/(32*scale)*1000)};
}

function validRect(rect) {
    return rect && [rect.x,rect.y,rect.width,rect.height].every(finite)
        && rect.width>0 && rect.height>0;
}
function intersects(a,b,gap) {
    return a.x < b.x+b.width+gap && a.x+a.width+gap > b.x
        && a.y < b.y+b.height+gap && a.y+a.height+gap > b.y;
}

// Park beside a stable live Panel/Popup content rectangle. Keep the FULL host
// and pointer Region clear of its content and every other occupied rectangle.
// Candidate ranking depends on the source edge; failure hides, never overlaps.
function besideSurface(rect, edge, outputWidth, outputHeight, width, height, blockers) {
    if (!validRect(rect) || ![outputWidth,outputHeight,width,height].every(finite)
        || Math.min(outputWidth,outputHeight,width,height)<=0
        || !["top","right","bottom","left"].includes(edge)
        || !Array.isArray(blockers) || blockers.length>512
        || blockers.some(r=>!validRect(r))) return {qualified:false};
    const gap=12;
    const positions={
        top:{x:rect.x+(rect.width-width)/2,y:rect.y-height-gap,source:"bottom"},
        bottom:{x:rect.x+(rect.width-width)/2,y:rect.y+rect.height+gap,source:"top"},
        left:{x:rect.x-width-gap,y:rect.y+(rect.height-height)/2,source:"right"},
        right:{x:rect.x+rect.width+gap,y:rect.y+(rect.height-height)/2,source:"left"}
    };
    const order={top:["bottom","right","left","top"],bottom:["top","right","left","bottom"],
        left:["right","bottom","top","left"],right:["left","bottom","top","right"]}[edge];
    for (const side of order) {
        const p=positions[side];
        const candidate={x:p.x,y:p.y,width:width,height:height};
        if (p.x<8 || p.y<8 || p.x+width>outputWidth-8 || p.y+height>outputHeight-8)
            continue;
        if (intersects(candidate,rect,gap-.001) || blockers.some(r=>intersects(candidate,r,8)))
            continue;
        return {qualified:true,x:p.x,y:p.y,emergenceEdge:p.source};
    }
    return {qualified:false};
}
