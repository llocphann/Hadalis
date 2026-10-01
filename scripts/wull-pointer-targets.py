#!/usr/bin/env python3
"""Pure, inert candidate targets for a guarded REAL nested-Niri click test.

No I/O, input injection or compositor operations. This only proposes the
first top-edge test positions using the reviewed production host equations.
A compositor-driven test MUST verify actual underlay and Wull events instead
of treating these coordinates as proof of an actual input region.
"""
from __future__ import annotations
import math


def top_edge_targets(width: int, height: int, *,
                     thickness: float = 16.0,
                     along: float = 0.72) -> dict:
    """Return top-edge body, empty-host-margin and exterior control points.

    Exact assumptions for the first controlled probe:
      scale=1; production host=112x98; production mapped body=76x92
      at (18,3) in the host; top-edge origin=(alongPosition-56,
      perimeterThickness-5). Settings are private deterministic overrides.
    """
    if (not isinstance(width, int) or isinstance(width, bool)
            or not isinstance(height, int) or isinstance(height, bool)
            or width < 480 or height < 240):
        raise ValueError("nested_output_too_small_or_invalid")
    if (not math.isfinite(thickness) or not 3 <= thickness <= 40
            or not math.isfinite(along) or not .08 <= along <= .92):
        raise ValueError("invalid_pinned_production_geometry")
    host_w, host_h = 112.0, 98.0
    mapped_x, mapped_y, mapped_w, mapped_h = 18.0, 3.0, 76.0, 92.0
    # Mirror reviewed WullHostPolicy.alongPosition for the pinned default
    # top-edge scale only. Keep source guards on the original JS/QML.
    margin = min(width * .5, max(32.0, host_w * .5 + 12.0))
    center_along = max(margin, min(width - margin, width * along))
    x, y = center_along - host_w * .5, thickness - 5
    body = (round(x + mapped_x + mapped_w * .5),
            round(y + mapped_y + mapped_h * .5))
    # Top bar occupies the upper edge; controls are below its default
    # 40px height, and the margin is outside the mapped body but INSIDE host.
    margin_point = (round(x + 9), body[1])
    exterior_x = round(x - 80 if x >= 90 else x + host_w + 80)
    exterior = (exterior_x, body[1])
    boxes = {
        "host": (x, y, host_w, host_h),
        "mapped_body": (x + mapped_x, y + mapped_y, mapped_w, mapped_h),
    }
    for point in (body, margin_point, exterior):
        if not (0 <= point[0] < width and 40 < point[1] < height):
            raise ValueError("candidate_point_outside_safe_nested_output")
    bx, by, bw, bh = boxes["mapped_body"]
    assert bx < body[0] < bx + bw and by < body[1] < by + bh
    assert margin_point[0] < bx and x < margin_point[0] < x + host_w
    assert not x <= exterior[0] <= x + host_w
    return {
        "edge": "top",
        "estimated_from_static_production_source": True,
        "host_bounds": tuple(round(v, 2) for v in boxes["host"]),
        "mapped_body_bounds": tuple(round(v, 2) for v in boxes["mapped_body"]),
        "body_center": body,
        "inside_host_outside_body": margin_point,
        "outside_host_control": exterior,
    }


def all_edge_targets(width: int, height: int, edge: str, *,
                     thickness: float = 16.0,
                     along: float = 0.72) -> dict:
    """Inert four-edge candidate coordinates, NOT compositor hit proof.

    Recorded actual production postchange geometry on four edges:
      horizontal hosts 112x98 / mapped body (18,3,76,92),
      vertical hosts 98x112 / mapped body (3,18,92,76).
    These top/bottom/left/right rectangles are conservative BBOXes:
    they are not the actual curved silhouette.
    """
    if edge == "top":
        return top_edge_targets(width, height, thickness=thickness, along=along)
    if edge not in ("bottom", "left", "right"):
        raise ValueError("unreviewed_pointer_edge")
    if (not isinstance(width, int) or isinstance(width, bool)
            or not isinstance(height, int) or isinstance(height, bool)
            or width < 480 or height < 240):
        raise ValueError("nested_output_too_small_or_invalid")
    if (not math.isfinite(thickness) or not 3 <= thickness <= 40
            or not math.isfinite(along) or not .08 <= along <= .92):
        raise ValueError("invalid_pinned_production_geometry")
    horizontal = edge == "bottom"
    host_w, host_h = (112.0, 98.0) if horizontal else (98.0, 112.0)
    mapped_x, mapped_y, mapped_w, mapped_h = (
        (18.0, 3.0, 76.0, 92.0) if horizontal
        else (3.0, 18.0, 92.0, 76.0))
    extent = width if horizontal else height
    span = host_w if horizontal else host_h
    margin = min(extent * .5, max(32.0, span * .5 + 12.0))
    along_center = max(margin, min(extent - margin, extent * along))
    if horizontal:
        x, y = along_center - host_w * .5, height - thickness - host_h + 5
    else:
        x = thickness - 5 if edge == "left" else width - thickness - host_w + 5
        y = along_center - host_h * .5
    body = (
        round(x + mapped_x + mapped_w * .5),
        round(y + mapped_y + mapped_h * .5))
    # On each side use the 9px empty strip INSIDE the full host, while
    # the exterior controls stay a safe 80px beyond the host box.
    if horizontal:
        inside = (round(x + 9), body[1])
        exterior_x = round(x - 80 if x >= 90 else x + host_w + 80)
        exterior = (exterior_x, body[1])
    else:
        inside = (body[0], round(y + 9))
        exterior_y = round(y - 80 if y >= 90 else y + host_h + 80)
        exterior = (body[0], exterior_y)
    # Four-edge probe forbids ambiguous input at physical compositor edges.
    for px, py in (body, inside, exterior):
        if not (px >= 2 and px < width - 2 and
                py >= 41 and py < height - 2):
            raise ValueError("candidate_point_outside_safe_nested_output")
    bx, by = x + mapped_x, y + mapped_y
    if not (bx < body[0] < bx + mapped_w
            and by < body[1] < by + mapped_h):
        raise ValueError("body_target_outside_production_bbox")
    if horizontal:
        if not (x < inside[0] < bx and
                (exterior[0] < x or exterior[0] > x + host_w)):
            raise ValueError("horizontal_control_target_invalid")
    elif not (y < inside[1] < by
              and (exterior[1] < y or exterior[1] > y + host_h)):
        raise ValueError("vertical_control_target_invalid")
    return {
        "edge": edge,
        "estimated_from_static_production_source": True,
        "host_bounds": tuple(round(v, 2) for v in (x, y, host_w, host_h)),
        "mapped_body_bounds": tuple(
            round(v, 2) for v in (bx, by, mapped_w, mapped_h)),
        "body_center": body,
        "inside_host_outside_body": inside,
        "outside_host_control": exterior,
    }
