pragma ComponentBehavior: Bound
import QtQuick
import "looks/AbyssPyramidMotion.js" as Motion

// Pyramid Popup v2 presentation coordinator.
//
// AbyssBodyPlacement remains the only resting-layout allocator. This object owns
// only visual transactions: group freeze during a close, popup-to-popup reveal
// origins, immediate semantic/input revocation, and reversible closing tails.
QtObject {
    id: root
    required property var controller

    property var closings: ({})
    property var frozenPlacements: ({})
    property int revision: 0

    function _number(value, fallback = 0) {
        const n=Number(value)
        return Number.isFinite(n) ? n : fallback
    }
    function _descriptor(request) {
        const record=request?.record
        return {
            edge:String(record?.edge ?? ""),
            anchorCenter:root._number(record?.along)
                +root._number(record?.span)/2
        }
    }
    function _sameAnchorDescriptor(a,b): bool {
        return !!a && !!b && a.edge === b.edge
            && Math.abs(root._number(a.anchorCenter)
                -root._number(b.anchorCenter)) <= 2
    }
    function _candidate(identity, participant) {
        if (!participant) return null
        const request=participant.placementRequest
        if (request?.stackPolicy !== "pyramid"
                || !(request?.open ?? false))
            return null
        const placement=participant.visualPlacement
            ?? root.controller?.bodyPlacements?.[identity] ?? null
        const record=participant.restingRecord
            ?? participant.geometry ?? null
        if (!placement || placement.visible === false || !record)
            return null
        return {
            identity:String(identity),
            descriptor:root._descriptor(request),
            placement:Motion.clonePlacement(placement),
            record:Motion.cloneRecord(record),
            source:"participant"
        }
    }
    function _sameAnchorCandidates(identity, request, includeClosings = true) {
        const wanted=root._descriptor(request)
        const result=[]
        for (const key of Object.keys(root.controller?.participants ?? {})) {
            if (String(key) === String(identity)) continue
            const candidate=root._candidate(
                key,root.controller.participants[key])
            if (candidate
                    && root._sameAnchorDescriptor(
                        wanted,candidate.descriptor))
                result.push(candidate)
        }
        if (includeClosings) {
            for (const key of Object.keys(root.closings)) {
                if (String(key) === String(identity)) continue
                const closing=root.closings[key]
                if (!root._sameAnchorDescriptor(
                        wanted,closing?.descriptor))
                    continue
                // Overlapping transactions meet a lower closing popup at the
                // boundary actually visible on this frame, not its old full
                // resting depth. Keep the full snapshot only as a fallback.
                const liveRecord=
                    root.controller?.participants?.[key]?.geometry ?? null
                result.push({
                    identity:String(key),
                    descriptor:closing.descriptor,
                    placement:Motion.clonePlacement(closing.placement),
                    record:Motion.cloneRecord(
                        liveRecord ?? closing.fullRecord),
                    source:"closing"
                })
            }
        }
        return result
    }
    function _lowerPeer(identity, request, placement) {
        if (!placement) return null
        const inward=root._number(placement.inward)
        if (!(inward > .5)) return null
        let best=null
        let bestInward=-1
        for (const candidate of root._sameAnchorCandidates(
                identity,request,true)) {
            const candidateInward=root._number(
                candidate.placement?.inward,-1)
            if (candidateInward < 0
                    || candidateInward >= inward-.5
                    || candidateInward <= bestInward)
                continue
            best=candidate
            bestInward=candidateInward
        }
        return best
    }
    function entryOrigin(identity, request, placement, fullRecord) {
        if (!placement || !fullRecord) return null
        const lower=root._lowerPeer(identity,request,placement)
        return Motion.collapsedRecord(
            fullRecord,lower?.record ?? null)
    }
    function _rebuildFrozen(): void {
        const next={}
        for (const key of Object.keys(root.closings)) {
            const frozen=root.closings[key]?.frozen ?? {}
            for (const peer of Object.keys(frozen)) {
                if (next[peer] === undefined)
                    next[peer]=Motion.clonePlacement(frozen[peer])
            }
        }
        root.frozenPlacements=next
        root.revision += 1
    }
    function targetFor(identity, livePlacement) {
        // Touch revision so callers also update if a rebuilt map happens to
        // contain numerically-equal placement objects.
        root.revision
        const closing=root.closings[String(identity)]
        if (closing?.placement)
            return closing.placement
        return root.frozenPlacements[String(identity)]
            ?? livePlacement ?? null
    }
    function beginClose(identity, request, placement, fullRecord) {
        identity=String(identity ?? "")
        if (!identity || !placement || !fullRecord)
            return Motion.collapsedRecord(fullRecord,null)

        const descriptor=root._descriptor(request)
        const frozen={}
        for (const peer of root._sameAnchorCandidates(
                identity,request,false)) {
            if (peer.placement)
                frozen[peer.identity]=Motion.clonePlacement(
                    peer.placement)
        }
        const lower=root._lowerPeer(identity,request,placement)
        const next=Object.assign({},root.closings)
        next[identity]={
            descriptor:descriptor,
            placement:Motion.clonePlacement(placement),
            fullRecord:Motion.cloneRecord(fullRecord),
            originRecord:Motion.collapsedRecord(
                fullRecord,lower?.record ?? null),
            frozen:frozen
        }
        root.closings=next
        root._rebuildFrozen()
        return Motion.cloneRecord(next[identity].originRecord)
    }
    function cancelClose(identity): void {
        identity=String(identity ?? "")
        if (!identity || root.closings[identity] === undefined)
            return
        const next=Object.assign({},root.closings)
        delete next[identity]
        root.closings=next
        root._rebuildFrozen()
    }
    function finishClose(identity): void {
        root.cancelClose(identity)
    }
    function resetIdentity(identity): void {
        identity=String(identity ?? "")
        const next=Object.assign({},root.closings)
        if (next[identity] !== undefined)
            delete next[identity]
        // A stable StyledPopup slot may be reused by another popup. Remove that
        // identity from other transactions so stale geometry cannot leak into
        // the new owner.
        for (const key of Object.keys(next)) {
            const entry=Object.assign({},next[key])
            const frozen=Object.assign({},entry.frozen ?? {})
            if (frozen[identity] !== undefined) {
                delete frozen[identity]
                entry.frozen=frozen
                next[key]=entry
            }
        }
        root.closings=next
        root._rebuildFrozen()
    }
}
