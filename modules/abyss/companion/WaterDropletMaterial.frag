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
};
const float BOTTOM=-0.87, TOP=0.99, DEPTH=0.91;
float verticalScale() { return optics.y>2.5 ? 0.40 : 1.0; }
float depthScale() { return optics.y>2.5 ? 0.55 : DEPTH; }
float radiusAt(float y) {
    if (optics.y>0.5) {
        y/=verticalScale();
        return sqrt(max(0.0,0.89*0.89-y*y));
    }
    if (y<BOTTOM || y>TOP) return 0.0;
    if (y<-0.23) {
        float t=(y+0.23)/0.64;
        return 0.93*sqrt(max(0.0,1.0-t*t));
    }
    float t=clamp((y+0.23)/1.22,0.0,1.0);
    // Both shoulders narrow evenly into one centered point. The finite
    // slope at the apex avoids the former curled, blunt cap; the belly
    // retains its smooth tangent and near 1:1 overall proportions.
    return 0.93*(1.0-t*t)*(1.0-0.15*smoothstep(0.50,1.0,t));
}
float centerAt(float y) {
    if (optics.y>0.5) return 0.0;
    float t=clamp((y-BOTTOM)/(TOP-BOTTOM),0.0,1.0);
    // No permanent sideways sweep. State-driven tip motion is subpixel at
    // the native size, so the pointed shape remains balanced while alive.
    return clamp(motion.y,-1.0,1.0)*0.008*t*t*t;
}
vec3 modelPoint(vec3 p) {
    float c=cos(optics.x), s=sin(optics.x);
    return vec3(c*p.x-s*p.z,p.y,s*p.x+c*p.z);
}
vec3 worldVector(vec3 p) {
    float c=cos(optics.x), s=sin(optics.x);
    return vec3(c*p.x+s*p.z,p.y,-s*p.x+c*p.z);
}
float field(vec3 world) {
    vec3 p=modelPoint(world);
    float radial=length(vec2(p.x-centerAt(p.y),p.z/depthScale()))-radiusAt(p.y);
    float low=optics.y>0.5 ? -0.89*verticalScale() : BOTTOM;
    float high=optics.y>0.5 ? 0.89*verticalScale() : TOP;
    return max(radial,max(low-p.y,p.y-high));
}
vec3 normalAt(vec3 world) {
    vec3 p=modelPoint(world);
    float r=radiusAt(p.y), x=p.x-centerAt(p.y);
    float dr=(radiusAt(p.y+0.002)-radiusAt(p.y-0.002))/0.004;
    float dc=(centerAt(p.y+0.002)-centerAt(p.y-0.002))/0.004;
    float depth=depthScale();
    vec3 n=vec3(x,-x*dc-r*dr,p.z/(depth*depth));
    return normalize(worldVector(n)+vec3(0.0,0.000001,0.0));
}
float backInterface(vec3 entry, vec3 direction) {
    float inside=0.0, outside=0.018;
    int steps=rendering.x>1.5 ? 28 : rendering.x>0.5 ? 18 : 10;
    for (int i=0;i<28;i++) {
        if (i>=steps) break;
        float d=field(entry+direction*outside);
        if (d>0.0) break;
        inside=outside;
        outside+=max(0.014,-d*0.85);
    }
    int refinements=rendering.x>1.5 ? 7 : rendering.x>0.5 ? 5 : 3;
    for (int i=0;i<7;i++) {
        if (i>=refinements) break;
        float middle=(inside+outside)*0.5;
        if (field(entry+direction*middle)<0.0) inside=middle;
        else outside=middle;
    }
    return max(0.002,(inside+outside)*0.5);
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

vec3 softTransmission(vec3 direction, vec3 hue) {
    vec3 light=environment(direction,hue);
    // Compress transmitted HDR energy as a whole, retaining colored window
    // detail. Independent channel clipping produced the old opaque gray fill.
    float peak=max(max(light.r,light.g),light.b);
    return light/(1.0+peak*0.35);
}

vec3 mediumLight(vec3 entry, vec3 internal, float travel, vec3 exitNormal,
                 float ior, vec3 hue, bool secondInterface) {
    vec3 exitPoint=entry+internal*travel;
    vec3 outgoing=refract(internal,-exitNormal,ior);
    bool totalReflection=dot(outgoing,outgoing)<0.001;
    float backF=totalReflection ? 1.0 : fresnel(abs(dot(internal,exitNormal)));
    vec3 extinction=(vec3(1.0)-hue)*1.35+vec3(0.025);
    vec3 light=totalReflection ? vec3(0.0)
        : softTransmission(outgoing,hue)*exp(-extinction*travel)*(1.0-backF);
    if (secondInterface || totalReflection) {
        // Trace one bounded internal bounce. This creates a real second
        // optical path through the curved volume, including total reflection.
        vec3 bounced=reflect(internal,-exitNormal);
        vec3 bounceStart=exitPoint+bounced*0.006;
        float bounceTravel=backInterface(bounceStart,bounced);
        vec3 bounceNormal=normalAt(bounceStart+bounced*bounceTravel);
        vec3 escaped=refract(bounced,-bounceNormal,ior);
        if (dot(escaped,escaped)>0.001)
            light+=softTransmission(escaped,hue)*exp(-extinction*(travel+bounceTravel))*backF;
    }
    return light;
}

vec3 dispersedLight(vec3 surface, vec3 normal, float ior, vec3 hue) {
    vec3 internal=refract(vec3(0.0,0.0,-1.0),normal,1.0/ior);
    float travel=backInterface(surface,internal);
    return mediumLight(surface,internal,travel,normalAt(surface+internal*travel),ior,hue,false);
}

float liquidFocus(vec3 p) {
    float flow=motion.x*0.45;
    float ridge=sin(p.x*14.0+p.y*5.0+sin(p.z*9.0+flow))
        +cos(p.z*13.0-p.y*7.0+sin(p.x*6.0-flow));
    float envelope=exp(-pow((p.y+0.56)/0.38,2.0));
    return exp(-ridge*ridge*36.0)*envelope;
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
    vec2 q=vec2((qt_TexCoord0.x-0.5)*2.15,(0.515-qt_TexCoord0.y)*2.15);
    q.y*=verticalScale();
    float r=radiusAt(q.y), center=centerAt(q.y);
    float c=cos(optics.x), s=sin(optics.x);
    float depth=depthScale();
    float halfWidth=r*sqrt(c*c+depth*depth*s*s);
    float low=optics.y>0.5 ? -0.89*verticalScale() : BOTTOM;
    float high=optics.y>0.5 ? 0.89*verticalScale() : TOP;
    float d=max(abs(q.x-center*c)-halfWidth,max(low-q.y,q.y-high));
    float aa=max(fwidth(d)*0.65,0.002);
    float cover=1.0-smoothstep(-aa,aa,d);
    vec3 hue=pow(accent.rgb/max(accent.a,0.001),vec3(2.2));
    float halo=exp(-max(d,0.0)*40.0)*(1.0-cover)*0.12*motion.w*(1.0+motion.z);
    if (cover<0.001) {
        fragColor=vec4(pow(hue,vec3(1.0/2.2))*halo,halo)*qt_Opacity;
        return;
    }
    // Ray/ellipse intersection at this height, after actual 3D camera yaw.
    float a=s*s+c*c/(depth*depth);
    float b=2.0*(-s*(q.x*c-center)+c*q.x*s/(depth*depth));
    float e=pow(q.x*c-center,2.0)+pow(q.x*s/depth,2.0)-r*r;
    float z=(-b+sqrt(max(0.0,b*b-4.0*a*e)))/(2.0*a);
    vec3 surface=vec3(q,z), normal=normalAt(surface);
    if (optics.y<0.5 && motion.w>0.5) {
        // A small tangent perturbation bends the reflected light like a
        // settling liquid surface while keeping the round silhouette smooth.
        vec3 p=modelPoint(surface);
        vec3 wave=worldVector(vec3(
            sin(p.y*16.0+p.z*9.0+motion.x*1.7),
            sin(p.x*13.0-p.z*8.0-motion.x*1.3),
            sin(p.x*11.0+p.y*9.0+motion.x*1.1)));
        normal=normalize(normal+(wave-normal*dot(wave,normal))*0.016);
    }
    vec3 incident=vec3(0.0,0.0,-1.0);
    float f=fresnel(normal.z);
    if (optics.y>1.5 && optics.y<2.5) {
        // Glossy dark eye under an implicit convex cornea. Its highlights
        // follow surface normals and the same studio rig as the liquid body.
        vec3 ray=reflect(incident,normal);
        vec3 white=mix(pow(specular.rgb/max(specular.a,0.001),vec3(2.2)),vec3(1.0),0.28);
        vec2 iris=(q-vec2(optics.z*0.26-0.05,optics.w*0.20-0.40))/vec2(0.39,0.23);
        vec3 color=hue*(0.004+exp(-dot(iris,iris)*1.5)*3.2);
        color+=environment(ray,hue)*f*0.12;
        color+=white*ovalLight(ray,vec3(-0.65,0.85,0.60),vec2(0.50,0.45))*f*230.0;
        color+=white*ovalLight(ray,vec3(0.90,-0.40,0.60),vec2(0.13,0.13))*f*110.0;
        color+=hue*ovalLight(ray,vec3(-0.50,-0.60,0.70),vec2(0.20,0.17))*3.0;
        fragColor=vec4(film(color)*cover,cover)*qt_Opacity;
        return;
    }
    vec3 internal=refract(incident,normal,1.0/1.333);
    float travel=backInterface(surface,internal);
    vec3 exitPoint=surface+internal*travel;
    vec3 exitNormal=normalAt(exitPoint);
    vec3 reflected=environment(reflect(incident,normal),hue);
    // The deeper medium absorbs more of the weaker accent channels. Keep the
    // surface illumination pale, with a saturated core beneath the glass.
    vec3 volumeHue=pow(hue,vec3(1.45));
    vec3 through=mediumLight(surface,internal,travel,exitNormal,1.333,volumeHue,rendering.x>1.5);
    if (rendering.x>1.5) {
        // Water's dispersion is small. Separate red/blue exit rays give the
        // rim depth without turning the droplet into a rainbow glass bead.
        through.r=dispersedLight(surface,normal,1.331,volumeHue).r;
        through.b=dispersedLight(surface,normal,1.339,volumeHue).b;
    }
    through*=0.32;
    vec3 middle=modelPoint(surface+internal*travel*0.5);
    vec3 localCore=(middle-vec3(0.0,-0.59,0.0))/vec3(0.80,0.35,1.1);
    float core=exp(-dot(localCore,localCore)*1.4);
    vec3 white=mix(pow(specular.rgb/max(specular.a,0.001),vec3(2.2)),vec3(1.0),0.28);
    vec3 waterLight=vec3(hue.r,sqrt(hue.g*max(hue.g,hue.b)),hue.b);
    through+=volumeHue*(1.0-exp(-travel*0.95))*0.28;
    through*=mix(1.0,0.62,smoothstep(-0.10,0.50,q.y));
    through+=mix(waterLight,white,0.015)*core*(1.45+motion.z*0.25)*(optics.y>0.5 ? 0.15 : 1.0);
    if (rendering.x>0.5 && optics.y<0.5) {
        float focus=liquidFocus(middle);
        if (rendering.x>1.5) {
            focus+=liquidFocus(modelPoint(surface+internal*travel*0.25))*0.55;
            focus+=liquidFocus(modelPoint(surface+internal*travel*0.75))*0.40;
        }
        through+=mix(waterLight,white,0.04)*focus*(1.0-exp(-travel))*0.20;
    }
    if (optics.y>2.5) {
        // Flattened water pods share the body's interfaces and light rig.
        // A shallow luminous core and bottom catch give the tiny feet depth.
        vec3 footCore=middle/vec3(0.85,0.24,0.65);
        through+=mix(waterLight,white,0.06)*exp(-dot(footCore,footCore))*0.95;
        through+=mix(waterLight,white,0.65)*exp(-pow((q.y+0.24)/0.055,2.0))*0.70;
    }
    // Compact approximation of the luminous floor's focusing at the base.
    vec2 leftFocus=(q-vec2(-0.44,-0.74))/vec2(0.13,0.035);
    vec2 rightFocus=(q-vec2(0.44,-0.74))/vec2(0.13,0.035);
    float caustic=exp(-dot(leftFocus,leftFocus)*1.5)+exp(-dot(rightFocus,rightFocus)*1.5);
    through+=mix(waterLight,white,0.50)*caustic*2.2*(optics.y>0.5 ? 0.0 : 1.0);
    vec3 color=reflected*f+through*(1.0-f);
    float grazing=1.0-clamp(normal.z,0.0,1.0);
    color+=waterLight*pow(grazing,2.6)*1.25+white*pow(grazing,5.0)*0.55;
    if (motion.w>0.5 && optics.y<0.5) {
        int candidates=rendering.x>1.5 ? 48 : rendering.x>0.5 ? 18 : 0;
        for (int i=0;i<48;i++) {
            if (i>=candidates) break;
            float index=float(i);
            vec3 bubble=vec3((hash(vec2(index,1.0))-0.5)*1.1,
                -0.48+hash(vec2(index,2.0))*1.08,(hash(vec2(index,3.0))-0.5)*0.8);
            bubble.y+=motion.x*0.018;
            bubble=worldVector(bubble);
            float along=dot(bubble-surface,internal);
            float offset=length(surface+internal*along-bubble);
            float radius=0.007+hash(vec2(index,4.0))*0.018;
            float edge=exp(-abs(offset-radius)*170.0)*step(0.0,along)*step(along,travel);
            float attenuation=exp(-along*0.70);
            color+=mix(waterLight,white,0.25)*edge*0.30*attenuation;
            float glint=exp(-offset*offset/(radius*radius*0.08))
                *step(0.0,along)*step(along,travel);
            color+=mix(waterLight,white,0.20)*glint*0.50*attenuation;
        }
    }
    // Thickness-dependent translucency lets the desktop contribute at thin
    // edges while the illuminated liquid core and bright catches stay dense.
    float opacity=mix(optics.y>0.5 && optics.y<1.5 ? 0.60 : 0.82,
        0.98,clamp(travel*0.55,0.0,1.0));
    opacity*=1.0-clamp(rendering.y,0.0,0.35)*0.55;
    float reflectedPeak=max(reflected.r,max(reflected.g,reflected.b))*f;
    opacity=mix(opacity,0.995,clamp(f*0.80+reflectedPeak*0.20,0.0,1.0));
    float alpha=cover*opacity;
    fragColor=(vec4(film(color)*alpha,alpha)+vec4(pow(hue,vec3(1.0/2.2))*halo,halo))*qt_Opacity;
}
