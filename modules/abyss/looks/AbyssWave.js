// A damped spring string on one closed output perimeter, in logical pixels.
var presets = {
    calm:{amplitude:.12,propagation:.35,speed:.3,decay:.85,tension:.8,viscosity:.85,rebound:.2,corner:.4},
    balanced:{amplitude:.8,propagation:.8,speed:.55,decay:.55,tension:.5,viscosity:.55,rebound:.6,corner:.8},
    fluid:{amplitude:2,propagation:1,speed:.8,decay:.45,tension:.3,viscosity:.25,rebound:.85,corner:1},
    deep:{amplitude:4,propagation:1,speed:.3,decay:.6,tension:.15,viscosity:.45,rebound:.9,corner:1}
};
function bounded(value, fallback, maximum) {
    return Number.isFinite(Number(value)) ? Math.max(0,Math.min(maximum,Number(value))) : fallback;
}
function heightLimit(state) {
    return Math.min(4+32*state.parameters.amplitude, Math.min(state.width,state.height)*.3, 144);
}
function bodyStrength(options) {
    if (Number.isFinite(Number(options?.strength)) && Number(options.strength)>=0)
        return bounded(options.strength,1,4);
    // Preserve the strongest old presentation response until the shared control
    // is explicitly set. Old fields remain migration input, not active controls.
    return Math.max(.1,...["small","large","dock","notifications"].map(
        key=>bounded(options?.[key],1,4)));
}
function unit(value, fallback) {
    return Number.isFinite(Number(value)) ? Math.max(0,Math.min(1,Number(value))) : fallback;
}
function parameters(options) {
    var base = presets[options?.preset] || presets.balanced;
    var result = {};
    Object.keys(base).forEach(function(key) { result[key] = options?.preset === "custom" ? bounded(options[key],base[key],key === "amplitude" ? 4 : 1) : base[key]; });
    ["hover","press","open","close","drag"].forEach(function(key) { result[key] = unit(options?.[key],1); });
    result.idle = options?.idle === true;
    result.strength = bodyStrength(options);
    return result;
}
function arc(edge, along, width, height) {
    if (edge === "right") return width+along;
    if (edge === "bottom") return width+height+width-along;
    if (edge === "left") return 2*width+height+height-along;
    return along;
}
function create(count, width, height, options) {
    return {count:count,width:width,height:height,length:Math.max(1,2*(width+height)),
        displacement:Array(count).fill(0),velocity:Array(count).fill(0),mass:Array(count).fill(1),
        spectrumTargets:Array(count).fill(0),hasSpectrum:false,
        acceleration:Array(count).fill(0),
        parameters:options,mode:"SLEEPING",quiet:0,age:0,steps:0};
}
function circularDistance(a,b,length) {
    var distance=Math.abs(a-b)%length;
    return Math.min(distance,length-distance);
}
function setMass(state, records) {
    state.mass.fill(1);
    records.forEach(function(record) {
        if (!record.mass || !record.progress) return;
        var center=arc(record.edge,record.along+record.span/2,state.width,state.height);
        var width=Math.max(40,record.span*.55);
        for(var i=0;i<state.count;i++) {
            var d=circularDistance(i*state.length/state.count,center,state.length)/width;
            state.mass[i]=Math.min(5,state.mass[i]+Math.min(4,record.mass)*record.progress*Math.exp(-d*d*2));
        }
    });
}
function impulse(state, edge, along, span, strength, mass) {
    var p=state.parameters;
    var center=arc(edge,along,state.width,state.height)%state.length;
    var width=Math.max(state.length/state.count*1.5,span*(.35+.3*p.propagation));
    var amount=strength*(60+280*p.amplitude)*Math.sqrt(Math.max(1,Math.min(6,mass || 1)));
    for(var i=0;i<state.count;i++) {
        var d=circularDistance(i*state.length/state.count,center,state.length)/width;
        state.velocity[i]=Math.max(-2000,Math.min(2000,state.velocity[i]+amount*Math.exp(-d*d*2)/Math.sqrt(state.mass[i])));
    }
    state.mode="ACTIVE";state.age=0;state.quiet=0;
}
// Feed a bounded, smooth rest shape into the same spring field. Constant audio
// can settle to a static wave; changing CAVA frames wake it without an idle clock.
function spectrum(state, edges, points, ceiling, strength) {
    var count=points?.length || 0,changed=false,active=false;
    var maximum=heightLimit(state)*bounded(strength,0,4)*2;
    var normalizer=Math.max(20,Number(ceiling) || 100);
    for(var i=0;i<state.count;i++) {
        var location=i*state.length/state.count,edge,along,length;
        if(location<state.width) { edge="top";along=location;length=state.width; }
        else if(location<state.width+state.height) { edge="right";along=location-state.width;length=state.height; }
        else if(location<2*state.width+state.height) { edge="bottom";along=2*state.width+state.height-location;length=state.width; }
        else { edge="left";along=state.length-location;length=state.height; }
        var t=along/Math.max(1,length),target=0;
        if(count && edges.indexOf(edge)>=0 && maximum>0) {
            var position=t*(count-1),low=Math.floor(position),high=Math.min(count-1,low+1);
            var a=Number(points[low]),b=Number(points[high]);
            var level=((Number.isFinite(a)?Math.max(0,a):0)*(1-(position-low))+(Number.isFinite(b)?Math.max(0,b):0)*(position-low))/normalizer;
            level=Math.sqrt(Math.max(0,Math.min(1,level)));
            if(level>.025) target=Math.min(heightLimit(state),maximum*level)*Math.sin(t*Math.PI*6)*Math.pow(Math.sin(t*Math.PI),2);
        }
        if(Math.abs(target-state.spectrumTargets[i])>.005 || (target===0 && state.spectrumTargets[i]!==0)) {
            changed=true;state.spectrumTargets[i]=target;
        }
        active=active || Math.abs(state.spectrumTargets[i])>.005;
    }
    state.hasSpectrum=active;
    if(changed) { state.mode="ACTIVE";state.quiet=0;state.age=0; }
    return changed;
}
function advance(state, elapsed) {
    if(state.mode === "SLEEPING") return false;
    var p=state.parameters,dx=state.length/state.count;
    var speed=(160+700*p.speed)*(.3+.7*p.propagation);
    var parts=Math.ceil(Math.max(0,Math.min(.05,elapsed))*Math.max(120,2.5*speed/dx));
    var dt=Math.max(0,Math.min(.05,elapsed))/Math.max(1,parts);
    var limit=heightLimit(state);
    var corners=[0,state.width,state.width+state.height,2*state.width+state.height];
    for(var step=0;step<parts;step++) {
        var acceleration=state.acceleration;
        for(var i=0;i<state.count;i++) {
            var left=(i+state.count-1)%state.count,right=(i+1)%state.count;
            var location=i*dx;
            var atCorner=corners.some(function(c) { return circularDistance(location,c,state.length)<dx*1.5; });
            var transfer=atCorner ? .15+.85*p.corner : 1;
            var lap=state.displacement[left]+state.displacement[right]-2*state.displacement[i];
            var viscous=state.velocity[left]+state.velocity[right]-2*state.velocity[i];
            var spring=(18+62*p.tension)*(.4+.6*p.rebound);
            var damping=1.2+7*p.decay+3*(1-p.propagation)+(atCorner?(1-p.corner)*2:0);
            acceleration[i]=(speed*speed/(dx*dx)*lap*transfer+spring*(state.spectrumTargets[i]-state.displacement[i])
                +p.viscosity*900/(dx*dx)*viscous)/state.mass[i]-damping*state.velocity[i];
        }
        for(var j=0;j<state.count;j++) {
            state.velocity[j]+=acceleration[j]*dt;
            state.displacement[j]+=state.velocity[j]*dt;
            if(Math.abs(state.displacement[j])>limit) {
                state.displacement[j]=Math.sign(state.displacement[j])*limit;
                state.velocity[j]*=.2;
            }
        }
        state.steps++;
    }
    state.age+=elapsed;
    var quiet=(state.hasSpectrum || state.displacement.every(function(v) { return Math.abs(v)<.025; }))
        && state.velocity.every(function(v) { return Math.abs(v)<.12; });
    state.quiet=quiet ? state.quiet+1 : 0;
    if(state.quiet>=8) {
        if(!state.hasSpectrum) state.displacement.fill(0);
        state.velocity.fill(0);state.mode="SLEEPING";
    } else state.mode=state.age<.2 ? "ACTIVE" : "SETTLING";
    return true;
}
