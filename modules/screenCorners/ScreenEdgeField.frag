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
        fragColor = u.frameColor * u.qt_Opacity;
        return;
    }

    vec2 p = qt_TexCoord0 * size;

    // Exact deep-interior reject. A rounded rectangle differs from its axis
    // box only inside the four radius corner squares. Once a fragment is both
    // farther than the complete shadow reach from every straight side and in
    // either central rectangle, its signed distance is guaranteed below the
    // visible AA/shadow band. Most workspace pixels therefore skip length(),
    // derivatives and smoothstep work entirely.
    float clampedRadius = min(max(u.params.x, 0.0),
        min(halfSize.x, halfSize.y));
    float safeReach = max(max(u.params.y, 0.0), 2.0);
    bool axisDeep =
        p.x >= lo.x + safeReach && p.x <= hi.x - safeReach
        && p.y >= lo.y + safeReach && p.y <= hi.y - safeReach;
    bool centralCore =
        (p.x >= lo.x + clampedRadius && p.x <= hi.x - clampedRadius)
        || (p.y >= lo.y + clampedRadius && p.y <= hi.y - clampedRadius);
    if (axisDeep && centralCore) {
        fragColor = vec4(0.0);
        return;
    }

    float d = roundedBox(p, centre, halfSize, clampedRadius);

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

    // ShaderEffect passes QColor uniforms already premultiplied. Apply only
    // coverage here; multiplying by color alpha again would square the shadow
    // opacity and visibly weaken the elevation.
    vec3 frameRgb = u.frameColor.rgb * frameCover;
    float frameAlpha = u.frameColor.a * frameCover;
    vec3 shadowRgb = u.shadowColor.rgb * innerShadow;
    float shadowAlpha = u.shadowColor.a * innerShadow;
    float remaining = 1.0 - frameAlpha;
    vec3 rgb = frameRgb + shadowRgb * remaining;
    float alpha = frameAlpha + shadowAlpha * remaining;

    fragColor = vec4(rgb, alpha) * u.qt_Opacity;
}
