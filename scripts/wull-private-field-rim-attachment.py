#!/usr/bin/env python3
"""INERT, reversible owner-private BOTTOM Wull inner Abyss field-rim candidate.

Both cases use the same exact ORIGINAL Wull with private bottomMargin=.25.
The only comparison change is the private copy of AbyssPerimeter's BOTTOM
host coordinate: bind to actual shader-field inset/local Bar deformation
under Wull's footprint instead of fixed physical perimeterThickness.
NO production source change, no Qt/Wayland/input/screenshot/Git operations.
"""
import hashlib
from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[1]
OLD = "scripts/wull-private-panel-quarter-shadow.py"
OLD_BLOB = "dd62b2b834e86d41856730547bca8ea4d73aaca8"
LAYOUT = "modules/abyss/looks/AbyssLayout.js"
LAYOUT_BLOB = "f65d9c1922696d236fc0d3bfee735ad8df16924b"
FIELD = "modules/abyss/looks/AbyssField.frag"
FIELD_BLOB = "75af27a7220d364b2eb1700bb7b29cc19c8ae2bd"
STYLE = "modules/abyss/looks/AbyssStyle.qml"
STYLE_BLOB = "4cc05dbaf547a3eff366647cb388abe8c31af5d5"
FIELD_QML = "modules/abyss/looks/AbyssField.qml"
FIELD_QML_BLOB = "6b9588b1233748991f1dfeaa886879d51c7c0530"
FIELD_QSB = "modules/abyss/looks/AbyssField.frag.qsb"
FIELD_QSB_BLOB = "fe36c75ceb1bab6d4676e87512ee549b8d100f45"
BAR = "modules/abyss/bar/AbyssBar.qml"
BAR_BLOB = "b9d91627734d0cfdf3057d598f7ec600649be45c"
SURFACE = "modules/abyss/AbyssSurfaceController.qml"
SURFACE_BLOB = "1fbbe81d2c9f62827c2e6835600caec01e24227f"
PERIMETER = "modules/abyss/AbyssPerimeter.qml"
PERIMETER_BLOB = "a3cd2a7bfbdf32dac2c7e42057a1dfaaeea214ac"
MODES = ("screen_boundary_m025", "inner_field_rim_m025")

# Exact reviewed first-stage function insertion: no input Region, renderer,
# settings, daemon or other screen-edge transform may change.
ALONG = """            function companionAlongPosition(): real {
                const horizontal = Geometry.horizontal(root.companionEdge)
                const extent = horizontal ? window.width : window.height
                const span = horizontal ? companion.implicitWidth * root.companionScale
                    : companion.implicitHeight * root.companionScale
                return WullHostPolicy.alongPosition(extent, span,
                    root.companionAlong)
            }
"""
FIELD_DEPTH = """            // PRIVATE ONLY: sample the real Abyss field's RESTING inner
            // boundary at the companion footprint, including local Bar
            // deformation. This does NOT yet track dynamic wave crests.
            function companionFieldDepth(): real {
                const horizontal = Geometry.horizontal(root.companionEdge)
                const footprint = (horizontal ? companion.implicitWidth
                    : companion.implicitHeight) * root.companionScale
                const along = window.companionAlongPosition() - footprint * 0.5
                const actual = window.bodyInsets(root.companionEdge,
                                                  along, footprint)
                const depth = Number(actual[root.companionEdge])
                return Number.isFinite(depth)
                    ? Math.max(AbyssStyle.perimeterThickness, depth)
                    : AbyssStyle.perimeterThickness
            }
"""
BOTTOM_OLD = "                        : window.height - AbyssStyle.perimeterThickness - implicitHeight + 5"
BOTTOM_NEW = "                        : window.height - window.companionFieldDepth() - implicitHeight + 5"

def blob(raw):
    return hashlib.sha1(b"blob " + str(len(raw)).encode("ascii")
                        + b"\0" + raw).hexdigest()

def original_pins(repo):
    checks = ((OLD, OLD_BLOB), (LAYOUT, LAYOUT_BLOB),
              (FIELD, FIELD_BLOB), (STYLE, STYLE_BLOB),
              (FIELD_QML, FIELD_QML_BLOB), (FIELD_QSB, FIELD_QSB_BLOB),
              (BAR, BAR_BLOB), (SURFACE, SURFACE_BLOB),
              (PERIMETER, PERIMETER_BLOB))
    if any(blob((Path(repo) / path).read_bytes()) != sha
           for path, sha in checks):
        raise ValueError("FIELD_ATTACHMENT_REVIEWED_SOURCE_MISMATCH")

def candidate(perimeter):
    if type(perimeter) is not bytes or blob(perimeter) != PERIMETER_BLOB:
        raise ValueError("FIELD_ATTACHMENT_PERIMETER_MISMATCH")
    original = perimeter.decode("utf-8")
    if original.count(ALONG) != 1 or original.count(BOTTOM_OLD) != 1:
        raise ValueError("FIELD_ATTACHMENT_QML_MARKER_MISMATCH")
    changed = original.replace(ALONG, ALONG + FIELD_DEPTH, 1)
    changed = changed.replace(BOTTOM_OLD, BOTTOM_NEW, 1)
    if (changed.replace(BOTTOM_NEW, BOTTOM_OLD, 1)
            .replace(ALONG + FIELD_DEPTH, ALONG, 1) != original):
        raise ValueError("FIELD_ATTACHMENT_NOT_REVERSIBLE")
    if changed.count("Region { item: WullHostPolicy.acceptsInput(") != 1:
        raise ValueError("FIELD_ATTACHMENT_INPUT_REGION_CHANGED")
    return changed.encode("utf-8")

def stage(repo, shell, mode):
    if mode not in MODES:
        raise ValueError("UNREVIEWED_FIELD_ATTACHMENT_MODE")
    repo, shell = Path(repo), Path(shell)
    original_pins(repo)
    base = runpy.run_path(str(repo / OLD),
                          run_name="private_wull_existing_shadow_only")
    # SAME private margin=.25 and QML import topology in BOTH cases.
    original_body = (repo / base["ORIGINAL"]).read_bytes()
    perimeter = (repo / PERIMETER).read_bytes()
    changed = candidate(perimeter)
    target = base["stage"](repo, shell, "private_bottom_m025")
    private_perimeter = shell / PERIMETER
    if private_perimeter.is_symlink() or private_perimeter.read_bytes() != perimeter:
        raise ValueError("PRIVATE_PERIMETER_STAGE_UNVERIFIED")
    if target.read_bytes() != base["generate"](original_body):
        raise ValueError("PRIVATE_IDENTICAL_BODY_UNVERIFIED")
    if mode == "inner_field_rim_m025":
        private_perimeter.write_bytes(changed)
        private_perimeter.chmod(0o600)
        if private_perimeter.read_bytes() != changed:
            raise ValueError("PRIVATE_FIELD_ATTACHMENT_WRITE_FAILED")
    if (blob((repo / PERIMETER).read_bytes()) != PERIMETER_BLOB
            or (repo / base["ORIGINAL"]).read_bytes() != original_body):
        raise ValueError("PRODUCTION_SOURCES_CHANGED")
    return target

LINK_NAMES = ("services", "GlobalStates.qml", "qmldir", "assets",
              "scripts", "defaults", "translations")

if __name__ == "__main__":
    raise SystemExit("PRIVATE_INERT_MODULE_ONLY")
