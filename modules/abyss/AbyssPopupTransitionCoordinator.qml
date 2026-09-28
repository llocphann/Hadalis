import QtQuick

// Capture-only transaction planner for same-anchor pyramid popups.
//
// Phase 1 deliberately does not drive geometry. It separates semantic state,
// visual residency and resting-layout snapshots so later motion can consume a
// stable transaction without mutating AbyssBodyPlacement or AbyssGeometry.
QtObject {
    id: root

    required property var controller
    // Infrastructure is live so snapshots can be audited in owner sessions,
    // but motion stays disabled until the group transaction path is enabled.
    property bool motionEnabled: false
    property int generation: 0
    property var snapshots: ({})
    property var semanticStates: ({})
    property var plannedTransitions: ({})

    function cloneRect(rect): var {
        if (!rect) return null
        return {x:Number(rect.x ?? 0), y:Number(rect.y ?? 0),
            width:Number(rect.width ?? 0), height:Number(rect.height ?? 0)}
    }
    function cloneRecord(record): var {
        if (!record) return null
        return {
            edge:String(record.edge ?? ""),
            along:Number(record.along ?? 0),
            span:Number(record.span ?? 0),
            depth:Number(record.depth ?? 0),
            targetDepth:Number(record.targetDepth ?? record.depth ?? 0),
            surface:cloneRect(record.surface),
            content:cloneRect(record.content)
        }
    }
    function clonePlacement(placement): var {
        if (!placement) return null
        return {
            visible:placement.visible !== false,
            evicted:placement.evicted === true,
            along:Number(placement.along ?? 0),
            inward:Number(placement.inward ?? 0),
            span:Number(placement.span ?? 0),
            depth:Number(placement.depth ?? 0),
            shrunk:placement.shrunk === true,
            content:cloneRect(placement.content)
        }
    }
    function anchorCenter(request): real {
        const record=request?.record
        return Number(record?.along ?? 0)+Number(record?.span ?? 0)/2
    }
    function sameAnchor(a,b): bool {
        return !!a && !!b
            && String(a.edge ?? "") === String(b.edge ?? "")
            && Math.abs(Number(a.anchorCenter ?? 0)
                -Number(b.anchorCenter ?? 0)) <= 2
    }
    function capture(identity,request,placement,record): void {
        if (!identity || !(request?.pyramidStack ?? false)
                || !(request?.open ?? false)
                || !placement || placement.visible === false || !record)
            return
        const next=Object.assign({},root.snapshots)
        next[identity]={
            identity:String(identity),
            edge:String(request.record?.edge ?? ""),
            anchorCenter:root.anchorCenter(request),
            placement:root.clonePlacement(placement),
            record:root.cloneRecord(record),
            order:Number(request.order ?? 0),
            priority:Number(request.priority ?? 0)
        }
        root.snapshots=next
    }
    function remove(identity): void {
        if (!identity || root.snapshots[identity] === undefined)
            return
        const next=Object.assign({},root.snapshots)
        delete next[identity]
        root.snapshots=next
    }
    function group(identity): var {
        const source=root.snapshots[identity]
        if (!source) return []
        return Object.keys(root.snapshots)
            .map(key => root.snapshots[key])
            .filter(peer => root.sameAnchor(source,peer))
            .sort((a,b) => Number(a.placement?.inward ?? 0)
                -Number(b.placement?.inward ?? 0))
    }
    function planClose(identity): var {
        const source=root.snapshots[identity]
        if (!source) return null
        const sourceInward=Number(source.placement?.inward ?? 0)
        let lower=null
        let lowerInward=-1
        for (const peer of root.group(identity)) {
            if (peer.identity === identity) continue
            const inward=Number(peer.placement?.inward ?? 0)
            if (inward < sourceInward-.5 && inward > lowerInward) {
                lower=peer
                lowerInward=inward
            }
        }
        return {
            generation:root.generation+1,
            identity:String(identity),
            phase:"planned",
            source:source,
            targetIdentity:lower?.identity ?? "",
            target:lower,
            group:root.group(identity)
        }
    }
    function observeSemantic(identity,open,request,placement,record): void {
        if (!identity) return
        const states=Object.assign({},root.semanticStates)
        const previous=states[identity]
        states[identity]=open === true
        root.semanticStates=states

        if (open) {
            root.capture(identity,request,placement,record)
            if (root.plannedTransitions[identity] !== undefined) {
                const next=Object.assign({},root.plannedTransitions)
                delete next[identity]
                root.plannedTransitions=next
            }
            return
        }

        if (previous === true) {
            root.generation += 1
            if (root.motionEnabled) {
                const plan=root.planClose(identity)
                const next=Object.assign({},root.plannedTransitions)
                if (plan) next[identity]=plan
                root.plannedTransitions=next
            }
        }
    }
}
