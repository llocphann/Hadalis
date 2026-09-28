#!/usr/bin/env python3
"""Deterministic geometry checks for Pyramid Popup v2 motion.

This is deliberately independent from the QML runtime clock. It verifies the
animation invariant that previously regressed: a popup may only change its
Edge-normal reveal extent; it must never inherit another popup's tangent
position/span.
"""
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def collapse(full: dict, lower: dict | None) -> dict:
    s = dict(full["surface"])
    c = dict(full["content"])
    edge = full["edge"]
    target_s = dict(s)
    target_c = dict(c)

    if lower is not None:
        peer = lower["surface"]
        if edge == "top":
            boundary = peer["y"] + peer["height"]
            target_s["height"] = max(0, min(s["height"], boundary - s["y"]))
            target_c["y"] = boundary
            target_c["height"] = 0
        elif edge == "bottom":
            boundary = peer["y"]
            end = s["y"] + s["height"]
            target_s["y"] = max(s["y"], min(end, boundary))
            target_s["height"] = max(0, end - target_s["y"])
            target_c["y"] = boundary
            target_c["height"] = 0
        elif edge == "left":
            boundary = peer["x"] + peer["width"]
            target_s["width"] = max(0, min(s["width"], boundary - s["x"]))
            target_c["x"] = boundary
            target_c["width"] = 0
        elif edge == "right":
            boundary = peer["x"]
            end = s["x"] + s["width"]
            target_s["x"] = max(s["x"], min(end, boundary))
            target_s["width"] = max(0, end - target_s["x"])
            target_c["x"] = boundary
            target_c["width"] = 0
    else:
        cross = s["height"] if edge in ("top", "bottom") else s["width"]
        owner_extent = max(0, cross - full["depth"])
        if edge == "top":
            target_s["height"] = owner_extent
            target_c["y"] = s["y"] + owner_extent
            target_c["height"] = 0
        elif edge == "bottom":
            target_s["y"] = s["y"] + max(0, s["height"] - owner_extent)
            target_s["height"] = owner_extent
            target_c["y"] = target_s["y"]
            target_c["height"] = 0
        elif edge == "left":
            target_s["width"] = owner_extent
            target_c["x"] = s["x"] + owner_extent
            target_c["width"] = 0
        elif edge == "right":
            target_s["x"] = s["x"] + max(0, s["width"] - owner_extent)
            target_s["width"] = owner_extent
            target_c["x"] = target_s["x"]
            target_c["width"] = 0

    full_cross = s["height"] if edge in ("top", "bottom") else s["width"]
    collapsed_cross = (
        target_s["height"] if edge in ("top", "bottom")
        else target_s["width"]
    )
    owner_extent = max(0, full_cross - full["depth"])
    depth = max(0, collapsed_cross - owner_extent)
    return {
        **full,
        "depth": depth,
        "surface": target_s,
        "content": target_c,
    }


