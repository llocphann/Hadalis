// A damped spring string on one closed output perimeter, in logical pixels.
var presets = {
    calm:{amplitude:.25,propagation:.45,speed:.35,decay:.8,tension:.7,viscosity:.8,rebound:.25,corner:.6},
    balanced:{amplitude:.6,propagation:.8,speed:.55,decay:.55,tension:.5,viscosity:.55,rebound:.6,corner:.8},
    fluid:{amplitude:.8,propagation:.9,speed:.65,decay:.4,tension:.35,viscosity:.35,rebound:.8,corner:.9},
    deep:{amplitude:.7,propagation:.7,speed:.3,decay:.5,tension:.3,viscosity:.7,rebound:.7,corner:.75}
};
function unit(value, fallback) {
    return Number.isFinite(Number(value)) ? Math.max(0,Math.min(1,Number(value))) : fallback;
}
function parameters(options) {
    var base = presets[options?.preset] || presets.balanced;
    var result = {};
    Object.keys(base).forEach(function(key) { result[key] = options?.preset === "custom" ? unit(options[key],base[key]) : base[key]; });
    ["hover","press","open","close","drag"].forEach(function(key) { result[key] = unit(options?.[key],1); });
    result.idle = options?.idle === true;
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
    var amount=strength*(30+150*p.amplitude)*Math.sqrt(Math.max(1,Math.min(6,mass || 1)));
    for(var i=0;i<state.count;i++) {
        var d=circularDistance(i*state.length/state.count,center,state.length)/width;
        state.velocity[i]=Math.max(-500,Math.min(500,state.velocity[i]+amount*Math.exp(-d*d*2)/Math.sqrt(state.mass[i])));
    }
    state.mode="ACTIVE";state.age=0;state.quiet=0;
}
function advance(state, elapsed) {
    if(state.mode === "SLEEPING") return false;
    var p=state.parameters,dx=state.length/state.count;
    var speed=(160+700*p.speed)*(.3+.7*p.propagation);
    var parts=Math.ceil(Math.max(0,Math.min(.05,elapsed))*Math.max(120,2.5*speed/dx));
    var dt=Math.max(0,Math.min(.05,elapsed))/Math.max(1,parts);
    var limit=4+32*p.amplitude;
    var corners=[0,state.width,state.width+state.height,2*state.width+state.height];
    for(var step=0;step<parts;step++) {
        var acceleration=Array(state.count);
        for(var i=0;i<state.count;i++) {
            var left=(i+state.count-1)%state.count,right=(i+1)%state.count;
            var location=i*dx;
            var atCorner=corners.some(function(c) { return circularDistance(location,c,state.length)<dx*1.5; });
            var transfer=atCorner ? .15+.85*p.corner : 1;
            var lap=state.displacement[left]+state.displacement[right]-2*state.displacement[i];
            var viscous=state.velocity[left]+state.velocity[right]-2*state.velocity[i];
            var spring=(18+62*p.tension)*(.4+.6*p.rebound);
            var damping=1.2+7*p.decay+3*(1-p.propagation)+(atCorner?(1-p.corner)*2:0);
            acceleration[i]=(speed*speed/(dx*dx)*lap*transfer-spring*state.displacement[i]
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
    var quiet=state.displacement.every(function(v) { return Math.abs(v)<.025; })
        && state.velocity.every(function(v) { return Math.abs(v)<.12; });
    state.quiet=quiet ? state.quiet+1 : 0;
    if(state.quiet>=8) {
        state.displacement.fill(0);state.velocity.fill(0);state.mode="SLEEPING";
    } else state.mode=state.age<.2 ? "ACTIVE" : "SETTLING";
    return true;
}
