#version 440
// Procedural glass. Bounded 6x8 contour: rounded belly and swept soft tip.
layout(location=0) in vec2 qt_TexCoord0;
layout(location=0) out vec4 fragColor;
layout(std140,binding=0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 accent;
    vec4 specular;
    vec4 motion; // shimmer, tip bend, pulse, effects gate
};
vec2 cubic(vec2 a, vec2 b, vec2 c, vec2 d, float t) {
    float u=1.0-t;
    return u*u*u*a+3.0*u*u*t*b+3.0*u*t*t*c+t*t*t*d;
}
void edge(vec2 p, vec2 a, vec2 b, inout float distance2, inout float side) {
    vec2 ab=b-a, ap=p-a;
    vec2 q=ap-ab*clamp(dot(ap,ab)/max(dot(ab,ab),0.000001),0.0,1.0);
    distance2=min(distance2,dot(q,q));
    if ((a.y>p.y)!=(b.y>p.y)) {
        if (p.x<(b.x-a.x)*(p.y-a.y)/(b.y-a.y)+a.x) side=-side;
    }
}
void curve(vec2 p, vec2 a, vec2 b, vec2 c, vec2 d, inout float dist, inout float side) {
    vec2 previous=a;
    for (int i=1;i<=8;i++) {
        vec2 next=cubic(a,b,c,d,float(i)/8.0);
        edge(p,previous,next,dist,side);
        previous=next;
    }
}
float silhouette(vec2 p) {
    float d=10.0, side=1.0;
    vec2 tip=vec2(0.54+motion.y*0.025,0.08);
    curve(p,tip,vec2(0.61,0.24),vec2(0.26,0.26),vec2(0.14,0.46),d,side);
    curve(p,vec2(0.14,0.46),vec2(-0.015,0.60),vec2(-0.015,0.84),vec2(0.15,0.90),d,side);
    curve(p,vec2(0.15,0.90),vec2(0.31,0.992),vec2(0.74,0.992),vec2(0.865,0.88),d,side);
    curve(p,vec2(0.865,0.88),vec2(1.025,0.77),vec2(0.99,0.57),vec2(0.80,0.395),d,side);
    curve(p,vec2(0.80,0.395),vec2(0.68,0.29),vec2(0.68,0.19),vec2(0.60,0.11),d,side);
    curve(p,vec2(0.60,0.11),vec2(0.565,0.055),vec2(0.52,0.04),tip,d,side);
    return sqrt(d)*side;
}
float spot(vec2 p, vec2 center, vec2 radius) {
    vec2 q=(p-center)/radius;
    return exp(-dot(q,q)*2.0);
}
void main() {
    vec2 p=qt_TexCoord0;
    float d=silhouette(p);
    float aa=max(fwidth(d)*0.65,0.0015);
    float cover=1.0-smoothstep(-aa,aa,d);
    vec3 hue=accent.rgb/max(accent.a,0.001);
    vec3 light=mix(specular.rgb/max(specular.a,0.001),vec3(0.93,0.99,1.0),0.55);
    vec3 cyan=mix(hue,vec3(0.12,0.92,1.0),0.32);
    vec3 glass=mix(hue*0.20,hue*0.70,smoothstep(0.12,0.75,p.y));
    float core=spot(p,vec2(0.49,0.82),vec2(0.48,0.36));
    glass=mix(glass,mix(cyan,light,0.63),core*0.96);
    vec2 sphere=(p-vec2(0.5,0.67))/vec2(0.43,0.34);
    float z=sqrt(max(0.0,1.0-dot(sphere,sphere)));
    vec3 normal=normalize(vec3(sphere,z+0.15));
    float softLight=max(0.0,dot(normal,normalize(vec3(-0.6,-0.5,0.8))));
    glass*=0.8+softLight*0.40;
    float depth=clamp(-d/0.18,0.0,1.0);
    float rim=exp(-abs(d)*100.0);
    float inner=exp(-abs(d+0.027)*74.0);
    glass+=cyan*inner*0.35+light*rim*0.8;
    float drift=motion.x*0.008;
    float left=spot(p,vec2(0.205+drift,0.49),vec2(0.040,0.17));
    float right=spot(p,vec2(0.795,0.47+drift),vec2(0.044,0.115));
    float rightCatch=spot(p,vec2(0.75,0.36),vec2(0.027,0.040));
    float tipLight=spot(p,vec2(0.55,0.16),vec2(0.022,0.085));
    float base=spot(p,vec2(0.49,0.91),vec2(0.31,0.023));
    glass=mix(glass,light,clamp(left*0.88+right*0.88+rightCatch*0.90+tipLight*0.78,0.0,1.0));
    glass+=cyan*base*0.65;
    glass+=mix(hue,vec3(0.72,0.48,1.0),0.35)*spot(p,vec2(0.75,0.82),vec2(0.06,0.055))*0.25;
    // Sparse internal glints, no textures or wallpaper/window capture.
    if (motion.w>0.5) {
        for (int i=0;i<7;i++) {
            float n=float(i);
            vec2 c=vec2(0.30+0.37*fract(n*0.618),0.34+0.29*fract(n*0.381));
            c.y-=motion.x*0.025;
            glass+=cyan*spot(p,c,vec2(0.006))*0.33;
        }
    }
    float alpha=cover*(0.90+depth*0.08);
    vec4 body=vec4(clamp(glass,0.0,1.0)*alpha,alpha);
    float halo=exp(-max(d,0.0)*65.0)*(1.0-cover)*0.10*motion.w*(1.0+motion.z);
    fragColor=(body+vec4(hue*halo,halo))*qt_Opacity;
}
