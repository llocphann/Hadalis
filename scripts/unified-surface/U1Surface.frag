#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float smoothK;
    float frameRadius;
    float popupRadius;
    float workspaceOnly;
    vec4 effectRect;
    vec4 frameOuter;
    vec4 frameInner;
    vec4 popupRect;
    vec4 materialColor;
} ubuf;

float sdBoxRect(vec2 p, vec4 rect) {
    vec2 center = rect.xy + rect.zw * 0.5;
    vec2 halfSize = rect.zw * 0.5;
    vec2 d = abs(p - center) - halfSize;
    return length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0);
}

float sdRoundedRect(vec2 p, vec4 rect, float radius) {
    vec2 center = rect.xy + rect.zw * 0.5;
    vec2 halfSize = rect.zw * 0.5;
    float r = min(max(radius, 0.0), min(halfSize.x, halfSize.y));
    vec2 d = abs(p - center) - halfSize + vec2(r);
    return length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0) - r;
}

// Same corner order as Caelestia BlobRectData: TR, BR, BL, TL.
float sdRoundedRect4(vec2 p, vec4 rect, vec4 radii) {
    vec2 center = rect.xy + rect.zw * 0.5;
    vec2 halfSize = rect.zw * 0.5;
    p -= center;
    radii.xy = (p.x > 0.0) ? radii.xy : radii.wz;
    radii.x = (p.y > 0.0) ? radii.y : radii.x;
    float r = min(max(radii.x, 0.0), min(halfSize.x, halfSize.y));
    vec2 q = abs(p) - halfSize + vec2(r);
    return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - r;
}

float circularSmin(float a, float b, float k) {
    float radius = max(k, 0.001);
    return max(radius, min(a, b))
        - length(max(vec2(radius) - vec2(a, b), vec2(0.0)));
}

float circularSmaxSharpA(float a, float b, float k) {
    float radius = max(k, 0.001);
    float sm = min(-radius, max(a, b))
        + length(max(vec2(a, b) + vec2(radius), vec2(0.0)));
    float blend = (sm - max(a, b))
        * smoothstep(0.0, radius * 0.5, -a);
    return max(a, b) + blend;
}

float cornerFillFactor(vec2 corner, vec4 innerRect, float k) {
    // A corner is squared only while it is near the inner-frame boundary.
    // Deep inside the workspace hole it keeps its full radius. This is the
    // inverted-frame half of Caelestia BlobShape::applyCornerFill().
    float sd = sdBoxRect(corner, innerRect);
    return smoothstep(0.0, max(k, 0.001), -sd);
}

vec4 popupCornerRadii(vec4 popup, vec4 innerRect, float radius, float k) {
    float left = popup.x;
    float top = popup.y;
    float right = popup.x + popup.z;
    float bottom = popup.y + popup.w;
    float base = max(radius, 0.0);
    float minRadius = min(2.0, base);

    float tr = max(base * cornerFillFactor(vec2(right, top), innerRect, k), minRadius);
    float br = max(base * cornerFillFactor(vec2(right, bottom), innerRect, k), minRadius);
    float bl = max(base * cornerFillFactor(vec2(left, bottom), innerRect, k), minRadius);
    float tl = max(base * cornerFillFactor(vec2(left, top), innerRect, k), minRadius);
    return vec4(tr, br, bl, tl);
}

float borderFacingScale(vec2 pixel, vec4 innerRect, vec4 popup, float k) {
    vec2 center = popup.xy + popup.zw * 0.5;
    vec2 halfSize = popup.zw * 0.5;

    float innerLeft = innerRect.x;
    float innerTop = innerRect.y;
    float innerRight = innerRect.x + innerRect.z;
    float innerBottom = innerRect.y + innerRect.w;

    // Match Caelestia's inverted-frame proximity measure. At the normal
    // resting position both relevant distances are >= k, so proximity is zero
    // and the open popup silhouette is unchanged. Compression appears only
    // while the rect is travelling inside/behind an owner border.
    float distY0 = (center.y + halfSize.y) - innerTop;
    float distY1 = innerBottom - (center.y - halfSize.y);
    float distX0 = (center.x + halfSize.x) - innerLeft;
    float distX1 = innerRight - (center.x - halfSize.x);

    float yProx = 1.0 - min(
        smoothstep(0.0, k, distY0),
        smoothstep(0.0, k, distY1)
    );
    float xProx = 1.0 - min(
        smoothstep(0.0, k, distX0),
        smoothstep(0.0, k, distX1)
    );

    // Weight the compression by the local SDF-facing axis. Outside a rounded
    // corner use its gradient; inside/on a face use a smooth face classifier.
    // This avoids an orientation branch at corners.
    vec2 q = abs(pixel - center) - halfSize;
    vec2 qp = max(q, vec2(0.0));
    float cornerLen = length(qp);

    float gradX = qp.x / max(cornerLen, 0.001);
    float gradY = qp.y / max(cornerLen, 0.001);

    float faceY = smoothstep(-4.0, 4.0, q.y - q.x);
    float faceX = 1.0 - faceY;

    float t = smoothstep(0.0, 2.0, cornerLen);
    float xWeight = mix(faceX, gradX, t);
    float yWeight = mix(faceY, gradY, t);

    const float boost = 3.0;
    return 1.0 + (xProx * xWeight + yProx * yWeight) * boost;
}

