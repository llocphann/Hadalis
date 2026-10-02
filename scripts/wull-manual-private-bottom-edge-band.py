#!/usr/bin/env python3
"""One owned PRIVATE original BOTTOM×1.5 FULL margin0..3 visual band probe.

Reuse UNCHANGED actually owner-PASSED original static four-margin Qt
fixture/runner and exact original QML, capture guards, source verification,
private original 320×300 RGBA8 images. Only NEW pure raster-band model runs
after that same private 4-image Qt capture. No live host screenshot, panel,
compositor, pointer, production source modification or publication.
"""
import os
from pathlib import Path
import runpy
import sys

ROOT = Path(__file__).resolve().parents[1]
BASE = "scripts/wull-manual-private-bottom-inset.py"
BASE_BLOB = "75f923b104c8409b3532a809c3ba62cfd5998e03"
MODEL = "scripts/wull-private-bottom-edge-band-model.py"
MODEL_BLOB = "dbfb226a4fa5f53154df25a6bd69d90674372a0f"
ALPHA = "scripts/wull-private-painted-alpha-model.py"
ALPHA_BLOB = "fa9e7c2af87ee830336988fa7060e2720e816ed0"
MARGINS = (0, 1, 2, 3)


class Stop(Exception):
    pass


def require(condition, code):
    if not condition:
        raise Stop(code)


def checked_sources():
    previous = runpy.run_path(
        str(ROOT / BASE), run_name="wull_original_bottom_static_fixture_borrow")
    # Reuse the owner's previously qualified source-pinned private runner:
    # audit exact clone/current remote dev, original QML/fixture, owner 0700,
    # private DBus/offscreen Qt0.3.1, process isolation/cleanup, 4 PNGs.
    core, source = previous["checked_sources"]()
    git = core["git"]
    for path, blob in ((BASE, BASE_BLOB), (MODEL, MODEL_BLOB),
                       (ALPHA, ALPHA_BLOB)):
        require(git("rev-parse", "HEAD:" + path) == blob,
                "EDGE_BAND_SOURCE_DRIFT")
    return previous, core, source


def private_classify(directory, previous):
    # Old secure_png verifies exact owner UID, mode0600 regular non-symlink,
    # <=1 MiB per actual private PNG. A new unexpected file is disallowed.
    expected = {"m" + str(n) + ".private.png" for n in MARGINS}
    found = {p.name for p in directory.glob("*.private.png")}
    require(found == expected, "EDGE_BAND_CAPTURE_SET_INVALID")
    images = {
        n: previous["secure_png"](
            directory / ("m" + str(n) + ".private.png"))
        for n in MARGINS
    }
    model = runpy.run_path(
        str(ROOT / MODEL), run_name="private_wull_bottom_edge_alpha_model")
    alpha = runpy.run_path(
        str(ROOT / ALPHA), run_name="original_private_wull_rgba8_decoder")
    try:
        return model["classify"](images, alpha)
    except (ValueError, TypeError, KeyError):
        raise Stop("EDGE_BAND_ALPHA_INCONCLUSIVE")


def main():
    require(sys.argv[1:] == ["--acknowledge-private-original-bottom-edge-band"],
            "EDGE_BAND_EXPLICIT_OPT_IN_REQUIRED")
    os.umask(0o077)
    previous, core, source = checked_sources()
    try:
        # Executes exactly the historical ORIGINAL FULL frozen margin0..3
        # one-instance private owned offscreen capture and all old gates.
        qualified_previous = previous["private_run"](core)
    except (previous["Stop"], previous["ReviewedQmlFailure"]):
        raise Stop("REUSED_ORIGINAL_PRIVATE_QT_UNQUALIFIED")
    require(qualified_previous["four_frames"] == 4
            and qualified_previous["original_zero_margin_exterior"] is True
            and qualified_previous["exterior_by_margin"][1] is False,
            "PRIOR_STATIC_MARGIN_CANDIDATE_NOT_REPRODUCED")
    results = private_classify(ROOT.parent / "bottom-inset", previous)
    require(results["margin0_exterior_positive"] is True
            and results["margin1_exterior_negative"] is True
            and results["original_margin0_boundary_band_positive"] is True
            and set(results["inner_boundary_band_by_margin"]) == set(MARGINS),
            "EDGE_BAND_RESULTS_UNQUALIFIED")
    require(core["git"]("rev-parse", "HEAD") == source and
            not core["git"]("status", "--porcelain=v1",
                            "--untracked-files=all"),
            "EDGE_BAND_POSTRUN_SOURCE_CHANGED")
    print("SOURCE_SHA=" + source)
    print("STATIC_REUSED_ORIGINAL_FULL_FIXTURE=SOURCE_PINNED")
    print("ONE_PRIVATE_ORIGINAL_QT_INSTANCE_FROZEN_POSE=YES")
    print("ACTUAL_PRIVATE_RGBA8_FRAMES=4")
    print("BASELINE_M0_EXTERIOR=YES")
    print("CANDIDATE_M1_EXTERIOR=NO")
    for margin in MARGINS:
        print("M" + str(margin) + "_INNER_EDGE_BAND=" +
              ("YES" if results["inner_boundary_band_by_margin"][margin]
               else "NO"))
    print("M1_POTENTIAL_PIXEL_BAND_GAP_SIGNAL=" +
          ("YES" if results["candidate_margin1_no_boundary_band_signal"]
           else "NO"))
    print("REAL_PANEL_VISUAL_CONNECTION=UNTESTED")
    print("DYNAMIC_MOTION=NOT_TESTED")
    print("COMPOSITOR_AND_POINTER=UNTESTED")
    print("PRODUCTION_MASK_CHANGED=NO")
    print("GATE=PRIVATE_BOTTOM_EDGE_BAND_CLASSIFIED")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        categories = {
            "EDGE_BAND_EXPLICIT_OPT_IN_REQUIRED",
            "EDGE_BAND_SOURCE_DRIFT",
            "EDGE_BAND_CAPTURE_SET_INVALID",
            "EDGE_BAND_ALPHA_INCONCLUSIVE",
            "REUSED_ORIGINAL_PRIVATE_QT_UNQUALIFIED",
            "PRIOR_STATIC_MARGIN_CANDIDATE_NOT_REPRODUCED",
            "EDGE_BAND_RESULTS_UNQUALIFIED",
            "EDGE_BAND_POSTRUN_SOURCE_CHANGED",
        }
        code = str(exc)
        print("GATE=" + (code if code in categories
                         else "PRIVATE_BOTTOM_EDGE_BAND_UNAVAILABLE"))
        raise SystemExit(1)
