pragma Singleton

import QtQuick
import qs
import qs.modules.common
import qs.modules.common.perimeter

QtObject {
    id: root

    function _barThickness(): real {
        const showBackground = Config.options?.bar?.showBackground ?? true
        const cornerStyle = Number(Config.options?.bar?.cornerStyle ?? 0)
        const detachedRounded = Appearance.zzzEverywhere
            && Appearance.zzz.round
            && showBackground
            && (cornerStyle === 1 || cornerStyle === 3)
        return detachedRounded
            ? Appearance.sizes.baseBarHeight + Appearance.sizes.elevationMargin * 2
            : Appearance.sizes.barHeight
    }

    function _dockThickness(instance): real {
        if (!(Config.options?.dock?.enable ?? true))
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
                    // Legacy Bar unmaps with barOpen. Keep the reservation in
                    // lock-step with that semantic state during migration.
                    if (GlobalStates.barOpen)
                        zone = Math.max(zone, root._barThickness())
                } else if (kind === "dock") {
                    zone = Math.max(zone, root._dockThickness(instance))
                }
            }
        }
        return Math.max(0, Math.ceil(zone))
    }
}
