// Persist normalized positions; derive pixel geometry independently per output.
var catalog = ["distroIcon","activeWindow","resources","media",
    "workspaces","clock","utilButtons","battery","tray",
    "timer","shellUpdate","weather","taskbar","wifi","bluetooth","utilities"];
var labels = {distroIcon:"Launcher",activeWindow:"Active window",
    resources:"System resources",media:"Media",workspaces:"Workspaces",clock:"Clock",
    utilButtons:"Quick actions",battery:"Battery",tray:"System tray",
    timer:"Timer",shellUpdate:"Updates",weather:"Weather",taskbar:"Taskbar",wifi:"Wi-Fi",bluetooth:"Bluetooth",utilities:"Utilities"};
function label(kind) { return labels[kind] || kind; }
function bounded(value, fallback, low, high) {
    var number = Number(value);
    return Number.isFinite(number) ? Math.max(low,Math.min(high,number)) : fallback;
}
function extent(kind, vertical) {
    var sizes = {utilButtons:36,distroIcon:88,
        activeWindow:178,resources:178,media:166,workspaces:192,clock:104,battery:72,
        tray:72,timer:68,shellUpdate:86,weather:80,taskbar:40,utilities:42};
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
            alignment:["start","center","end"].indexOf(p.alignment)>=0 ? p.alignment : "free",
            customSize:p.customSize === true || (p.customSize === undefined && Number.isFinite(Number(p.size)) && Number(p.size)!==1),
            size:bounded(p.size,1,0.6,1.8),depth:bounded(p.depth,1,0.5,2),
            influence:bounded(p.influence,1,0,2),compact:p.compact === true,joinCorner:p.joinCorner === true};
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
    return Object.assign({},options,{gap:profile?.gap ?? options?.gap ?? 8,
        size:bounded(profile?.size ?? options?.size,1,.6,1.8),
        edgeSizes:Object.assign({},options?.edgeSizes,profile?.edgeSizes),
        singleModuleExpansion:Object.assign({},options?.singleModuleExpansion,profile?.singleModuleExpansion)});
}
function edgeSize(options, edge) { return bounded(options?.edgeSizes?.[edge],1,.6,1.8); }
function moduleSize(placement, options) {
    return (placement.customSize ? placement.size : edgeSize(options,placement.edge)*bounded(options?.edgeThickness,16,10,40)/16)*bounded(options?.size,1,.6,1.8);
}
function project(x, y, width, height) {
    var distances = [y,width-x,height-y,x];
    var index = distances.indexOf(Math.min.apply(null,distances));
    var edge = ["top","right","bottom","left"][index];
    return {edge:edge,position:bounded((index%2===0 ? x : y)/Math.max(1,index%2===0 ? width : height),.5,0,1)};
}
function move(placements, id, x, y, width, height) {
    var location = project(x,y,width,height);
    return normalize(placements.map(function(p) { return p.id===id ? Object.assign({},p,location,{alignment:"free"}) : p; }),"top");
}
// Snap to the output center, end margins, and adjacent modules at the configured gap.
// Guides are presentation data only; positions stay normalized for other resolutions.
function snapMove(placements, id, x, y, width, height, options, fontScale) {
    var moved = move(placements,id,x,y,width,height);
    var selected = moved.find(function(p) { return p.id===id; });
    if (!selected) return {placements:moved,guides:[]};
    var horizontal = selected.edge==="top" || selected.edge==="bottom";
    var length = horizontal ? width : height;
    var margin = Math.min(34,length/12), usable = length-2*margin;
    var records = geometry(moved,width,height,options,fontScale);
    var own = records.find(function(p) { return p.id===id; });
    if (!own || usable<=0) return {placements:moved,guides:[]};
    var center = margin+selected.position*usable;
    var gap = bounded(options?.gap,8,0,32);
    var targets = [{center:length/2,line:length/2,label:"Center"},
        {center:margin+own.span/2,line:margin,label:"Start"},
        {center:length-margin-own.span/2,line:length-margin,label:"End"}];
    geometry(moved.filter(function(p) { return p.id!==id; }),width,height,options,fontScale)
        .filter(function(p) { return p.edge===selected.edge; }).forEach(function(p) {
        targets.push({center:p.along-gap-own.span/2,line:p.along-gap,label:Math.round(gap)+" px gap"});
        targets.push({center:p.along+p.span+gap+own.span/2,line:p.along+p.span+gap,label:Math.round(gap)+" px gap"});
    });
    var target = targets.filter(function(t) { return t.center-own.span/2>=margin && t.center+own.span/2<=length-margin; })
        .sort(function(a,b) { return Math.abs(a.center-center)-Math.abs(b.center-center); })[0];
    if (!target || Math.abs(target.center-center)>10) return {placements:moved,guides:[]};
    moved = moved.map(function(p) { return p.id===id ? Object.assign({},p,{position:(target.center-margin)/usable}) : p; });
    var actual = geometry(moved,width,height,options,fontScale).find(function(p) { return p.id===id; });
    // Do not show a misleading guide when collision packing prevented this snap.
    return {placements:moved,guides:Math.abs(actual.along+actual.span/2-target.center)<1
        ? [{horizontal:horizontal,along:target.line,label:target.label}] : []};
}
function saveProfile(options, outputName, placements, gap, outputOnly, edgeSizes, singleModuleExpansion, size) {
    var normalized = normalize(placements,"top");
    var profiles = Array.from(options?.outputLayouts || []);
    var current = optionsForOutput(options,outputName);
    var expansion = Object.assign({},singleModuleExpansion ?? current.singleModuleExpansion);
    var scale = bounded(size ?? current.size,1,.6,1.8);
    if (outputOnly) {
        var existing = profiles.find(function(p) { return p.outputName===outputName; });
        profiles = profiles.filter(function(p) { return p.outputName!==outputName; });
        profiles.push(Object.assign({},existing,{outputName:outputName,placements:normalized,gap:bounded(gap,8,0,32),
            edgeSizes:Object.assign({},edgeSizes ?? current.edgeSizes),singleModuleExpansion:expansion,size:scale}));
        return {"abyss.modules.outputLayouts":profiles};
    }
    return {"abyss.modules.configured":true,"abyss.modules.placements":normalized,
        "abyss.modules.gap":bounded(gap,8,0,32),"abyss.modules.outputLayouts":profiles.filter(function(p) { return p.outputName!==outputName; }),
        "abyss.modules.edgeSizes":Object.assign({},edgeSizes ?? options?.edgeSizes),
        "abyss.modules.singleModuleExpansion":expansion,"abyss.modules.size":scale};
}
function stripDepth(placements, edge, options, fontScale) {
    return placements.filter(function(p) { return p.enabled && p.edge===edge; }).reduce(function(depth,p) {
        return Math.max(depth,32*bounded(fontScale,1,.7,2)*moduleSize(p,options)*p.depth+16);
    },48);
}
function edgeInsetsForModules(placements, options, fontScale, thickness, minimum, reservation) {
    var insets = {top:thickness,right:thickness,bottom:thickness,left:thickness};
    ["top","right","bottom","left"].forEach(function(edge) {
        var enabled = placements.filter(function(p) { return p.enabled && p.edge===edge; });
        if (!enabled.length) return;
        // Wayland reserves a whole edge. Local paint still reserves enough room
        // for its module so application windows cannot obscure that foreground.
        if (reservation || enabled.length!==1 || options?.singleModuleExpansion?.[edge]!=="local")
            insets[edge] = Math.max(minimum,stripDepth(placements,edge,options,fontScale));
    });
    return insets;
}
function localSurfaces(records, width, height, options, fontScale, minimum) {
    return records.filter(function(p) {
        return options?.singleModuleExpansion?.[p.edge]==="local"
            && records.filter(function(other) { return other.edge===p.edge; }).length===1;
    }).map(function(p) {
        // Geometry records express depth in pixels, unlike placement depth's
        // multiplier. Derive the paint extent from the packed foreground.
        var depth = Math.max(minimum,(p.vertical ? p.content.width : p.content.height)+16);
        var surface = p.edge==="top" ? {x:p.along-8,y:-50,width:p.span+16,height:depth+50}
            : p.edge==="bottom" ? {x:p.along-8,y:height-depth,width:p.span+16,height:depth+50}
            : p.edge==="left" ? {x:-50,y:p.along-8,width:depth+50,height:p.span+16}
            : {x:width-depth,y:p.along-8,width:depth+50,height:p.span+16};
        return {edge:p.edge,surface:surface,content:p.content,span:p.span,along:p.along,depth:depth,progress:1,mass:1};
    });
}
function clearanceInsets(insets, localRecords, edge, along, span) {
    var result=Object.assign({},insets);
    localRecords.forEach(function(record) {
        if(record.edge===edge && record.along-8<along+span && record.along+record.span+8>along)
            result[edge]=Math.max(result[edge],record.depth);
    });
    return result;
}
function geometry(placements, width, height, options, fontScale) {
    var result = [];
    ["top","right","bottom","left"].forEach(function(edge) {
        var horizontal = edge === "top" || edge === "bottom";
        var length = horizontal ? width : height;
        var margin = Math.min(34,length/12), gap = bounded(options?.gap,8,0,32);
        var list = placements.filter(function(p) { return p.enabled && p.edge === edge; })
            .sort(function(a,b) { return a.position-b.position || a.id.localeCompare(b.id); });
        var sizes = list.map(function(p) {
            var measured = options?.extents?.[p.id];
            var natural = Number.isFinite(measured) && !(options?.editing && measured<1) ? Math.max(0,measured)
                : extent(p.kind,!horizontal)*bounded(fontScale,1,0.7,2);
            return natural*moduleSize(p,options);
        });
        var total = sizes.reduce(function(sum,n) { return sum+n; },0);
        if (!list.length || length < 1) return;
        gap = Math.min(gap,Math.max(0,(length-2*margin)/(list.length*4)));
        var scale = Math.min(1,Math.max(0.01,(length-2*margin-gap*(list.length-1))/Math.max(1,total)));
        // Each aligned group keeps its internal order; free placements keep their
        // requested position. Resolve collisions once across the entire edge.
        var targets = list.map(function(p,index) { return margin+p.position*(length-2*margin)-sizes[index]*scale/2; });
        ["start","center","end"].forEach(function(alignment) {
            var indices = list.map(function(p,i) { return p.alignment===alignment ? i : -1; }).filter(function(i) { return i>=0; });
            var groupSpan = indices.reduce(function(sum,i) { return sum+sizes[i]*scale; },0)+Math.max(0,indices.length-1)*gap;
            var start = alignment==="start" ? margin : alignment==="end" ? length-margin-groupSpan : (length-groupSpan)/2;
            indices.forEach(function(i) { targets[i]=start;start+=sizes[i]*scale+gap; });
        });
        var order = list.map(function(p,index) { return {placement:p,index:index}; }).sort(function(a,b) {
            return targets[a.index]-targets[b.index] || a.placement.id.localeCompare(b.placement.id);
        });
        var cursor = margin;
        var records = order.map(function(entry) {
            var p=entry.placement,index=entry.index;
            var size = sizes[index]*scale;
            var start = Math.max(cursor,targets[index]);
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
            var inset = 8, cross = 32*bounded(fontScale,1,.7,2)*moduleSize(p,options)*scale;
            p.content = horizontal ? {x:p.along,y:edge==="top"?inset:height-inset-cross,width:p.span,height:cross}
                : {x:edge==="left"?inset:width-inset-cross,y:p.along,width:cross,height:p.span};
            result.push(p);
        });
    });
    return result;
}

// Only modules within a short distance of a physical corner offer a second weld.
function adjacentEdge(record,width,height) {
    if (!record) return "";
    var horizontal = record.edge === "top" || record.edge === "bottom";
    var length = horizontal ? width : height;
    var first = Math.max(0,record.along);
    var last = Math.max(0,length-record.along-record.span);
    if (Math.min(first,last)>160) return "";
    return horizontal ? (first<=last ? "left" : "right") : (first<=last ? "top" : "bottom");
}
