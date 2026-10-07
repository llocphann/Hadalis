#version 440
// Implicit rounded 3D liquid volume. Front intersections are analytic;
// transmitted rays find the back interface with a bounded tiered search.
layout(location=0) in vec2 qt_TexCoord0;
layout(location=0) out vec4 fragColor;
layout(std140,binding=0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 accent;
    vec4 specular;
    vec4 motion; // shimmer, tip bend, pulse, effects gate
    vec4 optics; // yaw (radians), body/sphere/cornea/foot variant, eye gaze x/y
    vec4 rendering; // quality tier 0..2, liquid translucency 0..0.35
    vec4 curve0;
    vec4 curve1;
    vec4 curve2;
    vec4 curve3;
    vec4 bounds;
    vec4 pose; // pitch, roll (radians), local X/Y scale minus one
};

vec4 curve(float t) {
    float u=1.0-t;
    vec3 p=curve0.xyz*u*u*u+curve1.xyz*3.0*u*u*t+curve2.xyz*3.0*u*t*t+curve3.xyz*t*t*t;
    return vec4(p,mix(curve0.w,curve3.w,t));
}
// A finite piecewise tapered tube with spherical joins. The ray finds the
// foremost 3D interface analytically, even during pitch/yaw/tentacle curling.
float field(vec3 p) {
    float d=100.0;
    for(int i=0;i<8;i++) {
        vec4 a=curve(float(i)/8.0),b=curve(float(i+1)/8.0);
        vec3 v=b.xyz-a.xyz;float t=clamp(dot(p-a.xyz,v)/max(dot(v,v),0.00001),0.0,1.0);
        d=min(d,length(p-mix(a.xyz,b.xyz,t))-mix(a.w,b.w,t));
    }
    return d;
}
vec3 normalAt(vec3 p) {
    const vec2 e=vec2(0.001,0.0);
    return normalize(vec3(field(p+e.xyy)-field(p-e.xyy),field(p+e.yxy)-field(p-e.yxy),field(p+e.yyx)-field(p-e.yyx))+vec3(0,0,0.000001));
}
void sphereHit(vec3 o,vec3 d,vec4 s,inout float nearest,inout float along,float t) {
    vec3 p=o-s.xyz;float b=dot(p,d),h=b*b-dot(p,p)+s.w*s.w;
    if(h<0.0)return;
    float hit=-b-sqrt(h);
    if(hit>=0.0 && hit<nearest){nearest=hit;along=t;}
}
bool frontInterface(vec2 q,out vec3 p,out float along) {
    vec3 o=vec3(q,3.0),d=vec3(0,0,-1);float nearest=100.0;along=0.0;
    for(int i=0;i<8;i++) {
        float t=float(i)/8.0;
        vec4 a=curve(t),b=curve(t+0.125);
        sphereHit(o,d,a,nearest,along,t);
        vec3 axis=b.xyz-a.xyz;float len=length(axis);axis/=max(len,0.00001);
        vec3 offset=o-a.xyz;float oy=dot(offset,axis),dy=dot(d,axis),s=(b.w-a.w)/max(len,0.00001);
        vec3 ov=offset-axis*oy,dv=d-axis*dy;float radius=a.w+s*oy;
        float aa=dot(dv,dv)-s*s*dy*dy,bb=dot(dv,ov)-radius*s*dy,cc=dot(ov,ov)-radius*radius;
        float h=bb*bb-aa*cc;
        if(h>=0.0 && abs(aa)>0.00001) {
            float hit=(-bb-sqrt(h))/aa, y=oy+hit*dy;
            if(hit>=0.0 && y>=0.0 && y<=len && hit<nearest){nearest=hit;along=t+y/len*.125;}
        }
    }
    sphereHit(o,d,curve3,nearest,along,1.0);p=o+d*nearest;
    return nearest<99.0;
}
float backInterface(vec3 p,vec3 d) {
    float inside=0.0,outside=0.005;
    for(int i=0;i<12;i++){
        float f=field(p+d*outside);if(f>0.0)break;
        inside=outside;outside+=max(0.003,-f*.8);
    }
    for(int i=0;i<3;i++){
        float middle=(inside+outside)*.5;
        if(field(p+d*middle)<=0.0)inside=middle;else outside=middle;
    }
    return (inside+outside)*.5;
}
float boxLight(vec3 direction, vec3 axis, vec2 size) {
    axis=normalize(axis);
    vec3 horizontal=normalize(cross(vec3(0.0,1.0,0.0),axis));
    vec3 vertical=cross(axis,horizontal);
    float facing=dot(direction,axis);
    vec2 uv=vec2(dot(direction,horizontal),dot(direction,vertical))/max(0.001,facing);
    vec2 edge=abs(uv)-size;
    float distance=max(edge.x,edge.y);
    return (1.0-smoothstep(-0.045,0.055,distance))*step(0.0,facing);
}
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float ovalLight(vec3 direction, vec3 axis, vec2 size) {
    axis=normalize(axis);
    vec3 horizontal=normalize(cross(vec3(0.0,1.0,0.0),axis));
    vec3 vertical=cross(axis,horizontal);
    float facing=dot(direction,axis);
    vec2 uv=vec2(dot(direction,horizontal),dot(direction,vertical))/max(0.001,facing);
    uv/=size;
    return exp(-dot(uv,uv)*2.0)*step(0.0,facing);
}
vec3 environment(vec3 direction, vec3 hue) {
    direction=normalize(direction);
    // Private procedural light rig: no wallpaper/window/desktop texture.
    float rotation=motion.x*0.10;
    direction.xz=mat2(cos(rotation),-sin(rotation),sin(rotation),cos(rotation))*direction.xz;
    vec3 sky=vec3(0.003,0.006,0.016)+hue*(0.020+0.060*pow(1.0-abs(direction.y),3.0));
    vec2 uv=vec2(atan(direction.x,direction.z)*9.0,(direction.y+0.35)*17.0);
    vec2 cell=floor(uv), local=abs(fract(uv)-0.5);
    vec2 aa=max(fwidth(uv),vec2(0.025));
    float windows=(1.0-smoothstep(0.17-aa.x,0.17+aa.x,local.x))
        *(1.0-smoothstep(0.29-aa.y,0.29+aa.y,local.y));
    windows*=step(0.68,hash(cell))*smoothstep(-0.28,0.08,direction.y)
        *(1.0-smoothstep(0.62,0.82,direction.y));
    vec3 white=mix(pow(specular.rgb/max(specular.a,0.001),vec3(2.2)),vec3(1.0),0.28);
    vec3 waterLight=vec3(hue.r,sqrt(hue.g*max(hue.g,hue.b)),hue.b);
    sky+=mix(hue,white,0.24)*windows*(rendering.x>1.5 ? 4.0 : rendering.x>0.5 ? 1.8 : 0.0);
    // Broad colored illumination surrounds the narrow white light catches.
    // The tint follows the material: blue gains a cyan edge, warm palettes
    // retain their amber light instead of receiving a fixed blue overlay.
    sky+=waterLight*ovalLight(direction,vec3(-1.0,0.45,-0.25),vec2(0.15,0.75))*26.0;
    sky+=waterLight*ovalLight(direction,vec3(1.0,0.70,-0.32),vec2(0.22,0.37))*28.0;
    sky+=white*ovalLight(direction,vec3(-1.0,0.45,-0.25),vec2(0.065,0.65))*100.0;
    sky+=white*ovalLight(direction,vec3(1.0,0.70,-0.32),vec2(0.12,0.25))*125.0;
    if (rendering.x>0.5) {
        sky+=white*ovalLight(direction,vec3(-0.75,0.67,0.40),vec2(0.045,0.11))*55.0;
        sky+=white*ovalLight(direction,vec3(0.90,0.18,0.45),vec2(0.08,0.15))*110.0;
        sky+=white*ovalLight(direction,vec3(0.72,0.72,0.40),vec2(0.055,0.10))*65.0;
    }
    sky+=white*ovalLight(direction,vec3(-0.25,1.0,-0.30),vec2(0.18,0.10))*55.0;
    sky+=hue*boxLight(direction,vec3(0.1,-0.8,0.6),vec2(0.70,0.06))*8.0;
    return sky;
}
float fresnel(float cosine) {
    float ior=optics.y>1.5 && optics.y<2.5 ? 1.376 : 1.333;
    float f0=pow((ior-1.0)/(ior+1.0),2.0);
    return f0+(1.0-f0)*pow(1.0-clamp(cosine,0.0,1.0),5.0);
}

