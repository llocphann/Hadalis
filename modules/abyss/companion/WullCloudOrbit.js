.pragma library

// A finite, inward-facing orbit. No clock, animation or full-screen hit target.
function overlaps(a, b, gap) {
    return a.x < b.x+b.width+gap && a.x+a.width+gap > b.x
        && a.y < b.y+b.height+gap && a.y+a.height+gap > b.y;
}

function layout(outputWidth, outputHeight, actor) {
    const scale = Math.max(.1, Number(actor.scale) || 1);
    const width = actor.width*scale, height = actor.height*scale;
    const cx = actor.x+actor.width/2+(Number(actor.sideAlignment)||0)*scale;
    const cy = actor.y+actor.height/2+(Number(actor.floorAlignment)||0)*scale;
    const nodeWidth = Math.max(38, Math.min(48, Math.min(width,height)*.62));
    const nodeHeight = nodeWidth*42/48;
    const body = {x:cx-width/2,y:cy-height/2,width:width,height:height};
    const empty = {available:false,nodes:[{x:0,y:0,width:nodeWidth,height:nodeHeight},
        {x:0,y:0,width:nodeWidth,height:nodeHeight}]};
    let edge = actor.edge;
    if (!["top","bottom","left","right"].includes(edge)) {
        const distances = [cy,outputHeight-cy,cx,outputWidth-cx];
        edge = ["top","bottom","left","right"][distances.indexOf(Math.min.apply(null,distances))];
    }
    const normal = edge==="top" ? Math.PI/2 : edge==="bottom" ? -Math.PI/2
        : edge==="right" ? Math.PI : 0;
    const baseRadius = Math.max(width/2+nodeWidth/2,height/2+nodeHeight/2)+14;
    function node(angle, radius) {
        return {x:cx+Math.cos(angle)*baseRadius*radius-nodeWidth/2,
            y:cy+Math.sin(angle)*baseRadius*radius-nodeHeight/2,
            width:nodeWidth,height:nodeHeight};
    }
    function fits(n) {
        const nx = n.x+n.width/2, ny = n.y+n.height/2;
        return n.x>=8 && n.y>=8 && n.x+n.width<=outputWidth-8
            && n.y+n.height<=outputHeight-8 && !overlaps(n,body,3)
            && (nx-cx)*Math.cos(normal)+(ny-cy)*Math.sin(normal)>0;
    }
    // Keep equal distances and mirrored angles. Near a corner, turn the pair
    // inward together instead of shifting just one action out of symmetry.
    for (const turn of [0,-Math.PI/8,Math.PI/8,-Math.PI/4,Math.PI/4]) {
        for (const radius of [1,1.15,1.35]) {
            for (const spread of [.8,1.05,.65,.5,.4]) {
                const axis = normal+turn;
                const a = node(axis-spread,radius), b = node(axis+spread,radius);
                if (fits(a) && fits(b) && !overlaps(a,b,4))
                    return {available:true,nodes:[a,b],axisAngle:axis};
            }
        }
    }
    // A tiny/occluded output must not stack buttons or spill onto another screen.
    return empty;
}
