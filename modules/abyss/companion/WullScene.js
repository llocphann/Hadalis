.pragma library
.import "WullSurfacePlacement.js" as Slots

// Output-local geometry only. Decisions run on semantic events, never frames.
var edges = ["top", "right", "bottom", "left"]
function finite(value) { return typeof value === "number" && Number.isFinite(value) }
function clamp(value, minimum, maximum) { return Math.max(minimum, Math.min(maximum, value)) }
function valid(scene) {
    return !!scene && [scene.width,scene.height,scene.hostWidth,scene.hostHeight,scene.scale].every(finite)
        && scene.hostWidth > 0 && scene.hostHeight > 0 && scene.scale > 0
        && scene.width >= scene.hostWidth+4 && scene.height >= scene.hostHeight+4
        && scene.insets && edges.every(e=>finite(scene.insets[e]) && scene.insets[e]>=0)
        && scene.insets.left+scene.insets.right<scene.width
        && scene.insets.top+scene.insets.bottom<scene.height
        && Array.isArray(scene.records) && scene.records.length <= 256
        && scene.records.every(r=>r && edges.includes(r.edge) && finite(r.along) && finite(r.span) && r.span>=0)
        && Array.isArray(scene.blockers) && scene.blockers.length <= 128
        && scene.blockers.every(Slots.validRect)
        && Array.isArray(scene.surfaces) && scene.surfaces.length <= 16
        && scene.surfaces.every(s=>s && Slots.validRect(s.rect) && edges.includes(s.edge))
}
function rect(scene, point) {
    return {x:point.x,y:point.y,width:scene.hostWidth,height:scene.hostHeight}
}
function clearAt(scene, point) {
    return valid(scene) && !!point && finite(point.x) && finite(point.y)
        && point.x>=2 && point.y>=2 && point.x+scene.hostWidth<=scene.width-2
        && point.y+scene.hostHeight<=scene.height-2
        && !scene.blockers.some(b=>Slots.intersects(rect(scene,point),b,1.5))
}
function supportAt(scene, point) {
    if (!clearAt(scene,point)) return null
    const bottom=point.y+scene.hostHeight, tolerance=3*scene.scale
    const floor=scene.height-scene.insets.bottom
    if (Math.abs(bottom-floor)<=tolerance)
        return {key:"bottom",y:floor,from:scene.insets.left+2,to:scene.width-scene.insets.right-2}
    for (const surface of scene.surfaces) {
        const r=surface.rect
        if (Math.abs(bottom-r.y)<=tolerance && point.x>=r.x && point.x+scene.hostWidth<=r.x+r.width)
            return {key:surface.key,y:r.y,from:r.x,to:r.x+r.width}
    }
    // A module's upper rim is also a real horizontal surface, if fully clear.
    for (let i=0;i<scene.blockers.length;i++) {
        const r=scene.blockers[i]
        if (Math.abs(bottom-r.y)<=tolerance && point.x>=r.x && point.x+scene.hostWidth<=r.x+r.width)
            return {key:"rim"+i,y:r.y,from:r.x,to:r.x+r.width}
    }
    return null
}
function annotate(scene, point, edge, kind, key) {
    const support=supportAt(scene,point)
    return {qualified:true,x:point.x,y:point.y,edge:edge,kind:kind,key:key,
        grounded:!!support,support:support}
}
function edgePoint(scene, edge, fraction) {
    if (!valid(scene) || !edges.includes(edge) || !finite(fraction)) return {qualified:false}
    const horizontal=edge==="top" || edge==="bottom"
    const span=horizontal ? scene.hostWidth : scene.hostHeight
    const extent=horizontal ? scene.width : scene.height
    const normal=edge==="top" ? Math.max(2,scene.insets.top)
        : edge==="bottom" ? Math.min(scene.height-scene.hostHeight-2,scene.height-scene.insets.bottom-scene.hostHeight)
        : edge==="left" ? Math.max(2,scene.insets.left)
        : Math.min(scene.width-scene.hostWidth-2,scene.width-scene.insets.right-scene.hostWidth)
    const depth=horizontal ? scene.hostHeight : scene.hostWidth
    const reservations=[]
    for (const b of scene.blockers) {
        const start=horizontal ? b.y : b.x, end=start+(horizontal ? b.height : b.width)
        if (start < normal+depth+2 && end+2 > normal)
            reservations.push({edge:edge,along:horizontal ? b.x : b.y,span:horizontal ? b.width : b.height})
    }
    const result=Slots.slot({edge:edge,extent:extent,footprint:span,
        desired:extent*clamp(fraction,.08,.92),clearance:3,sideGuard:8,
        cornerStart:(horizontal ? scene.insets.left : scene.insets.top)+12,
        cornerEnd:(horizontal ? scene.insets.right : scene.insets.bottom)+12,
        maxShift:extent,records:scene.records,reservations:reservations})
    if (!result.qualified) return result
    const point=horizontal ? {x:result.center-span/2,y:normal} : {x:normal,y:result.center-span/2}
    if (!clearAt(scene,point)) return {qualified:false}
    const placement=annotate(scene,point,edge,"edge",edge)
    placement.freeInterval=result.freeInterval
    return placement
}
function surfacePoints(scene) {
    if (!valid(scene)) return []
    const result=[], w=scene.hostWidth, h=scene.hostHeight, gap=2*scene.scale
    for (const surface of scene.surfaces) {
        const r=surface.rect
        const points={
            right:{x:r.x+r.width+gap,y:r.y+(r.height-h)/2,edge:"left"},
            left:{x:r.x-w-gap,y:r.y+(r.height-h)/2,edge:"right"},
            top:{x:r.x+(r.width-w)/2,y:r.y-h-gap,edge:"bottom"},
            bottom:{x:r.x+(r.width-w)/2,y:r.y+r.height+gap,edge:"top"}
        }
        const order=surface.edge==="left" ? ["right","top","bottom","left"]
            : surface.edge==="right" ? ["left","top","bottom","right"] : ["top","right","left","bottom"]
        for (const side of order) {
            const point=points[side]
            if (clearAt(scene,point)) result.push(annotate(scene,point,point.edge,"surface",surface.key))
        }
    }
    return result
}
// All four edges remain eligible. A visible Sidebar/Popup has a 35% initial
// visit chance, not a preference that pins Wull to that surface.
function appearance(scene, surfaceRoll, edgeRoll, alongRoll) {
    if (!valid(scene) || ![surfaceRoll,edgeRoll,alongRoll].every(finite)) return {qualified:false}
    const surfaces=surfacePoints(scene)
    if (surfaces.length && surfaceRoll<.35)
        return surfaces[Math.min(surfaces.length-1,Math.floor(clamp(edgeRoll,0,.999999)*surfaces.length))]
    const first=Math.floor(clamp(edgeRoll,0,.999999)*4)
    for (let i=0;i<4;i++) {
        const point=edgePoint(scene,edges[(first+i)%4],alongRoll)
        if (point.qualified) return point
    }
    return {qualified:false}
}