vec3 film(vec3 color) {
    color*=1.25;
    // Compress light energy together, preserving the live panel hue instead
    // of desaturating each RGB channel into an unrelated cyan material.
    float peak=max(max(color.r,color.g),max(color.b,0.00001));
    float mapped=(peak*(2.51*peak+0.03))/(peak*(2.43*peak+0.59)+0.14);
    vec3 luminous=(color*(2.51*color+0.03))/(color*(2.43*color+0.59)+0.14);
    vec3 compressed=mix(color/peak*mapped,luminous,smoothstep(0.55,2.0,peak));
    return pow(clamp(compressed,0.0,1.0),vec3(1.0/2.2));
}

void main() {
    vec2 q=vec2(bounds.x+qt_TexCoord0.x*bounds.z,bounds.y+(1.0-qt_TexCoord0.y)*bounds.w);
    vec3 surface;float along;
    if(!frontInterface(q,surface,along)){fragColor=vec4(0);return;}
    vec3 n=normalAt(surface),incident=vec3(0,0,-1);
    vec3 hue=pow(accent.rgb/max(accent.a,.001),vec3(2.2));
    vec3 white=mix(pow(specular.rgb/max(specular.a,.001),vec3(2.2)),vec3(1),.28);
    vec3 internal=refract(incident,n,1.0/1.333);float travel=backInterface(surface,internal);
    vec3 exitNormal=normalAt(surface+internal*travel),outgoing=refract(internal,-exitNormal,1.333);
    if(dot(outgoing,outgoing)<.001)outgoing=reflect(internal,-exitNormal);
    float f=fresnel(n.z);
    vec3 transmitted=environment(outgoing,hue);transmitted/=1.0+max(max(transmitted.r,transmitted.g),transmitted.b)*.35;
    transmitted*=exp(-((vec3(1)-hue)*1.35+.025)*travel)*.32;
    vec3 color=environment(reflect(incident,n),hue)*f+transmitted*(1.0-f);
    color+=hue*(.42+pow(1.0-clamp(n.z,0.0,1.0),2.6)*1.2);
    // Shallow concave cups are distributed at the same four Blender curve
    // coordinates. Normal-dependent visibility prevents painted flat dots.
    float cups=0.0;
    for(int i=0;i<4;i++) {
        float t=.32+float(i)*.15;
        float u=(along-t)*48.0;
        float v=n.x*2.4;
        float bowl=length(vec2(u,v));
        float visible=smoothstep(.3,.75,n.z);
        cups=max(cups,(1.0-smoothstep(.75,1.05,bowl))*visible);
        color+=white*exp(-pow((bowl-.8)*12.0,2.0))*.28*visible;
    }
    color=mix(color,mix(hue*.12,vec3(.16,.045,.25),.40),cups*.72);
    // A front tentacle completely occludes the one behind it. Glass lighting
    // belongs to the surface; body translucency must not reveal stacked arms.
    float alpha=1.0;
    alpha*=smoothstep(0.0,max(.025,fwidth(n.z)*.8),n.z);
    fragColor=vec4(film(color)*alpha,alpha)*qt_Opacity;
}
