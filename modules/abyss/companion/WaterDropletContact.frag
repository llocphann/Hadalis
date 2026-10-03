#version 440
layout(location=0) in vec2 qt_TexCoord0;
layout(location=0) out vec4 fragColor;
layout(std140,binding=0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 accent;
    vec4 specular;
    vec4 motion;
    vec4 feet; // projected camera-facing foot contacts in this surface
};
layout(binding=1) uniform sampler2D surfaceSource;
void main() {
    vec2 uv=qt_TexCoord0;
    vec2 disc=(uv-0.5)*2.0;
    float radius=length(disc);
    float mask=1.0-smoothstep(0.88,1.0,radius);
    float ripple=sin(radius*23.0-motion.x*3.0)*motion.y*0.012;
    // Mirror the complete Wull layer about its feet. Perspective compresses
    // the image into the front half of the puddle and fades it with distance.
    vec2 reflectedUV=vec2((uv.x-0.5)*motion.z+0.5+ripple,
        0.865-max(0.0,uv.y-0.48)*1.55+ripple*0.30);
    vec4 reflection=texture(surfaceSource,reflectedUV)*0.50;
    reflection+=texture(surfaceSource,reflectedUV+vec2(0.008,0.018))*0.25;
    reflection+=texture(surfaceSource,reflectedUV-vec2(0.008,0.018))*0.25;
    reflection*=step(0.0,reflectedUV.x)*step(reflectedUV.x,1.0)
        *step(0.0,reflectedUV.y)*step(reflectedUV.y,1.0);
    float opacity=mask*smoothstep(0.44,0.53,uv.y)*exp(-max(0.0,uv.y-0.49)*6.2)*0.78;
    vec3 hue=accent.rgb/max(accent.a,0.001);
    vec3 light=specular.rgb/max(specular.a,0.001);
    float angle=atan(disc.y,disc.x);
    float wave=sin(angle*4.0+motion.x)*0.012;
    float caustic=exp(-pow((radius-0.51-wave)/0.023,2.0))*1.10
        +exp(-pow((radius-0.74+wave)/0.025,2.0))*0.55
        +exp(-pow((radius-0.90-wave)/0.020,2.0))*0.28;
    float glow=exp(-pow((radius-0.51-wave)/0.085,2.0))*0.24
        +exp(-pow((radius-0.74+wave)/0.065,2.0))*0.12;
    caustic=clamp((caustic+glow)*mask*(0.68+0.32*cos(angle*3.0+motion.x)),0.0,1.0);
    vec4 rings=vec4(mix(hue,light,0.50)*caustic,caustic);
    vec2 leftContact=(uv-vec2(feet.x,0.51))/vec2(0.065,0.060);
    vec2 rightContact=(uv-vec2(feet.y,0.51))/vec2(0.065,0.060);
    float contact=(exp(-dot(leftContact,leftContact)*1.8)
        +exp(-dot(rightContact,rightContact)*1.8))*0.72*mask;
    vec4 contactLight=vec4(mix(hue,light,0.72)*contact,contact);
    float haze=exp(-dot(disc/vec2(0.68,0.58),disc/vec2(0.68,0.58))*2.0)*0.11;
    vec4 floorGlow=vec4(hue*haze,haze);
    vec4 surface=reflection*opacity+floorGlow*(1.0-reflection.a*opacity);
    surface=contactLight+surface*(1.0-contactLight.a);
    fragColor=(rings+surface*(1.0-rings.a))*qt_Opacity;
}
