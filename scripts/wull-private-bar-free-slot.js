// PRIVATE INERT RESEARCH ONLY: one-dimensional free Bar/Screen-Edge slot.
// This file is NOT imported by production. An eventual QML shadow may
// import it after explicit source/geometry review. Never mutate records.
//
// Layout source: actual AbyssBar.layoutRecords and active surface reservations,
// NOT raw pixels, old scale=1 body boxes, tray assumptions or physical borders.
// A fit is a geometry candidate, not a visual/pointer/fullscreen acceptance.
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
