#version 440
layout(location=0) in vec2 qt_TexCoord0;
layout(location=0) out vec4 fragColor;
layout(std140,binding=0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 accent;
    vec4 specular;
    vec4 motion;
};
layout(binding=1) uniform sampler2D surfaceSource;
void main() {
    vec2 uv=qt_TexCoord0;
    vec2 disc=(uv-0.5)*2.0;
    float radius=length(disc);
    float mask=1.0-smoothstep(0.88,1.0,radius);
    float ripple=sin(radius*23.0-motion.x*3.0)*motion.y*0.012;
    vec2 reflectedUV=vec2((uv.x-0.5)*motion.z+0.5+ripple,0.91-uv.y*0.80);
    vec4 reflection=texture(surfaceSource,reflectedUV)*0.50;
    reflection+=texture(surfaceSource,reflectedUV+vec2(0.008,0.018))*0.25;
    reflection+=texture(surfaceSource,reflectedUV-vec2(0.008,0.018))*0.25;
    reflection*=step(0.0,reflectedUV.x)*step(reflectedUV.x,1.0);
    float opacity=mask*exp(-uv.y*2.8)*0.62;
    vec3 hue=accent.rgb/max(accent.a,0.001);
    vec3 light=specular.rgb/max(specular.a,0.001);
    float angle=atan(disc.y,disc.x);
    float wave=sin(angle*4.0+motion.x)*0.012;
    float caustic=exp(-pow((radius-0.51-wave)/0.023,2.0))*1.10
        +exp(-pow((radius-0.74+wave)/0.025,2.0))*0.55
        +exp(-pow((radius-0.90-wave)/0.020,2.0))*0.28;
    float glow=exp(-pow((radius-0.51-wave)/0.085,2.0))*0.24
        +exp(-pow((radius-0.74+wave)/0.065,2.0))*0.12;
    caustic=clamp((caustic+glow)*mask*(0.75+0.25*cos(angle*3.0+motion.x)),0.0,1.0);
    vec4 rings=vec4(mix(hue,light,0.50)*caustic,caustic);
    fragColor=(rings+reflection*opacity*(1.0-caustic))*qt_Opacity;
}
