#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float smoothK;
    float frameRadius;
    float popupRadius;
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

    float preOff = k * (2.0 - sqrt(2.0)) * 0.5;

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
    // qt_TexCoord0 is local to this bounded ShaderEffect. effectRect maps it
    // back into output-local logical coordinates without mutating semantic rects.
    vec2 pixel = ubuf.effectRect.xy + qt_TexCoord0 * ubuf.effectRect.zw;

    float k = max(ubuf.smoothK, 0.001);
    float dOuter = sdBoxRect(pixel, ubuf.frameOuter) - 1.0;
    float dInner = sdRoundedRect(pixel, ubuf.frameInner, ubuf.frameRadius);

    // Generic border sink. It evaluates all four frame sides from the same popup
    // rectangle and contains no module, source-position, or contact-corner state.
    dInner -= frameSink(pixel, ubuf.frameInner, ubuf.popupRect, k);

    float topThickness = ubuf.frameInner.y - ubuf.frameOuter.y;
    float bottomThickness = (ubuf.frameOuter.y + ubuf.frameOuter.w)
        - (ubuf.frameInner.y + ubuf.frameInner.w);
    float leftThickness = ubuf.frameInner.x - ubuf.frameOuter.x;
    float rightThickness = (ubuf.frameOuter.x + ubuf.frameOuter.z)
        - (ubuf.frameInner.x + ubuf.frameInner.z);
    float minThickness = min(min(topThickness, bottomThickness), min(leftThickness, rightThickness));
    float frameK = min(k, max(0.5, minThickness - 0.5));

    float dFrame = circularSmaxSharpA(dOuter, -dInner, frameK);
    float dPopup = sdRoundedRect(pixel, ubuf.popupRect, ubuf.popupRadius);
    float merged = circularSmin(dFrame, dPopup, k);

    float aa = max(fwidth(merged), 0.0001);
    float alpha = 1.0 - smoothstep(-aa, aa, merged);
    vec4 color = ubuf.materialColor;
    fragColor = vec4(color.rgb * alpha, color.a * alpha) * ubuf.qt_Opacity;
}
