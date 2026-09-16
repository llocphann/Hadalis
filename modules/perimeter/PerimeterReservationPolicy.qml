pragma Singleton

import QtQuick
import qs
import qs.modules.common
import qs.modules.common.perimeter

QtObject {
    id: root

    function _barThickness(edge: string): real {
        if (!PerimeterPresentationPolicy.barSurfaceEnabled)
            return 0
        const targetEdge = String(edge ?? "")
        const cornerStyle = Number(Config.options?.bar?.cornerStyle ?? 0)
        if (targetEdge === "left" || targetEdge === "right") {
            // Match legacy VerticalBar reservation semantics when bar-family
            // modules are hosted on a vertical perimeter edge.
            return Appearance.sizes.baseVerticalBarWidth
                + (cornerStyle === 1 ? Appearance.sizes.hyprlandGapsOut : 0)
        }

        const showBackground = Config.options?.bar?.showBackground ?? true
        const detachedRounded = Appearance.zzzEverywhere
            && Appearance.zzz.round
            && showBackground
            && (cornerStyle === 1 || cornerStyle === 3)
        return detachedRounded
            ? Appearance.sizes.baseBarHeight + Appearance.sizes.elevationMargin * 2
            : Appearance.sizes.barHeight
    }

    function _dockThickness(instance): real {
        if (!PerimeterPresentationPolicy.dockSurfaceEnabled
                || !(Config.options?.dock?.enable ?? true))
            return 0
        const raw = Number(instance?.config?.thickness
            ?? Config.options?.dock?.height ?? 70)
        const thickness = Number.isFinite(raw)
            ? Math.max(40, Math.min(200, raw)) : 70
        return thickness + Appearance.sizes.elevationMargin
    }

    function zoneForOutputEdge(outputName: string, edge: string): real {
        Config.revision
        ModuleRegistry.moduleIds
        const name = String(outputName ?? "")
        const targetEdge = String(edge ?? "")
        if (!name || !PerimeterTopology.edges.includes(targetEdge)
                || !PerimeterConfig.validate(name))
            return 0

        let zone = 0
        for (const slotId of PerimeterTopology.slotIds) {
            if (PerimeterTopology.edgeForSlot(slotId) !== targetEdge)
                continue
            for (const instanceId of PerimeterConfig.slotInstanceIds(name, slotId)) {
                const instance = PerimeterConfig.instanceDescriptor(name, instanceId)
                const moduleId = String(instance?.moduleId ?? "")
                const registration = ModuleRegistry.resolve(moduleId)
                const kind = String(registration?.reservationKind ?? "")
                if (kind === "bar") {
                    // Legacy Bar drops its zone while coverflow owns the edge and
                    // unmaps completely when barOpen is false. Output placement is
                    // perimeter-owned once cutover is requested, so legacy screenList
                    // must not become a second placement source.
                    if (GlobalStates.barOpen
                            && !GlobalStates.coverflowSelectorOpen)
                        zone = Math.max(zone, root._barThickness(targetEdge))
                } else if (kind === "dock") {
                    // A pinned legacy Dock keeps its zone while reveal content is
                    // hidden. Which output owns the dock is determined only by
                    // PerimeterConfig placement.
                    zone = Math.max(zone, root._dockThickness(instance))
                }
            }
        }
        return Math.max(0, Math.ceil(zone))
    }
}
