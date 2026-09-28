import QtQuick
import qs.modules.abyss.looks

// Transaction planner for same-anchor pyramid popups.
//
// Phase 1 deliberately does not drive geometry. It separates semantic state,
// visual residency and resting-layout snapshots so later motion can consume a
// stable transaction without mutating AbyssBodyPlacement or AbyssGeometry.
QtObject {
    id: root

    required property var controller
    property bool motionEnabled: true
    property int generation: 0
    property int transactionGeneration: 0
    property real transactionProgress: 1
    property bool resettingProgress: false
    property var snapshots: ({})
    property var semanticStates: ({})
    property var plannedTransitions: ({})
    property var publishedTargets: ({})
    property var pendingTargets: ({})
    property var activeClosings: ({})

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
    function placementEqual(a,b): bool {
        if (!a || !b) return a === b
        return a.visible === b.visible
            && Math.abs(Number(a.along ?? 0)-Number(b.along ?? 0)) < .25
            && Math.abs(Number(a.inward ?? 0)-Number(b.inward ?? 0)) < .25
            && Math.abs(Number(a.span ?? 0)-Number(b.span ?? 0)) < .25
            && Math.abs(Number(a.depth ?? 0)-Number(b.depth ?? 0)) < .25
    }
    function targetMapsEqual(a,b): bool {
        const ak=Object.keys(a ?? {}).sort()
        const bk=Object.keys(b ?? {}).sort()
        if (ak.length !== bk.length) return false
        for (let i=0;i<ak.length;++i) {
            if (ak[i] !== bk[i] || !root.placementEqual(a[ak[i]],b[bk[i]]))
                return false
        }
        return true
    }
    function interpolatePlacement(from,to,t): var {
        if (!from) return root.clonePlacement(to)
        if (!to) return root.clonePlacement(from)
        const p=Math.max(0,Math.min(1,Number(t ?? 1)))
        function mix(a,b) { return Number(a ?? 0)+(Number(b ?? 0)-Number(a ?? 0))*p }
        return Object.assign({},to,{
            along:mix(from.along,to.along),
            inward:mix(from.inward,to.inward),
            span:mix(from.span,to.span),
            depth:mix(from.depth,to.depth)
        })
    }
    function targetFor(identity): var {
        return root.publishedTargets[String(identity)] ?? null
    }
    function hasActiveClosings(): bool {
        return Object.keys(root.activeClosings).length > 0
    }
    function buildTargets(placements,participants): var {
        const result={}
        for (const identity of Object.keys(participants ?? {})) {
            const request=participants[identity]?.placementRequest
            if (!(request?.pyramidStack ?? false) || !(request?.open ?? false))
                continue
            const placement=placements?.[identity]
            if (!placement || placement.visible === false)
                continue
            result[identity]=root.clonePlacement(placement)
        }
        return result
    }
    function publishTargets(targets,animate=true): void {
        const next=targets ?? ({})
        if (root.targetMapsEqual(root.publishedTargets,next))
            return

        if (!root.motionEnabled || !AbyssStyle.motionEnabled
                || Object.keys(root.publishedTargets).length === 0 || !animate) {
            root.resettingProgress=true
            root.publishedTargets=next
            root.transactionProgress=1
            root.transactionGeneration += 1
            root.resettingProgress=false
            return
        }

        // Hosts snapshot their current interpolated frame when generation
        // changes. Reset progress only after that synchronous notification.
        root.publishedTargets=next
        root.transactionGeneration += 1
        root.resettingProgress=true
        root.transactionProgress=0
        root.resettingProgress=false
        Qt.callLater(() => {
            if (root.motionEnabled)
                root.transactionProgress=1
        })
    }
    function syncResting(placements,participants): void {
        const next=root.buildTargets(placements,participants)
        if (root.hasActiveClosings()) {
            root.pendingTargets=next
            return
        }
        root.pendingTargets=({})
        root.publishTargets(next,true)
    }
    function beginClosing(identity): void {
        if (!identity) return
        const next=Object.assign({},root.activeClosings)
        next[String(identity)]=true
        root.activeClosings=next
    }
    function finishClosing(identity,placements,participants): void {
        if (!identity || root.activeClosings[identity] === undefined)
            return
        const next=Object.assign({},root.activeClosings)
        delete next[identity]
        root.activeClosings=next
        root.remove(identity)
        if (root.hasActiveClosings())
            return
        const pending=Object.keys(root.pendingTargets).length > 0
            ? root.pendingTargets : root.buildTargets(placements,participants)
        root.pendingTargets=({})
        root.publishTargets(pending,true)
    }
    function cancelClosing(identity,placements,participants): void {
        if (!identity || root.activeClosings[identity] === undefined)
            return
        const next=Object.assign({},root.activeClosings)
        delete next[identity]
        root.activeClosings=next
        if (!root.hasActiveClosings())
            root.syncResting(placements,participants)
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
        if (!identity || !(request?.pyramidStack ?? false))
            return
        const states=Object.assign({},root.semanticStates)
        const previous=states[identity]
        states[identity]=open === true
        root.semanticStates=states

        if (open) {
            root.capture(identity,request,placement,record)
            if (previous === false)
                root.cancelClosing(identity,
                    root.controller?.bodyPlacements,
                    root.controller?.participants)
            if (root.plannedTransitions[identity] !== undefined) {
                const next=Object.assign({},root.plannedTransitions)
                delete next[identity]
                root.plannedTransitions=next
            }
            return
        }

        if (previous === true) {
            root.generation += 1
            root.beginClosing(identity)
            if (root.motionEnabled) {
                const plan=root.planClose(identity)
                const next=Object.assign({},root.plannedTransitions)
                if (plan) next[identity]=plan
                root.plannedTransitions=next
            }
        }
    }

    Behavior on transactionProgress {
        enabled: root.motionEnabled && !root.resettingProgress
            && AbyssStyle.motionEnabled
        NumberAnimation {
            duration: AbyssStyle.motionNormal
            easing.type: Easing.InOutCubic
        }
    }
}
