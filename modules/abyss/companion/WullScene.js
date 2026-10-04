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
        && Array.isArray(scene.surfaces) && scene.surfaces.length <= 40
        && scene.surfaces.every(s=>s && Slots.validRect(s.rect) && edges.includes(s.edge))
}
// Every registered Abyss body participates: Dock, Settings, Sidebars, ordinary
// and StyledPopup/IPC hosts, OSD, notifications and future body-host surfaces.
// Use the actual painted silhouette, never the inset content/input rectangle.
function fromParticipants(base, participants, modules) {
    const records=Array.isArray(modules) ? modules : [], blockers=[], surfaces=[]
    for (const record of records) {
        const horizontal=record.edge==="top" || record.edge==="bottom"
        const depth=Number(base.insets?.[record.edge])
        // Hidden Bar modules retain a zero span in the live layout. They have
        // no painted area; keep their records validated, without an empty
        // collision rectangle invalidating every possible Wull placement.
        if (record.span===0 || depth===0) continue
        blockers.push(horizontal
            ? {x:record.along,y:record.edge==="top" ? 0 : base.height-depth,width:record.span,height:depth}
            : {x:record.edge==="left" ? 0 : base.width-depth,y:record.along,width:depth,height:record.span})
    }
    const keys=Object.keys(participants ?? {})
    // Capacity overflow fails closed rather than dropping a visible obstacle.
    if (keys.length>40) return Object.assign({},base,{records:records,blockers:[],surfaces:null})
    for (const key of keys) {
        const participant=participants[key], geometry=participant?.geometry, r=geometry?.surface
        if (!geometry) continue
        if (!r || ![r.x,r.y,r.width,r.height].every(finite)
                || r.width<0 || r.height<0 || !edges.includes(geometry.edge))
            return Object.assign({},base,{records:records,blockers:null,surfaces:[]})
        // Match the shared field's visible-record rule, including custom IPC
        // participants without a body-host progress property.
        if (r.width<=0 || r.height<=0) continue
        blockers.push({x:r.x,y:r.y,width:r.width,height:r.height,walkable:false})
        if (edges.includes(geometry.edge))
            surfaces.push({key:key,edge:geometry.edge,rect:blockers[blockers.length-1],
                radius:Math.max(0,Number(base.rimRadius) || 0),settled:participant.surfaceSettled===true})
    }
    return Object.assign({},base,{records:records,blockers:blockers,surfaces:surfaces})
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
function normal(edge) {
    return {nx:edge==="left" ? 1 : edge==="right" ? -1 : 0,
        ny:edge==="top" ? 1 : edge==="bottom" ? -1 : 0}
}
function supportAt(scene, point, preferredEdge) {
    if (!clearAt(scene,point)) return null
    const tolerance=Math.max(2.1,3*scene.scale)
    const order=edges.includes(preferredEdge) ? [preferredEdge].concat(edges.filter(e=>e!==preferredEdge)) : ["bottom","top","left","right"]
    function match(key,edge,coordinate,from,to) {
        const horizontal=edge==="top" || edge==="bottom"
        const boundary=edge==="bottom" ? point.y+scene.hostHeight : edge==="top" ? point.y
            : edge==="left" ? point.x : point.x+scene.hostWidth
        const start=horizontal ? point.x : point.y, extent=horizontal ? scene.hostWidth : scene.hostHeight
        if (Math.abs(boundary-coordinate)>tolerance || start<from || start+extent>to) return null
        const n=normal(edge)
        return {key:key,edge:edge,nx:n.nx,ny:n.ny,axis:horizontal ? "x" : "y",
            coordinate:coordinate,y:horizontal ? coordinate : undefined,from:from,to:to}
    }
    for (const edge of order) {
        const horizontal=edge==="top" || edge==="bottom"
        const coordinate=edge==="top" ? scene.insets.top : edge==="bottom" ? scene.height-scene.insets.bottom
            : edge==="left" ? scene.insets.left : scene.width-scene.insets.right
        const found=match(edge,edge,coordinate,horizontal ? scene.insets.left+2 : scene.insets.top+2,
            horizontal ? scene.width-scene.insets.right-2 : scene.height-scene.insets.bottom-2)
        if (found) return found
        for (const surface of scene.surfaces) {
            const r=surface.rect, margin=Math.min(Number(surface.radius)||0,(horizontal ? r.width : r.height)/2)
            const side=edge==="bottom" ? r.y : edge==="top" ? r.y+r.height : edge==="left" ? r.x+r.width : r.x
            const start=horizontal ? r.x : r.y, extent=horizontal ? r.width : r.height
            const rim=match(surface.key,edge,side,start+margin,start+extent-margin)
            if (rim) return rim
        }
    }
    for (let i=0;i<scene.blockers.length;i++) {
        const r=scene.blockers[i]
        if (r.walkable===false) continue
        const rim=match("rim"+i,"bottom",r.y,r.x,r.x+r.width)
        if (rim) return rim
    }
    return null
}
function annotate(scene, point, edge, kind, key) {
    const support=supportAt(scene,point,edge)
    const placement={qualified:true,x:point.x,y:point.y,edge:support?.edge ?? edge,kind:kind,key:key,
        grounded:!!support,support:support}
    placement.contact=waterContact(scene,placement,point)
    return placement
}
function waterContact(scene, placement, point) {
    if (!valid(scene) || !placement || !point || !clearAt(scene,point)) return null
    const key=placement.kind==="surface" ? placement.key : supportAt(scene,point)?.key
    const surface=scene.surfaces.find(s=>s.key===key)
    const support=supportAt(scene,point,placement.edge)
    const edge=surface ? (support?.edge ?? placement.edge) : support?.edge ?? (placement.kind==="edge" ? placement.edge : "")
    if (!edges.includes(edge)) return null
    const horizontal=edge==="top" || edge==="bottom"
    const r=surface?.rect
    const x=horizontal ? point.x+scene.hostWidth/2
        : r ? edge==="left" ? r.x+r.width : r.x : edge==="left" ? scene.insets.left : scene.width-scene.insets.right
    const y=!horizontal ? point.y+scene.hostHeight/2
        : r ? edge==="bottom" ? r.y : r.y+r.height : edge==="top" ? scene.insets.top : scene.height-scene.insets.bottom
    const boundary=horizontal ? edge==="bottom" ? point.y+scene.hostHeight : point.y
        : edge==="left" ? point.x : point.x+scene.hostWidth
    if (Math.abs(boundary-(horizontal ? y : x))>5*scene.scale) return null
    return {x:x,y:y,nx:edge==="left" ? 1 : edge==="right" ? -1 : 0,
        ny:edge==="top" ? 1 : edge==="bottom" ? -1 : 0,scale:scene.scale,
        span:(horizontal ? scene.hostWidth : scene.hostHeight)*.7,
        sourceEdge:surface?.edge ?? edge,
        sourceAlong:(surface?.edge ?? edge)==="top" || (surface?.edge ?? edge)==="bottom" ? x : y,
        key:surface?.key ?? edge}
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
    const result=[], w=scene.hostWidth, h=scene.hostHeight, gap=Math.max(2,2*scene.scale)
    for (const surface of scene.surfaces) {
        if (surface.settled===false) continue
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
// All four edges remain eligible. Any settled Abyss body has a 35% initial
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
        // Preserve all four geometry reads before either axis test. These
        // bounds are private scalar values; two staging arrays per obstacle
        // are unnecessary even when an early axis exit is taken.
        const loX=b.x-scene.hostWidth-1.5, loY=b.y-scene.hostHeight-1.5
        const hiX=b.x+b.width+1.5, hiY=b.y+b.height+1.5
        let enter=0, exit=1, hit=true
        for (let axis=0;axis<2;axis++) {
            const start=axis ? from.y : from.x, delta=axis ? dy : dx
            if (Math.abs(delta)<1e-9) {
                if (start<=(axis ? loY : loX) || start>=(axis ? hiY : hiX)) {hit=false;break}
            } else {
                const a=((axis ? loY : loX)-start)/delta, z=((axis ? hiY : hiX)-start)/delta
                enter=Math.max(enter,Math.min(a,z)); exit=Math.min(exit,Math.max(a,z))
                if (enter>=exit-1e-9) {hit=false;break}
            }
        }
        if (hit && enter<exit-1e-9) return false
    }
    return true
}
function distance(a,b) { return Math.hypot(a.x-b.x,a.y-b.y) }
// Conservative full swept envelope, not sparse sampling of a curved path.
// Every authored height lies in [0,1]; the entire host stays inside this box.
function clearArc(scene, from, to, height, nx = 0, ny = -1) {
    if (!finite(height) || height<0 || !clearSegment(scene,from,to)) return false
    if (!finite(nx) || !finite(ny) || Math.abs(Math.hypot(nx,ny)-1)>.001) return false
    const envelope={x:Math.min(from.x,to.x)+Math.min(0,nx*height),y:Math.min(from.y,to.y)+Math.min(0,ny*height),
        width:scene.hostWidth+Math.abs(to.x-from.x)+Math.abs(nx*height),
        height:scene.hostHeight+Math.abs(to.y-from.y)+Math.abs(ny*height)}
    return envelope.x>=2 && envelope.y>=2 && envelope.x+envelope.width<=scene.width-2
        && envelope.y+envelope.height<=scene.height-2
        && !scene.blockers.some(b=>Slots.intersects(envelope,b,1.5))
}
function landingBelow(scene, point) {
    if (!clearAt(scene,point)) return {qualified:false}
    const floors=[{key:"bottom",y:scene.height-scene.insets.bottom,
        from:scene.insets.left+2,to:scene.width-scene.insets.right-2}]
    for (const s of scene.surfaces) {
        const margin=Math.min(Number(s.radius)||0,s.rect.width/2)
        floors.push({key:s.key,y:s.rect.y,from:s.rect.x+margin,to:s.rect.x+s.rect.width-margin})
    }
    for (let i=0;i<scene.blockers.length;i++) {
        const b=scene.blockers[i]
        if (b.walkable!==false) floors.push({key:"rim"+i,y:b.y,from:b.x,to:b.x+b.width})
    }
    floors.sort((a,b)=>a.y-b.y)
    for (const floor of floors) {
        const next={x:point.x,y:floor.y-scene.hostHeight-Math.max(2,2*scene.scale)}
        if (next.y<point.y+.1 || point.x<floor.from || point.x+scene.hostWidth>floor.to
                || !clearSegment(scene,point,next) || !supportAt(scene,next)) continue
        return annotate(scene,next,"bottom",floor.key==="bottom" ? "edge" : "surface",floor.key)
    }
    return {qualified:false}
}
function path(scene, from, to) {
    if (!valid(scene) || !clearAt(scene,from) || !clearAt(scene,to)) return {qualified:false}
    const a=supportAt(scene,from,from.edge), b=supportAt(scene,to,to.edge)
    const horizontal=a?.axis==="x"
    const walking=!!a && !!b && a.key===b.key && a.edge===b.edge
        && Math.abs((horizontal ? from.y-to.y : from.x-to.x))<.1
        && Math.min(horizontal ? from.x : from.y,horizontal ? to.x : to.y)>=a.from
        && Math.max(horizontal ? from.x : from.y,horizontal ? to.x : to.y)+(horizontal ? scene.hostWidth : scene.hostHeight)<=a.to
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
function nearestWater(scene, point, avoid = null) {
    if (!valid(scene) || !clearAt(scene,point)) return {qualified:false}
    let best=null, candidates=surfacePoints(scene)
    for (const edge of edges) {
        const horizontal=edge==="top" || edge==="bottom"
        const fraction=(horizontal ? point.x+scene.hostWidth/2 : point.y+scene.hostHeight/2)/(horizontal ? scene.width : scene.height)
        const water=edgePoint(scene,edge,fraction)
        if (water.qualified) candidates.push(water)
    }
    candidates.sort((a,b)=>distance(point,a)-distance(point,b))
    for (const water of candidates) {
        if (avoid && distance(water,avoid)<140*scene.scale) continue
        // Straight distance is a lower bound on every routed path. Once it
        // exceeds the best clear route, later candidates cannot improve it.
        if (best && distance(point,water)>=best.route.distance) break
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
    for (const s of scene.surfaces) {
        const margin=Math.min(Number(s.radius)||0,s.rect.width/2)
        floors.push({y:s.rect.y,from:s.rect.x+margin,to:s.rect.x+s.rect.width-margin})
    }
    for (const floor of floors) {
        const candidate={x:point.x,y:floor.y-scene.hostHeight-2*scene.scale}
        if (Math.abs(candidate.y-point.y)<12*scene.scale && point.x>=floor.from
            && point.x+scene.hostWidth<=floor.to && clearAt(scene,candidate)) {point.y=candidate.y;break}
    }
    return annotate(scene,point,"top","drop","drop")
}

// Carry an actor with the painted front of a growing/moving Abyss body. The
// presentation stays revealed; this is a surface attachment, never teleport-
// hide/reappear. The full host and rounded rim still have to fit.
function ride(scene, point, previous) {
    if (!valid(scene) || !previous?.support) return {qualified:false}
    const edge=previous.support.edge, horizontal=edge==="top" || edge==="bottom"
    const candidates=scene.surfaces.filter(s=>s.key===previous.support.key || Slots.intersects(rect(scene,point),s.rect,1.5))
    for (const surface of candidates) {
        const r=surface.rect, margin=Math.min(Number(surface.radius)||0,(horizontal ? r.width : r.height)/2)
        const extent=horizontal ? scene.hostWidth : scene.hostHeight
        const lo=(horizontal ? r.x : r.y)+margin, hi=(horizontal ? r.x+r.width : r.y+r.height)-margin-extent
        if (hi<lo) continue
        const along=clamp(horizontal ? point.x : point.y,lo,hi),gap=Math.max(2,2*scene.scale)
        const candidate=edge==="bottom" ? {x:along,y:r.y-scene.hostHeight-gap}
            : edge==="top" ? {x:along,y:r.y+r.height+gap}
            : edge==="left" ? {x:r.x+r.width+gap,y:along} : {x:r.x-scene.hostWidth-gap,y:along}
        if (clearAt(scene,candidate)) return annotate(scene,candidate,edge,"surface",surface.key)
    }
    return {qualified:false}
}
