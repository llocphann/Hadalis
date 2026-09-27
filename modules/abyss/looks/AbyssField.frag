#version 440
// Original Abyss field: inverse workspace opening unioned with edge deformations.
// One final distance owns fill, specular rim and shadow. No clock/time uniform.
layout(location=0) in vec2 qt_TexCoord0;
layout(location=0) out vec4 fragColor;
layout(std140,binding=0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 viewport;
    vec4 insets;
    vec4 material;
    vec4 effects;
    vec4 wallpaperCrop;
    vec4 surface;
    vec4 raised;
    vec4 rim;
    vec4 shadow;
    vec4 glow;
    vec4 rect0; vec4 rect1; vec4 rect2; vec4 rect3;
    vec4 rect4; vec4 rect5; vec4 rect6; vec4 rect7;
    vec4 rect8; vec4 rect9; vec4 rect10; vec4 rect11;
    vec4 rect12; vec4 rect13; vec4 rect14; vec4 rect15;
    vec4 rect16; vec4 rect17; vec4 rect18; vec4 rect19;
    vec4 rect20; vec4 rect21; vec4 rect22; vec4 rect23;
    vec4 rect24; vec4 rect25; vec4 rect26; vec4 rect27;
    vec4 rect28; vec4 rect29; vec4 rect30; vec4 rect31;
    vec4 rect32; vec4 rect33; vec4 rect34; vec4 rect35;
    vec4 rect36; vec4 rect37; vec4 rect38; vec4 rect39;
};
layout(binding=1) uniform sampler2D wallpaper;
layout(binding=2) uniform sampler2D waveSamples;
float waveAt(float arc) {
    vec4 encoded=texture(waveSamples,vec2(fract(arc/(2.0*(viewport.x+viewport.y))),0.5));
    return encoded.a<0.5 ? 0.0 : ((encoded.r*65280.0+encoded.g*255.0)/65535.0-0.5)*96.0;
}
float displacement(vec2 p) {
    vec4 distances=vec4(p.y,viewport.x-p.x,viewport.y-p.y,p.x);
    float nearest=min(min(distances.x,distances.y),min(distances.z,distances.w));
    // Blend corner projections; adjacent sides share the same circular state.
    vec4 weights=exp(-max(vec4(0.0),distances-nearest)/28.0);
    vec4 arcs=vec4(p.x,viewport.x+p.y,2.0*viewport.x+viewport.y-p.x,2.0*(viewport.x+viewport.y)-p.y);
    vec4 waves=vec4(waveAt(arcs.x),waveAt(arcs.y),waveAt(arcs.z),waveAt(arcs.w));
    return dot(waves,weights)/dot(weights,vec4(1.0))*smoothstep(0.0,10.0,nearest);
}
float roundedBox(vec2 p, vec4 rect, float radius) {
    float r = min(radius,min(rect.z,rect.w)*0.5);
    vec2 q = abs(p-rect.xy-rect.zw*0.5)-rect.zw*0.5+r;
    return length(max(q,0.0))+min(max(q.x,q.y),0.0)-r;
}
float fuse(float a, float b) {
    float k = max(0.1,material.y);
    float h = max(k-abs(a-b),0.0)/k;
    return min(a,b)-h*h*k*0.25;
}
float record(float d, vec2 p, vec4 rect) {
    if(rect.z <= 0.0 || rect.w <= 0.0) return d;
    return fuse(d,roundedBox(p,rect,material.z));
}
float field(vec2 p) {
    vec4 hole=vec4(insets.xy,viewport.xy-insets.xy-insets.zw);
    float d=-roundedBox(p,hole,material.x);
    d=record(d,p,rect0); d=record(d,p,rect1); d=record(d,p,rect2); d=record(d,p,rect3);
    d=record(d,p,rect4); d=record(d,p,rect5); d=record(d,p,rect6); d=record(d,p,rect7);
    d=record(d,p,rect8); d=record(d,p,rect9); d=record(d,p,rect10); d=record(d,p,rect11);
    d=record(d,p,rect12); d=record(d,p,rect13); d=record(d,p,rect14); d=record(d,p,rect15);
    d=record(d,p,rect16); d=record(d,p,rect17); d=record(d,p,rect18); d=record(d,p,rect19);
    d=record(d,p,rect20); d=record(d,p,rect21); d=record(d,p,rect22); d=record(d,p,rect23);
    d=record(d,p,rect24); d=record(d,p,rect25); d=record(d,p,rect26); d=record(d,p,rect27);
    d=record(d,p,rect28); d=record(d,p,rect29); d=record(d,p,rect30); d=record(d,p,rect31);
    d=record(d,p,rect32); d=record(d,p,rect33); d=record(d,p,rect34); d=record(d,p,rect35);
    d=record(d,p,rect36); d=record(d,p,rect37); d=record(d,p,rect38); d=record(d,p,rect39);
    return d-displacement(p);
}
void main() {
    vec2 p=qt_TexCoord0*viewport.xy;
    float d=field(p);
    // Derivatives are evaluated before any divergent early return.
    vec2 gradient=vec2(dFdx(d),dFdy(d));
    float aa=max(0.6,fwidth(d)*0.6);
    if(d>24.0) { fragColor=vec4(0.0); return; }
    float coverage=1.0-smoothstep(-aa,aa,d);
    float depth=exp(-abs(d)*0.045);
    vec4 body=mix(surface,raised*surface.a,depth*0.38);
    if(effects.z>0.5 && coverage>0.0) {
        vec2 normal=gradient/max(0.0001,length(gradient));
        vec2 uv=qt_TexCoord0+normal*effects.y*exp(-abs(d)/30.0)/viewport.xy;
        uv=wallpaperCrop.xy+clamp(uv,0.0,1.0)*wallpaperCrop.zw;
        vec2 stepUv=effects.x/viewport.xy*wallpaperCrop.zw;
        vec3 glass=texture(wallpaper,uv).rgb;
        if(effects.x>0.0) {
            // Bounded five-tap wallpaper blur in the same silhouette pass.
            glass=glass*0.4+(texture(wallpaper,uv+vec2(stepUv.x,0)).rgb
                +texture(wallpaper,uv-vec2(stepUv.x,0)).rgb
                +texture(wallpaper,uv+vec2(0,stepUv.y)).rgb
                +texture(wallpaper,uv-vec2(0,stepUv.y)).rgb)*0.15;
        }
        // Strong absorption keeps typography readable; no live application
        // pixels are sampled. Missing/animated wallpaper uses the color body.
        body.rgb=mix(body.rgb,glass*surface.a,0.075+depth*0.07);
    }
    vec2 normal=gradient/max(0.0001,length(gradient));
    float facing=clamp(dot(normal,normalize(vec2(-0.45,-0.85)))*0.5+0.5,0.0,1.0);
    float reflection=exp(-abs(d)*0.19)*(0.10+0.40*pow(facing,3.0))*material.w;
    float spec=exp(-abs(d)*0.8)*pow(facing,5.0)*material.w;
    body.rgb=mix(body.rgb,raised.rgb*body.a,reflection);
    body.rgb+=rim.rgb*body.a*(spec*0.65+reflection*0.32);
    body.rgb*=1.0-exp(-max(-d,0.0)*0.10)*(1.0-facing)*0.18;
    body.a=surface.a;
    vec4 outside=shadow*exp(-max(d,0.0)/5.0)+glow*exp(-max(d,0.0)/7.0);
    outside*=smoothstep(-aa,aa,d)*(1.0-smoothstep(16.0,24.0,d));
    float alpha=coverage*body.a;
    fragColor=(body*coverage+outside*(1.0-alpha))*qt_Opacity;
}
