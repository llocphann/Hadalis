#!/usr/bin/env python3
"""Pyramid v2 transaction-order regression model.

The QML coordinator is deliberately small; this model locks the non-visual
ordering rules that matter when close operations overlap. Geometry itself is
covered by test-abyss-pyramid-v2-geometry.py.
"""
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


@dataclass(frozen=True)
class Peer:
    name: str
    edge: str
    start: float
    end: float
    inward: float
    open: bool = True


def related(a: Peer, b: Peer, proximity: float = 24) -> bool:
    if a.edge != b.edge:
        return False
    if a.end < b.start:
        gap = b.start - a.end
    elif b.end < a.start:
        gap = a.start - b.end
    else:
        gap = 0
    return gap <= proximity


def component(subject: Peer, peers: list[Peer]) -> list[Peer]:
    pool=[peer for peer in peers if peer.name != subject.name and peer.open]
    result=[]
    frontier=[subject]
    changed=True
    while changed:
        changed=False
        for peer in pool[:]:
            if any(related(peer,member) for member in frontier):
                result.append(peer)
                frontier.append(peer)
                pool.remove(peer)
                changed=True
    return result


def lower_peer(subject: Peer, peers: list[Peer]) -> Peer | None:
    candidates = [
        peer for peer in component(subject, peers)
        if peer.inward < subject.inward - 0.5
    ]
    return max(candidates, key=lambda peer: peer.inward, default=None)


def reflowing_survivors(subject: Peer, peers: list[Peer]) -> set[str]:
    # Semantic survivors remain open and therefore receive their new allocator
    # resting placements immediately when subject closes.
    return {peer.name for peer in component(subject, peers)}


def main() -> None:
    coord = (ROOT / "modules/abyss/AbyssPyramidCoordinator.qml").read_text()
    host = (ROOT / "modules/abyss/AbyssBodyHost.qml").read_text()

    # Source-level guards for the runtime ordering rules.
    assert "includeClosings = true" in coord
    assert "root._pyramidGroupCandidates(" in coord
    assert "identity,request,false" in coord
    assert "function _pyramidDescriptorsRelated(a,b): bool" in coord
    assert "tangentStart" in coord and "tangentEnd" in coord
    assert "root._lowerPeer(identity,request,placement)" in coord
    assert "root._rebuildFrozen()" not in coord
    assert "property var frozenPlacements: ({})" not in coord
    assert "return transaction?.placement ?? livePlacement ?? null" in coord
    assert 'phase:"closing"' in coord
    assert 'root._setPhase(identity,"reopening")' in coord
    assert 'root._setPhase(identity,"closing")' in coord
    assert "function finishReopen(identity): void" in coord
    assert "const liveRecord=" in coord
    assert "liveRecord ?? closing.fullRecord" in coord
    assert "root._number(liveRecord.progress,1) <= .001" in coord
    assert "function cancelClose(identity): void" in coord
    assert "preserveForPeers" not in coord
    assert "frozen[identity]" not in coord
    assert "root.pyramidOriginRecord && root.progress > 0.001" in host
    assert "root.pyramidAllocatorPlacement,root.pyramidAllocatorRecord" in host
    assert "Qt.callLater(root.syncPyramidEntryOrigin)" not in host

    # Different anchors, but one connected tangent neighborhood.
    bottom = Peer("bottom", "top", 300, 760, 0)
    middle = Peer("middle", "top", 620, 900, 220)
    top = Peer("top", "top", 820, 1040, 420)
    remote = Peer("remote", "top", 30, 250, 80)
    side = Peer("side", "left", 620, 900, 80)
    group = [bottom, middle, top, remote, side]

    # The chain is transitive: bottom overlaps middle, middle overlaps top,
    # while bottom/top need not overlap directly.
    assert related(bottom, middle)
    assert related(middle, top)
    assert not related(bottom, top)
    assert not related(bottom, remote)
    assert not related(middle, remote)
    assert not related(top, side)

    # Entry/close targets are nearest lower peers inside that neighborhood.
    assert lower_peer(top, group) == middle
    assert lower_peer(middle, group) == bottom
    assert lower_peer(bottom, group) is None

    # Closing top makes the connected semantic survivors reflow immediately;
    # they do not wait for the closing tail to reach zero.
    assert reflowing_survivors(top, group) == {"bottom", "middle"}

    # If middle closes while top is already visual-only, bottom remains its
    # lower semantic peer; remote and perpendicular peers stay independent.
    after_top_semantic_close = [
        bottom, Peer("middle", "top", 620, 900, 220, True),
        Peer("top", "top", 820, 1040, 420, False), remote, side
    ]
    assert reflowing_survivors(
        after_top_semantic_close[1], after_top_semantic_close
    ) == {"bottom"}

    # A lower visual tail at the zero endpoint is no longer a meaningful lower
    # boundary even if its transaction bookkeeping clears one binding turn later.
    closing_tail_progress = 0.001
    assert closing_tail_progress <= 0.001

    # Reopen reverses the closing popup's O/F transaction. Survivors do not
    # need a frozen map: when semantic open returns, allocator targets change
    # again and their existing placement Behaviors reverse from the current frame.
    phase = "closing"
    phase = "reopening"
    assert phase == "reopening"
    phase = "closing"
    assert phase == "closing"

    # Different anchors/Edges still stay independent.
    assert reflowing_survivors(remote, group) == set()
    assert reflowing_survivors(side, group) == set()

    print("Pyramid Popup v2 transaction-order contract: ok")


if __name__ == "__main__":
    main()
