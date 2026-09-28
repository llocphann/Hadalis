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
        if (!record) return null
        const horizontal=record.edge === "top" || record.edge === "bottom"
        const content=record.content ?? ({})
        const start=horizontal
            ? root._number(content.x,root._number(record.along))
            : root._number(content.y,root._number(record.along))
        const extent=Math.max(0,horizontal
            ? root._number(content.width,root._number(record.span))
            : root._number(content.height,root._number(record.span)))
        return {
            edge:String(record.edge ?? ""),
            tangentStart:start,
            tangentEnd:start+extent,
            proximity:Math.max(0,
                root._number(request?.stackProximity,24))
        }
    }
    function _descriptorGap(a,b) {
        if (!a || !b || a.edge !== b.edge)
            return Infinity
        if (a.tangentEnd < b.tangentStart)
            return b.tangentStart-a.tangentEnd
        if (b.tangentEnd < a.tangentStart)
            return a.tangentStart-b.tangentEnd
        return 0
    }
    function _pyramidDescriptorsRelated(a,b): bool {
        if (!a || !b || a.edge !== b.edge)
            return false
        return root._descriptorGap(a,b)
            <= Math.max(root._number(a.proximity,24),
                root._number(b.proximity,24))
    }
    function _candidate(identity, participant) {
        if (!participant) return null
        const request=participant.placementRequest
        if (request?.stackPolicy !== "pyramid"
                || !(request?.open ?? false))
            return null
        const placement=participant.visualPlacement
            ?? root.controller?.bodyPlacements?.[identity] ?? null
        // Published geometry is the current visible boundary during
        // overlapping opens/reversals; restingRecord is the fallback.
        const record=participant.geometry
            ?? participant.restingRecord ?? null
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
    function _candidatePool(identity, includeClosings = true) {
        const result=[]
        for (const key of Object.keys(root.controller?.participants ?? {})) {
            if (String(key) === String(identity)) continue
            const candidate=root._candidate(
                key,root.controller.participants[key])
            if (candidate)
                result.push(candidate)
        }
        if (includeClosings) {
            for (const key of Object.keys(root.closings)) {
                if (String(key) === String(identity)) continue
                const closing=root.closings[key]
                // A reopening transaction is semantically open and therefore
                // already represented by the participant candidates above.
                if (root.controller?.participants?.[key]
                        ?.placementRequest?.open === true)
                    continue
                const liveRecord=
                    root.controller?.participants?.[key]?.geometry ?? null
                if (liveRecord
                        && root._number(liveRecord.progress,1) <= .001)
                    continue
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
    function _pyramidGroupCandidates(identity, request,
            includeClosings = true) {
        const wanted=root._descriptor(request)
        if (!wanted) return []
        const pool=root._candidatePool(identity,includeClosings)
        const result=[]
        const descriptors=[wanted]
        const used=({})

        // Match AbyssBodyPlacement's union-find semantics: a neighborhood may
        // be transitive (A overlaps B, B overlaps C) even when A and C do not.
        let changed=true
        while (changed) {
            changed=false
            for (let i=0;i<pool.length;i++) {
                if (used[i]) continue
                const candidate=pool[i]
                if (!descriptors.some(descriptor =>
                        root._pyramidDescriptorsRelated(
                            descriptor,candidate.descriptor)))
                    continue
                used[i]=true
                result.push(candidate)
                descriptors.push(candidate.descriptor)
                changed=true
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
        for (const candidate of root._pyramidGroupCandidates(
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
        for (const peer of root._pyramidGroupCandidates(
                identity,request,false)) {
            if (peer.placement)
                frozen[peer.identity]=Motion.clonePlacement(
                    peer.placement)
        }
        const lower=root._lowerPeer(identity,request,placement)
        const next=Object.assign({},root.closings)
        next[identity]={
            phase:"closing",
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
    function _setPhase(identity, phase): void {
        identity=String(identity ?? "")
        const current=root.closings[identity]
        if (!identity || !current || current.phase === phase)
            return
        const next=Object.assign({},root.closings)
        next[identity]=Object.assign({},current,{phase:String(phase)})
        root.closings=next
        root.revision += 1
    }
    function beginReopen(identity): void {
        root._setPhase(identity,"reopening")
    }
    function resumeClose(identity): void {
        root._setPhase(identity,"closing")
    }
    function cancelClose(identity, preserveForPeers = true): void {
        identity=String(identity ?? "")
        if (!identity || root.closings[identity] === undefined)
            return
        const reopening=root.closings[identity]
        const next=Object.assign({},root.closings)
        delete next[identity]

        if (preserveForPeers && reopening?.placement
                && reopening?.descriptor) {
            // Reopen during another same-neighborhood close must reverse from the
            // current transaction without jumping into the allocator's already
            // reflowed slot. Keep this identity frozen by remaining peers until
            // their own tails finish, then normal placement motion can resume.
            for (const key of Object.keys(next)) {
                const entry=Object.assign({},next[key])
                if (!root._pyramidDescriptorsRelated(
                        reopening.descriptor,entry?.descriptor))
                    continue
                const frozen=Object.assign({},entry.frozen ?? {})
                if (frozen[identity] === undefined)
                    frozen[identity]=Motion.clonePlacement(
                        reopening.placement)
                entry.frozen=frozen
                next[key]=entry
            }
        }

        root.closings=next
        root._rebuildFrozen()
    }
    function finishClose(identity): void {
        // A finished popup is gone; only a completed reopen may need to remain
        // frozen by another overlapping same-neighborhood transaction.
        root.cancelClose(identity,false)
    }
    function finishReopen(identity): void {
        root.cancelClose(identity,true)
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