float frameSink(vec2 pixel, vec4 innerRect, vec4 popup, float k) {
    float innerLeft = innerRect.x;
    float innerTop = innerRect.y;
    float innerRight = innerRect.x + innerRect.z;
    float innerBottom = innerRect.y + innerRect.w;

    float outerLeft = ubuf.frameOuter.x;
    float outerTop = ubuf.frameOuter.y;
    float outerRight = ubuf.frameOuter.x + ubuf.frameOuter.z;
    float outerBottom = ubuf.frameOuter.y + ubuf.frameOuter.w;

    vec2 popupCenter = popup.xy + popup.zw * 0.5;
    vec2 popupHalf = popup.zw * 0.5;

    // Caelestia's circular-union border-sink onset.
    float preOff = k * (2.0 - sqrt(2.0)) * 0.5;

    // Track the opposite popup edge. The sink is generic frame/popup field
    // behavior; it is not a contact-side selector.
    float topPen = clamp(
        innerTop - (popupCenter.y + popupHalf.y) - preOff,
        0.0,
        max(0.0, innerTop - outerTop)
    );
    float bottomPen = clamp(
        (popupCenter.y - popupHalf.y) - innerBottom - preOff,
        0.0,
        max(0.0, outerBottom - innerBottom)
    );
    float leftPen = clamp(
        innerLeft - (popupCenter.x + popupHalf.x) - preOff,
        0.0,
        max(0.0, innerLeft - outerLeft)
    );
    float rightPen = clamp(
        (popupCenter.x - popupHalf.x) - innerRight - preOff,
        0.0,
        max(0.0, outerRight - innerRight)
    );

    float hLat = max(abs(pixel.x - popupCenter.x) - popupHalf.x, 0.0);
    float vLat = max(abs(pixel.y - popupCenter.y) - popupHalf.y, 0.0);

    float topZone = 1.0 - smoothstep(innerTop, innerTop + k, pixel.y);
    float bottomZone = smoothstep(innerBottom - k, innerBottom, pixel.y);
    float leftZone = 1.0 - smoothstep(innerLeft, innerLeft + k, pixel.x);
    float rightZone = smoothstep(innerRight - k, innerRight, pixel.x);

    float lateral = max(k * 2.0, 0.001);
    float hFalloff = 1.0 - smoothstep(0.0, lateral, hLat);
    float vFalloff = 1.0 - smoothstep(0.0, lateral, vLat);

    return max(
        max(topPen * hFalloff * topZone, bottomPen * hFalloff * bottomZone),
        max(leftPen * vFalloff * leftZone, rightPen * vFalloff * rightZone)
    );
}

void main() {
    vec2 pixel = ubuf.effectRect.xy + qt_TexCoord0 * ubuf.effectRect.zw;

    float k = max(ubuf.smoothK, 0.001);
    float dOuter = sdBoxRect(pixel, ubuf.frameOuter) - 1.0;
    // Preserve the physical owner/workspace boundary separately from the
    // sink-modified frame field. Production Overlay composition may evaluate
    // the complete union while owning only workspace-side output pixels.
    float dWorkspace = sdRoundedRect(pixel, ubuf.frameInner, ubuf.frameRadius);
    float dInner = dWorkspace;

    dInner -= frameSink(pixel, ubuf.frameInner, ubuf.popupRect, k);

    float topThickness = ubuf.frameInner.y - ubuf.frameOuter.y;
    float bottomThickness = (ubuf.frameOuter.y + ubuf.frameOuter.w)
        - (ubuf.frameInner.y + ubuf.frameInner.w);
    float leftThickness = ubuf.frameInner.x - ubuf.frameOuter.x;
    float rightThickness = (ubuf.frameOuter.x + ubuf.frameOuter.z)
        - (ubuf.frameInner.x + ubuf.frameInner.z);
    float minThickness = min(min(topThickness, bottomThickness), min(leftThickness, rightThickness));
    float frameK = clamp(min(k, minThickness - 1.0), 1.0, k);

    float dFrame = circularSmaxSharpA(dOuter, -dInner, frameK);
    vec4 effectiveRadii = popupCornerRadii(
        ubuf.popupRect, ubuf.frameInner, ubuf.popupRadius, k
    );
    float dPopup = sdRoundedRect4(pixel, ubuf.popupRect, effectiveRadii);
    dPopup *= borderFacingScale(pixel, ubuf.frameInner, ubuf.popupRect, k);
    float merged = circularSmin(dFrame, dPopup, k);

    float aa = max(fwidth(merged), 0.0001);
    float alpha = 1.0 - smoothstep(-aa, aa, merged);

    if (ubuf.workspaceOnly > 0.5) {
        float workspaceAa = max(fwidth(dWorkspace), 0.0001);
        float workspaceAlpha =
            1.0 - smoothstep(-workspaceAa, workspaceAa, dWorkspace);
        alpha *= workspaceAlpha;
    }

    vec4 color = ubuf.materialColor;
    fragColor = vec4(color.rgb * alpha, color.a * alpha) * ubuf.qt_Opacity;
}