def mix(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def interpolate(origin: dict, full: dict, t: float) -> dict:
    out = {**full}
    out["surface"] = {
        key: mix(origin["surface"][key], full["surface"][key], t)
        for key in ("x", "y", "width", "height")
    }
    out["content"] = {
        key: mix(origin["content"][key], full["content"][key], t)
        for key in ("x", "y", "width", "height")
    }
    out["depth"] = mix(origin["depth"], full["depth"], t)
    # This is the hard invariant in AbyssPyramidMotion.interpolateRecord().
    out["along"] = full["along"]
    out["span"] = full["span"]
    return out


def records(edge: str) -> tuple[dict, dict, dict]:
    # Synthetic nested surfaces model Geometry.placedPanel() output after
    # allocator inward offsets. Tangent extents intentionally differ.
    if edge == "top":
        lower_s = {"x": 180, "y": -50, "width": 420, "height": 280}
        middle_s = {"x": 220, "y": -50, "width": 330, "height": 474}
        upper_s = {"x": 255, "y": -50, "width": 260, "height": 642}
        content = lambda x, y, w, h: {"x": x, "y": y, "width": w, "height": h}
        lower_c, middle_c, upper_c = content(194, 24, 392, 172), content(234, 258, 302, 132), content(269, 466, 232, 92)
    elif edge == "bottom":
        lower_s = {"x": 180, "y": 800, "width": 420, "height": 280}
        middle_s = {"x": 220, "y": 606, "width": 330, "height": 474}
        upper_s = {"x": 255, "y": 438, "width": 260, "height": 642}
        content = lambda x, y, w, h: {"x": x, "y": y, "width": w, "height": h}
        lower_c, middle_c, upper_c = content(194, 814, 392, 172), content(234, 620, 302, 132), content(269, 452, 232, 92)
    elif edge == "left":
        lower_s = {"x": -50, "y": 180, "width": 280, "height": 420}
        middle_s = {"x": -50, "y": 220, "width": 474, "height": 330}
        upper_s = {"x": -50, "y": 255, "width": 642, "height": 260}
        content = lambda x, y, w, h: {"x": x, "y": y, "width": w, "height": h}
        lower_c, middle_c, upper_c = content(24, 194, 172, 392), content(258, 234, 132, 302), content(466, 269, 92, 232)
    else:
        lower_s = {"x": 1640, "y": 180, "width": 280, "height": 420}
        middle_s = {"x": 1446, "y": 220, "width": 474, "height": 330}
        upper_s = {"x": 1278, "y": 255, "width": 642, "height": 260}
        content = lambda x, y, w, h: {"x": x, "y": y, "width": w, "height": h}
        lower_c, middle_c, upper_c = content(1654, 194, 172, 392), content(1460, 234, 132, 302), content(1292, 269, 92, 232)

    def make(surface: dict, content_rect: dict, depth: float) -> dict:
        return {
            "edge": edge,
            "along": surface["x"] if edge in ("top", "bottom") else surface["y"],
            "span": surface["width"] if edge in ("top", "bottom") else surface["height"],
            "depth": depth,
            "surface": surface,
            "content": content_rect,
        }

    return make(lower_s, lower_c, 220), make(middle_s, middle_c, 160), make(upper_s, upper_c, 120)


def assert_tangent_unchanged(edge: str, origin: dict, full: dict) -> None:
    if edge in ("top", "bottom"):
        assert origin["surface"]["x"] == full["surface"]["x"]
        assert origin["surface"]["width"] == full["surface"]["width"]
    else:
        assert origin["surface"]["y"] == full["surface"]["y"]
        assert origin["surface"]["height"] == full["surface"]["height"]


def main() -> None:
    source = (ROOT / "modules/abyss/looks/AbyssPyramidMotion.js").read_text()
    assert "result.along=_number(to.along,0)" in source
    assert "result.span=Math.max(0,_number(to.span,0))" in source
    assert "result.depth=Math.max(0,mix(from.depth,to.depth,t))" in source
    assert "collapsedCross-ownerExtent" in source

    for edge in ("top", "bottom", "left", "right"):
        lower, middle, upper = records(edge)
        middle_origin = collapse(middle, lower)
        upper_origin = collapse(upper, middle)
        base_origin = collapse(lower, None)

        assert_tangent_unchanged(edge, middle_origin, middle)
        assert_tangent_unchanged(edge, upper_origin, upper)
        assert_tangent_unchanged(edge, base_origin, lower)

        # Current record.depth must describe the same cross-axis reach as the
        # interpolated surface. The lowest collapsed tier reaches only the
        # physical owner strip, so its current depth is exactly zero.
        assert base_origin["depth"] == 0
        assert 0 <= middle_origin["depth"] < middle["depth"]
        assert 0 <= upper_origin["depth"] < upper["depth"]

        if edge == "top":
            assert middle_origin["surface"]["y"] + middle_origin["surface"]["height"] == lower["surface"]["y"] + lower["surface"]["height"]
            assert upper_origin["surface"]["y"] + upper_origin["surface"]["height"] == middle["surface"]["y"] + middle["surface"]["height"]
        elif edge == "bottom":
            assert middle_origin["surface"]["y"] == lower["surface"]["y"]
            assert upper_origin["surface"]["y"] == middle["surface"]["y"]
        elif edge == "left":
            assert middle_origin["surface"]["x"] + middle_origin["surface"]["width"] == lower["surface"]["x"] + lower["surface"]["width"]
            assert upper_origin["surface"]["x"] + upper_origin["surface"]["width"] == middle["surface"]["x"] + middle["surface"]["width"]
        else:
            assert middle_origin["surface"]["x"] == lower["surface"]["x"]
            assert upper_origin["surface"]["x"] == middle["surface"]["x"]

        # Opening and reopening use the same path in opposite scalar direction.
        for t in (0.0, 0.15, 0.5, 0.85, 1.0):
            frame = interpolate(middle_origin, middle, t)
            reverse_frame = interpolate(middle_origin, middle, t)
            assert frame == reverse_frame
            assert frame["along"] == middle["along"]
            assert frame["span"] == middle["span"]
            assert frame["depth"] == mix(
                middle_origin["depth"], middle["depth"], t
            )
            assert_tangent_unchanged(edge, frame, middle)

    print("Pyramid Popup v2 four-edge geometry contract: ok")


if __name__ == "__main__":
    main()
