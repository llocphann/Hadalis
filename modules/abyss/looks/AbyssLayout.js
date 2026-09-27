// Persist normalized positions; derive pixel geometry independently per output.
var catalog = ["leftSidebarButton","distroIcon","activeWindow","resources","media",
    "workspaces","clock","utilButtons","battery","rightSidebarButton","tray",
    "timer","shellUpdate","weather","taskbar"];
function bounded(value, fallback, low, high) {
    var number = Number(value);
    return Number.isFinite(number) ? Math.max(low,Math.min(high,number)) : fallback;
}
function extent(kind, vertical) {
    var sizes = {leftSidebarButton:36,rightSidebarButton:36,utilButtons:36,distroIcon:88,
        activeWindow:178,resources:178,media:166,workspaces:192,clock:104,battery:72,
        tray:72,timer:68,shellUpdate:86,weather:80,taskbar:40};
    return vertical ? (kind === "workspaces" ? 192 : kind === "clock" ? 86 : kind === "tray" ? 72 : 42) : (sizes[kind] || 48);
}
function normalize(list, fallbackEdge) {
    var seen = {};
    return Array.from(list || []).filter(function(p) {
        if (!p || catalog.indexOf(String(p.kind)) < 0) return false;
        var id = String(p.id || p.kind);
        if (seen[id]) return false;
        seen[id] = true;
        return true;
    }).slice(0,24).map(function(p) {
        return {id:String(p.id || p.kind),kind:String(p.kind),
            edge:["top","right","bottom","left"].indexOf(p.edge)>=0 ? p.edge : fallbackEdge,
            position:bounded(p.position,0.5,0,1),enabled:p.enabled !== false,
            size:bounded(p.size,1,0.6,1.8),depth:bounded(p.depth,1,0.5,2),
            influence:bounded(p.influence,1,0,2),compact:p.compact === true};
    });
}
function seed(zones, edge, width, height) {
    var vertical = edge === "left" || edge === "right";
    var length = vertical ? height : width;
    var result = [];
    zones.forEach(function(ids, group) {
        var total = ids.reduce(function(sum,kind) { return sum+extent(kind,vertical)+8; },0)-8;
        var cursor = (group+0.5)*length/5-total/2;
        ids.forEach(function(kind) {
            var size = extent(kind,vertical);
            result.push({id:kind,kind:kind,edge:edge,position:(cursor+size/2)/Math.max(1,length)});
            cursor += size+8;
        });
    });
    return normalize(result,edge);
}
function resolve(options, outputName, fallback) {
    var profiles = Array.from(options?.outputLayouts || []);
    var profile = profiles.find(function(p) { return p.outputName === outputName; });
    if (profile) return normalize(profile.placements,"top");
    return options?.configured ? normalize(options.placements,"top") : fallback;
}
function optionsForOutput(options, outputName) {
    var profile = Array.from(options?.outputLayouts || []).find(function(p) { return p.outputName === outputName; });
    return Object.assign({},options,{gap:profile?.gap ?? options?.gap ?? 8});
}
function project(x, y, width, height) {
    var distances = [y,width-x,height-y,x];
    var index = distances.indexOf(Math.min.apply(null,distances));
    var edge = ["top","right","bottom","left"][index];
    return {edge:edge,position:bounded((index%2===0 ? x : y)/Math.max(1,index%2===0 ? width : height),.5,0,1)};
}
function move(placements, id, x, y, width, height) {
    var location = project(x,y,width,height);
    return normalize(placements.map(function(p) { return p.id===id ? Object.assign({},p,location) : p; }),"top");
}
function saveProfile(options, outputName, placements, gap, outputOnly) {
    var normalized = normalize(placements,"top");
    var profiles = Array.from(options?.outputLayouts || []);
    if (outputOnly) {
        profiles = profiles.filter(function(p) { return p.outputName!==outputName; });
        profiles.push({outputName:outputName,placements:normalized,gap:bounded(gap,8,0,32)});
        return {"abyss.modules.outputLayouts":profiles};
    }
    return {"abyss.modules.configured":true,"abyss.modules.placements":normalized,
        "abyss.modules.gap":bounded(gap,8,0,32),"abyss.modules.outputLayouts":profiles.filter(function(p) { return p.outputName!==outputName; })};
}
function geometry(placements, width, height, options, fontScale) {
    var result = [];
    ["top","right","bottom","left"].forEach(function(edge) {
        var horizontal = edge === "top" || edge === "bottom";
        var length = horizontal ? width : height;
        var margin = Math.min(34,length/12), gap = bounded(options?.gap,8,0,32);
        var list = placements.filter(function(p) { return p.enabled && p.edge === edge; })
            .sort(function(a,b) { return a.position-b.position || a.id.localeCompare(b.id); });
        var sizes = list.map(function(p) { return extent(p.kind,!horizontal)*p.size*bounded(options?.size,1,0.6,1.8)*bounded(fontScale,1,0.7,2); });
        var total = sizes.reduce(function(sum,n) { return sum+n; },0);
        if (!list.length || length < 1) return;
        gap = Math.min(gap,Math.max(0,(length-2*margin)/(list.length*4)));
        var scale = Math.min(1,Math.max(0.01,(length-2*margin-gap*(list.length-1))/Math.max(1,total)));
        var cursor = margin;
        var records = list.map(function(p,index) {
            var size = sizes[index]*scale;
            var start = Math.max(cursor,margin+p.position*(length-2*margin)-size/2);
            cursor = start+size+gap;
            return Object.assign({},p,{along:start,span:size,vertical:!horizontal,
                depth:bounded(options?.depth,36,22,64)*p.depth,
                compact:p.compact || (!horizontal && p.kind!=="clock") || scale<0.65});
        });
        var end = length-margin;
        for (var i=records.length-1;i>=0;i--) {
            records[i].along = Math.max(margin,Math.min(records[i].along,end-records[i].span));
            end = records[i].along-gap;
        }
        records.forEach(function(p) {
            var inset = 10, cross = 32;
            p.content = horizontal ? {x:p.along,y:edge==="top"?inset:height-inset-cross,width:p.span,height:cross}
                : {x:edge==="left"?inset:width-inset-cross,y:p.along,width:cross,height:p.span};
            result.push(p);
        });
    });
    return result;
}
