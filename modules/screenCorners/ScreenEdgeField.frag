#version 440

// Single-pass physical Screen Edge field.
//
// The output-local window itself is the outer frame bound. The rounded
// workspace opening is one signed-distance field: pixels outside the opening
// paint the physical frame, while pixels just inside it receive the inward
// elevation falloff. This replaces Shape -> offscreen layer -> blur chain ->
// MultiEffect composite with one texture-free fragment pass.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 viewport;    // width, height, 0, 0
    vec4 insets;      // left, top, right, bottom
    vec4 frameColor;
    vec4 shadowColor;
    vec4 params;      // radius, shadow reach, minimum AA width, reserved
} u;

float roundedBox(vec2 p, vec2 centre, vec2 halfSize, float radius) {
    float r = min(max(radius, 0.0), min(halfSize.x, halfSize.y));
    vec2 q = abs(p - centre) - (halfSize - vec2(r));
    return length(max(q, vec2(0.0)))
        + min(max(q.x, q.y), 0.0) - r;
}

void main() {
    vec2 size = max(u.viewport.xy, vec2(1.0));
    vec2 lo = max(u.insets.xy, vec2(0.0));
    vec2 hi = max(lo, size - max(u.insets.zw, vec2(0.0)));
    vec2 halfSize = max((hi - lo) * 0.5, vec2(0.0));
    vec2 centre = (lo + hi) * 0.5;

    if (halfSize.x <= 0.0 || halfSize.y <= 0.0) {
        float alpha = u.frameColor.a;
        fragColor = vec4(u.frameColor.rgb * alpha, alpha) * u.qt_Opacity;
        return;
    }

    vec2 p = qt_TexCoord0 * size;
    float d = roundedBox(p, centre, halfSize, u.params.x);

    // Positive distance is physical frame, negative distance is workspace.
    // Curve/GeometryRenderer differences disappear here: the silhouette AA is
    // derived directly from the SDF at output resolution.
    float aa = max(max(fwidth(d), u.params.z), 0.5);
    float frameCover = smoothstep(-aa, aa, d);

    // Only the workspace-facing side needs elevation. Squaring the smoothstep
    // gives the same restrained near-edge emphasis as Qt's analytic
    // RectangularShadow family without a Gaussian texture pyramid.
    float reach = max(u.params.y, aa);
    float innerShadow = smoothstep(-reach, 0.0, d)
        * (1.0 - frameCover);
    innerShadow *= innerShadow;

    float frameAlpha = u.frameColor.a * frameCover;
    float shadowAlpha = u.shadowColor.a * innerShadow;
    float remaining = 1.0 - frameAlpha;
    vec3 rgb = u.frameColor.rgb * frameAlpha
        + u.shadowColor.rgb * shadowAlpha * remaining;
    float alpha = frameAlpha + shadowAlpha * remaining;

    fragColor = vec4(rgb, alpha) * u.qt_Opacity;
}
