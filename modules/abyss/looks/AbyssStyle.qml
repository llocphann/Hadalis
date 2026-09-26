pragma Singleton
import QtQuick
import Quickshell
import qs.modules.common
import qs.modules.common.functions

Singleton {
    readonly property var options: Config.options?.abyss
    readonly property string quality: ["performance", "balanced", "quality"].includes(options?.quality) ? options.quality : "balanced"
    readonly property real perimeterThickness: Math.max(3, Math.min(24, options?.perimeter?.thickness ?? 8))
    readonly property real perimeterRadius: Math.max(12, Math.min(64, options?.perimeter?.radius ?? 34))
    readonly property real surfaceTension: Math.max(0, Math.min(1, options?.surface?.tension ?? 0.5))
    readonly property real neckRadius: 20 + 18 * surfaceTension
    readonly property real connectionDepth: Math.max(4, Math.min(48, options?.surface?.softness ?? 24))
    readonly property real sectionSpacing: 18 * Appearance.fontSizeScale
    readonly property real contentPadding: 20 * Appearance.fontSizeScale
    readonly property real barThickness: Math.max(48, Appearance.sizes.barHeight)
    readonly property real dockThickness: Math.max(52, Math.min(100, Config.options?.dock?.height ?? 70))
    readonly property real blurRadius: quality === "performance" || !(options?.effects?.blur?.enabled ?? true) ? 0 : Math.max(0, Math.min(24, options?.effects?.blur?.radius ?? 10))
    readonly property real shadowStrength: quality === "performance" ? 0 : Math.max(0, Math.min(0.5, options?.effects?.shadowStrength ?? 0.24))
    readonly property real refractionStrength: quality !== "quality" || !(options?.effects?.refraction?.enabled ?? false) ? 0 : Math.max(0, Math.min(16, options?.effects?.refraction?.strength ?? 6))
    readonly property real highlightStrength: Math.max(0, Math.min(1, options?.effects?.surfaceHighlight ?? 0.45))
    readonly property real glowStrength: quality === "performance" ? 0 : Math.max(0, Math.min(0.3, options?.effects?.glow?.strength ?? 0.08))
    readonly property bool motionEnabled: Appearance.animationsEnabled && (options?.motion?.intensity ?? 0.6) > 0
    readonly property int motionFast: motionEnabled ? 140 : 0
    readonly property int motionNormal: motionEnabled ? 220 : 0
    readonly property int motionSettle: motionEnabled ? 280 : 0
    readonly property real motionOvershoot: quality === "quality" ? 0.025 * (options?.motion?.intensity ?? 0.6) : 0
    readonly property string fontFamily: Appearance.font.family.main
    readonly property real fontSize: Appearance.font.pixelSize.normal
    readonly property color surfaceDeep: ColorUtils.colorWithLightness(Appearance.m3colors.m3surface, 0.045)
    readonly property color surfaceRaised: ColorUtils.colorWithLightness(Appearance.colors.colPrimary, 0.11)
    readonly property color surface: Qt.alpha(surfaceDeep, Math.max(0.65, Math.min(1, options?.surface?.opacity ?? 0.91)))
    readonly property color accent: ColorUtils.colorWithLightness(Appearance.colors.colPrimary, 0.68)
    readonly property color textColor: Qt.hsla(Math.max(0, Appearance.m3colors.m3onSurface.hslHue),
        Math.min(0.15, Appearance.m3colors.m3onSurface.hslSaturation), 0.92, 1)
    readonly property color textColorMuted: Qt.alpha(textColor, 0.68)
    readonly property color specular: ColorUtils.colorWithLightness(accent, 0.85)
    readonly property color glow: Qt.alpha(accent, glowStrength)
    readonly property color shadow: Qt.alpha(Appearance.m3colors.m3shadow, shadowStrength)
}