// Exact swept full-host rectangle vs expanded obstacle, including endpoints.
function clearSegment(scene, from, to) {
    if (!clearAt(scene,from) || !clearAt(scene,to)) return false
    const dx=to.x-from.x, dy=to.y-from.y
    for (const b of scene.blockers) {
        const lo=[b.x-scene.hostWidth-1.5,b.y-scene.hostHeight-1.5]
        const hi=[b.x+b.width+1.5,b.y+b.height+1.5]
        let enter=0, exit=1, hit=true
        for (let axis=0;axis<2;axis++) {
            const start=axis ? from.y : from.x, delta=axis ? dy : dx
            if (Math.abs(delta)<1e-9) {
                if (start<=lo[axis] || start>=hi[axis]) {hit=false;break}
            } else {
                const a=(lo[axis]-start)/delta, z=(hi[axis]-start)/delta
                enter=Math.max(enter,Math.min(a,z)); exit=Math.min(exit,Math.max(a,z))
                if (enter>=exit-1e-9) {hit=false;break}
            }
        }
        if (hit && enter<exit-1e-9) return false
    }
    return true
}
function distance(a,b) { return Math.hypot(a.x-b.x,a.y-b.y) }
function path(scene, from, to) {
    if (!valid(scene) || !clearAt(scene,from) || !clearAt(scene,to)) return {qualified:false}
    const a=supportAt(scene,from), b=supportAt(scene,to)
    const walking=!!a && !!b && a.key===b.key && Math.abs(from.y-to.y)<.1
        && Math.min(from.x,to.x)>=a.from && Math.max(from.x,to.x)+scene.hostWidth<=a.to
    if (clearSegment(scene,from,to))
        return {qualified:true,mode:walking ? "walk" : "fly",points:[to],distance:distance(from,to)}
    // Bounded visibility graph. Every segment checks ALL obstacles; only node
    // construction is capped. Complex/blocked scenes fail closed.
    const nodes=[from,to], gap=2.5
    for (const obstacle of scene.blockers.slice(0,24)) {
        for (const x of [obstacle.x-scene.hostWidth-gap,obstacle.x+obstacle.width+gap])
            for (const y of [obstacle.y-scene.hostHeight-gap,obstacle.y+obstacle.height+gap]) {
                const point={x:x,y:y}
                if (clearAt(scene,point)) nodes.push(point)
            }
    }
    const costs=nodes.map(()=>Infinity), previous=nodes.map(()=>-1), seen=nodes.map(()=>false)
    costs[0]=0
    for (let iteration=0;iteration<nodes.length;iteration++) {
        let index=-1
        for (let i=0;i<nodes.length;i++) if (!seen[i] && (index<0 || costs[i]<costs[index])) index=i
        if (index<0 || !finite(costs[index])) break
        if (index===1) {
            const points=[]
            for (let i=1;i!==0;i=previous[i]) points.unshift(nodes[i])
            return {qualified:true,mode:"fly",points:points,distance:costs[1]}
        }
        seen[index]=true
        for (let i=0;i<nodes.length;i++) {
            if (seen[i] || !clearSegment(scene,nodes[index],nodes[i])) continue
            const cost=costs[index]+distance(nodes[index],nodes[i])
            if (cost<costs[i]) {costs[i]=cost;previous[i]=index}
        }
    }
    return {qualified:false}
}
function nearestWater(scene, point) {
    if (!valid(scene) || !clearAt(scene,point)) return {qualified:false}
    let best=null
    for (const edge of edges) {
        const horizontal=edge==="top" || edge==="bottom"
        const fraction=(horizontal ? point.x+scene.hostWidth/2 : point.y+scene.hostHeight/2)/(horizontal ? scene.width : scene.height)
        const water=edgePoint(scene,edge,fraction)
        if (!water.qualified) continue
        const route=path(scene,point,water)
        if (route.qualified && (!best || route.distance<best.route.distance)) best={qualified:true,placement:water,route:route}
    }
    return best || {qualified:false}
}
function drop(scene, x, y, previous) {
    if (!valid(scene) || !finite(x) || !finite(y)) return {qualified:false}
    const point={x:clamp(x,2,scene.width-scene.hostWidth-2),y:clamp(y,2,scene.height-scene.hostHeight-2)}
    if (!clearAt(scene,point)) return clearAt(scene,previous) ? annotate(scene,previous,"top","drop","drop") : {qualified:false}
    // Snap to a nearby upper rim, never invent a surface under an airborne drop.
    const floors=[{y:scene.height-scene.insets.bottom,from:scene.insets.left,to:scene.width-scene.insets.right}]
    for (const s of scene.surfaces) floors.push({y:s.rect.y,from:s.rect.x,to:s.rect.x+s.rect.width})
    for (const floor of floors) {
        const candidate={x:point.x,y:floor.y-scene.hostHeight-2*scene.scale}
        if (Math.abs(candidate.y-point.y)<12*scene.scale && point.x>=floor.from
            && point.x+scene.hostWidth<=floor.to && clearAt(scene,candidate)) {point.y=candidate.y;break}
    }
    return annotate(scene,point,"top","drop","drop")
}
