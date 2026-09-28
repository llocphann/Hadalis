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
    center: float
    inward: float
    open: bool = True


def same_anchor(a: Peer, b: Peer) -> bool:
    return a.edge == b.edge and abs(a.center - b.center) <= 2


def lower_peer(subject: Peer, peers: list[Peer]) -> Peer | None:
    candidates = [
        peer for peer in peers
        if peer.name != subject.name
        and same_anchor(subject, peer)
        and peer.inward < subject.inward - 0.5
    ]
    return max(candidates, key=lambda peer: peer.inward, default=None)


def frozen_survivors(subject: Peer, peers: list[Peer]) -> set[str]:
    return {
        peer.name for peer in peers
        if peer.name != subject.name and peer.open and same_anchor(subject, peer)
    }


def main() -> None:
    coord = (ROOT / "modules/abyss/AbyssPyramidCoordinator.qml").read_text()
    host = (ROOT / "modules/abyss/AbyssBodyHost.qml").read_text()

    # Source-level guards for the runtime ordering rules.
    assert "includeClosings = true" in coord
    assert "root._sameAnchorCandidates(identity,request,false)" in coord
    assert "root._lowerPeer(identity,request,placement)" in coord
    assert "root._rebuildFrozen()" in coord
    assert "const liveRecord=" in coord
    assert "liveRecord ?? closing.fullRecord" in coord
    assert "root.pyramidOriginRecord && root.progress > 0.001" in host
    assert "root.pyramidAllocatorPlacement,root.pyramidAllocatorRecord" in host
    assert "Qt.callLater(root.syncPyramidEntryOrigin)" not in host

    bottom = Peer("bottom", "top", 500, 0)
    middle = Peer("middle", "top", 500, 220)
    top = Peer("top", "top", 500, 420)
    remote = Peer("remote", "top", 650, 80)
    side = Peer("side", "left", 500, 80)
    group = [bottom, middle, top, remote, side]

    # Entry/close targets must be nearest lower same-anchor peers only.
    assert lower_peer(top, group) == middle
    assert lower_peer(middle, group) == bottom
    assert lower_peer(bottom, group) is None
    assert remote not in (lower_peer(top, group), lower_peer(middle, group))
    assert side not in (lower_peer(top, group), lower_peer(middle, group))

    # Closing top freezes only the surviving same-anchor group.
    assert frozen_survivors(top, group) == {"bottom", "middle"}

    # If middle closes while top is already a visual-only closing tail, top is
    # no longer a semantic survivor; bottom remains frozen until middle ends.
    after_top_semantic_close = [
        bottom, Peer("middle", "top", 500, 220, True),
        Peer("top", "top", 500, 420, False), remote, side
    ]
    assert frozen_survivors(after_top_semantic_close[1], after_top_semantic_close) == {"bottom"}

    # Reopen/cancel of the middle transaction releases its own freeze; any
    # independent transaction may still rebuild its own same-anchor map.
    assert frozen_survivors(remote, group) == set()
    assert frozen_survivors(side, group) == set()

    print("Pyramid Popup v2 transaction-order contract: ok")


if __name__ == "__main__":
    main()
