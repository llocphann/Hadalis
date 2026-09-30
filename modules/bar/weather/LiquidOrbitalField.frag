#version 440

// One continuously deforming liquid field, evaluated at display resolution.
// The ellipse, its eight pods and their soft joins share a single SDF so no
// overlapping transparent blobs can expose seams. Angular waves change both
// the outer contour and the necks between pods; independent internal waves
// create refractive folds and moving caustics.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 fieldSize;
    vec2 orbitRadii;
    vec4 nodesX0;
    vec4 nodesX1;
    vec4 nodesY0;
    vec4 nodesY1;
    vec4 bodyInk;
    vec4 accentInk;
    vec4 deepInk;
    vec4 glintInk;
    float seconds;
    float regularRadius;
    int selectedIndex;
    int nodeCount;
} u;

float softUnion(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

vec2 nodeCentre(int index) {
    if (index < 4)
        return vec2(u.nodesX0[index], u.nodesY0[index]);
    return vec2(u.nodesX1[index - 4], u.nodesY1[index - 4]);
}

void main() {
    if (u.nodeCount < 2 || u.fieldSize.x < 1.0 || u.fieldSize.y < 1.0) {
        fragColor = vec4(0.0);
        return;
    }

    vec2 p = qt_TexCoord0 * u.fieldSize;
    vec2 origin = u.fieldSize * 0.5;
    vec2 radii = max(u.orbitRadii, vec2(1.0));
    vec2 q = (p - origin) / radii;
    float theta = atan(q.y, q.x);
    float radial = (length(q) - 1.0) * min(radii.x, radii.y);
    float scale = u.regularRadius / 24.0;
    float phase = u.seconds;

    // Three incommensurate waves keep the perimeter from merely rotating as
    // one rigid sinusoid. Neck width changes independently of its centreline.
    float displacement = scale * (
        2.7 * sin(theta * 8.0 - phase * 0.72)
        + 1.9 * sin(theta * 15.0 + phase * 0.94)
        + 0.9 * sin(theta * 27.0 - phase * 1.31));
    float neck = u.regularRadius * (
        0.39 + 0.075 * sin(theta * 8.0 + phase * 0.83)
        + 0.052 * sin(theta * 13.0 - phase * 1.16));
    float ringDistance = abs(radial - displacement) - neck;

    float fieldDistance = ringDistance;
    float nearestPod = 1e6;
    float activePod = 1e6;
    float activeRadius = u.regularRadius * 1.28;
    for (int i = 0; i < 8; ++i) {
        if (i >= u.nodeCount)
            break;
        float radius = u.regularRadius * (i == u.selectedIndex ? 1.28 : 1.0);
        radius += sin(phase * 0.79 + float(i) * 1.47)
            * (i == u.selectedIndex ? 1.25 : 0.55);
        float d = length(p - nodeCentre(i)) - radius;
        nearestPod = min(nearestPod, d);
        if (i == u.selectedIndex) {
            activePod = d;
            activeRadius = radius;
        }
        fieldDistance = softUnion(fieldDistance, d,
            u.regularRadius * 0.50);
    }

    float pixel = max(0.9, fwidth(fieldDistance));
    float fieldCover = 1.0 - smoothstep(-pixel, pixel, fieldDistance);
    float podCover = 1.0 - smoothstep(-pixel, pixel, nearestPod);
    float edge = exp(-abs(fieldDistance) / max(2.0, u.regularRadius * 0.085));
    float podEdge = exp(-abs(nearestPod) / max(2.0, u.regularRadius * 0.11));

    // The membrane has two flowing depths: dark channels carry through each
    // segment while thin blue-white crests curl across them. Both fields move
    // independently of the mass silhouette and of each other.
    float bridge = smoothstep(2.0, u.regularRadius * 0.95, nearestPod);
    float foldPhase = theta * 13.0 - phase * 0.71
        + radial * 0.115 + 1.3 * sin(theta * 5.0 + phase * 0.38);
    float brightFold = pow(max(0.0, sin(foldPhase)), 5.0) * bridge;
    float darkFold = pow(max(0.0, sin(foldPhase * 0.67 + 1.8)), 3.0)
        * bridge;
    float fineCaustic = pow(max(0.0,
        sin(theta * 28.0 + phase * 1.17 - radial * 0.21)), 10.0)
        * bridge;
    vec2 normal = normalize(vec2(dFdx(fieldDistance),
        dFdy(fieldDistance)) + vec2(0.0001));
    float facing = clamp(dot(normal, normalize(vec2(-0.55, -0.83))), 0.0, 1.0);

    vec3 membrane = mix(u.bodyInk.rgb, u.accentInk.rgb,
        clamp(0.32 + 0.19 * facing + 0.18 * brightFold
            + 0.22 * edge, 0.0, 1.0));
    membrane = mix(membrane, u.glintInk.rgb,
        clamp(0.25 * edge + 0.30 * brightFold
            + 0.18 * fineCaustic, 0.0, 0.75));
    membrane = mix(membrane, u.deepInk.rgb, 0.29 * darkFold);
    float membraneAlpha = fieldCover * (
        0.28 + 0.29 * edge + 0.12 * brightFold
        + 0.08 * fineCaustic + 0.06 * facing);
    membraneAlpha *= 1.0 - 0.34 * darkFold;

    // Each forecast pod is a separate glass volume inside the same field.
    // Its rim catches light while its centre remains dark and translucent.
    float selectedPodWeight = activePod <= nearestPod + 0.25 ? 1.0 : 0.0;
    vec3 pod = mix(u.deepInk.rgb, u.accentInk.rgb,
        clamp(0.11 + 0.64 * podEdge + 0.16 * facing
            + selectedPodWeight * 0.10, 0.0, 1.0));
    pod = mix(pod, u.glintInk.rgb,
        clamp(podEdge * (0.16 + selectedPodWeight * 0.20), 0.0, 0.48));
    float podAlpha = podCover * (
        0.59 + 0.20 * podEdge + selectedPodWeight * 0.06);

    vec3 premul = membrane * membraneAlpha * (1.0 - podAlpha)
        + pod * podAlpha;
    float alpha = membraneAlpha * (1.0 - podAlpha) + podAlpha;

    // A soft local bloom sits behind the selected pod and fades into the
    // backdrop instead of filling its glass centre with a flat accent colour.
    float halo = exp(-pow(max(activePod, 0.0)
        / max(1.0, activeRadius * 0.52), 2.0)) * 0.18;
    halo *= 1.0 - podCover;
    premul += u.accentInk.rgb * halo * (1.0 - alpha);
    alpha += halo * (1.0 - alpha);

    fragColor = vec4(premul, alpha) * u.qt_Opacity;
}
