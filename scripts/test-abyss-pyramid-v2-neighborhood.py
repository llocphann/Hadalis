#!/usr/bin/env python3
"""Pyramid v2 grouping for the common two-popup, different-anchor case."""
from dataclasses import dataclass
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]


@dataclass(frozen=True)
class D:
    edge: str
    start: float
    end: float
    proximity: float = 24


def gap(a: D, b: D) -> float:
    if a.edge != b.edge:
        return float("inf")
    if a.end < b.start:
        return b.start-a.end
    if b.end < a.start:
        return a.start-b.end
    return 0


def related(a: D, b: D) -> bool:
    return a.edge == b.edge and gap(a,b) <= max(a.proximity,b.proximity)


def component(seed: D, pool: list[D]) -> list[D]:
    result=[]
    frontier=[seed]
    pending=list(pool)
    changed=True
    while changed:
        changed=False
        for item in pending[:]:
            if any(related(item,member) for member in frontier):
                result.append(item)
                frontier.append(item)
                pending.remove(item)
                changed=True
    return result


placement=(ROOT/"modules/abyss/looks/AbyssBodyPlacement.js").read_text()
coord=(ROOT/"modules/abyss/AbyssPyramidCoordinator.qml").read_text()
host=(ROOT/"modules/abyss/AbyssBodyHost.qml").read_text()

assert "property real stackProximity: 24" in host
assert "stackProximity:root.stackProximity" in host
assert "function _pyramidDescriptorsRelated(a,b)" in placement
assert "function _samePyramidNeighborhood(a,b)" in placement
assert "function _pyramidDescriptorsRelated(a,b): bool" in coord
assert "function _pyramidGroupCandidates(identity, request," in coord
assert "descriptors.some(descriptor =>" in coord

# Typical pair: centers are far apart, but popup bodies overlap tangentially.
a=D("top",100,420)
b=D("top",350,640)
assert abs((a.start+a.end)/2-(b.start+b.end)/2) > 2
assert related(a,b)

# The allocator's normal 24px clearance also joins a near pair.
near=D("top",430,620)
assert gap(a,near) == 10
assert related(a,near)

# Far-apart same-Edge and perpendicular popups stay independent.
far=D("top",470,650)
side=D("left",350,640)
assert gap(a,far) == 50
assert not related(a,far)
assert not related(a,side)

# Grouping is transitive to match the allocator's union-find.
c=D("top",620,850)
assert related(b,c)
assert not related(a,c)
assert component(a,[b,c,far]) == [b,c,far]  # far is linked indirectly through b
assert component(a,[b,c,D("top",900,1100)]) == [b,c]

print("Pyramid Popup v2 tangent-neighborhood contract: ok")
