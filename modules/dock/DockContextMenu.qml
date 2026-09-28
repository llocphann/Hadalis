import qs.modules.common
import qs.modules.common.widgets
import Quickshell
import qs.modules.abyss.looks

// Alias to the generic ContextMenu with dock-specific defaults
ContextMenu {
    readonly property bool abyssMode:
        (Config.options?.panelFamily ?? "ii") === "abyss"
    padding: abyssMode ? 8 : 4
    visualMargin: abyssMode ? 10 : 8
    panelFallbackColor: abyssMode
        ? Qt.alpha(AbyssStyle.surfaceDeep, Math.max(.84,AbyssStyle.contentOpacity))
        : Appearance.colors.colSurfaceContainer
    panelRadius: abyssMode ? Math.max(14,AbyssStyle.neckRadius*.72)
        : Appearance.rounding.normal
    panelBorderWidth: abyssMode ? 1 : 1
    panelBorderColor: abyssMode
        ? Qt.alpha(AbyssStyle.accent,.22)
        : Appearance.colors.colSurfaceContainerHighest
    closeOnHoverLostDelay: abyssMode ? 650 : 500
    readonly property string dockPosition: Config.options?.dock?.position ?? "bottom"
    readonly property bool isVertical: dockPosition === "left" || dockPosition === "right"
    
    // Para posiciones verticales: popup hacia el centro (right para left, left para right)
    // Para posiciones horizontales: popup arriba para bottom, abajo para top
    popupAbove: !isVertical && dockPosition !== "top"
    
    // Para posiciones verticales, usar gravity/edges horizontales (0 = none/vertical)
    popupSide: isVertical ? (dockPosition === "left" ? Edges.Right : Edges.Left) : 0
}
