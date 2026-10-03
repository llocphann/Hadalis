#!/usr/bin/env python3
"""FAKE ONLY: private original-body m025 vs field-rim attachment contract.

No Qt, Niri, screen capture, device access, pointer injection or network.
"""
import hashlib
import os
from pathlib import Path
import runpy
import stat
import tempfile

os.umask(0o077)
ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / "scripts/wull-private-field-rim-attachment.py"
EXPECTED_HELPER = "b7c2ac861ab11073540d113df86a1339c7f43e6e"
ORIGINAL_BASE = ROOT / "scripts/wull-private-panel-quarter-shadow.py"
ORIGINAL_BASE_BLOB = "dd62b2b834e86d41856730547bca8ea4d73aaca8"
PERIMETER = ROOT / "scripts/wull-fixtures/historical/pre-surface-attachment-perimeter.snapshot"
PERIMETER_BLOB = "a3cd2a7bfbdf32dac2c7e42057a1dfaaeea214ac"
BODY = ROOT / "scripts/wull-fixtures/historical/pre-surface-attachment-companion.snapshot"
BODY_BLOB = "b5b01835a282458eba0d0268396ae2c350d919d2"
DEPS = {
    "modules/abyss/looks/AbyssLayout.js":
        "f65d9c1922696d236fc0d3bfee735ad8df16924b",
    "modules/abyss/looks/AbyssField.frag":
        "75af27a7220d364b2eb1700bb7b29cc19c8ae2bd",
    "modules/abyss/looks/AbyssStyle.qml":
        "4cc05dbaf547a3eff366647cb388abe8c31af5d5",
    "modules/abyss/looks/AbyssField.qml":
        "6b9588b1233748991f1dfeaa886879d51c7c0530",
    "modules/abyss/looks/AbyssField.frag.qsb":
        "fe36c75ceb1bab6d4676e87512ee549b8d100f45",
    "modules/abyss/bar/AbyssBar.qml":
        "b9d91627734d0cfdf3057d598f7ec600649be45c",
    "modules/abyss/AbyssSurfaceController.qml":
        "1fbbe81d2c9f62827c2e6835600caec01e24227f",
}
# This consumed proof uses its original field, just like its original body and
# perimeter above. Preserve every reviewed hash and the helper's drift guard;
# production's new shared water has independent current-source coverage.
FROZEN_FIELDS = {
    "modules/abyss/looks/AbyssField.frag": ROOT / "scripts/wull-fixtures/historical/pre-shared-water-field-frag.snapshot",
    "modules/abyss/looks/AbyssField.qml": ROOT / "scripts/wull-fixtures/historical/pre-shared-water-field-qml.snapshot",
    "modules/abyss/looks/AbyssField.frag.qsb": ROOT / "scripts/wull-fixtures/historical/pre-shared-water-field-qsb.snapshot",
}
def dependency_bytes(path):
    return FROZEN_FIELDS.get(path, ROOT / path).read_bytes()

def blob(data):
    return hashlib.sha1(
        b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()
for file, sha in ((HELPER, EXPECTED_HELPER),
                  (ORIGINAL_BASE, ORIGINAL_BASE_BLOB),
                  (PERIMETER, PERIMETER_BLOB), (BODY, BODY_BLOB)):
    assert blob(file.read_bytes()) == sha, file.name
for path, sha in DEPS.items():
    assert blob(dependency_bytes(path)) == sha, path

x = runpy.run_path(str(HELPER), run_name="inert_only_no_local_session")
base = runpy.run_path(str(ORIGINAL_BASE), run_name="inert_only_base")
assert x["MODES"] == ("screen_boundary_m025", "inner_field_rim_m025")
assert x["OLD_BLOB"] == ORIGINAL_BASE_BLOB
assert x["PERIMETER_BLOB"] == PERIMETER_BLOB
perimeter = PERIMETER.read_bytes()
candidate = x["candidate"](perimeter).decode()
original = perimeter.decode()
along, field = x["ALONG"], x["FIELD_DEPTH"]
yold, ynew = x["BOTTOM_OLD"], x["BOTTOM_NEW"]
assert original.count(along) == original.count(yold) == 1
assert candidate.count(along + field) == 1
assert candidate.count(ynew) == 1 and yold not in candidate
assert (candidate.replace(ynew, yold).replace(along + field, along)
        == original)
assert candidate.count("Region { item: WullHostPolicy.acceptsInput(") == 1
assert 'window.bodyInsets(root.companionEdge,' in candidate
assert 'const footprint = (horizontal ? companion.implicitWidth' in candidate
assert 'const along = window.companionAlongPosition() - footprint * 0.5' in candidate
assert 'Math.max(AbyssStyle.perimeterThickness, depth)' in candidate
assert "AbyssStyle.perimeterThickness - implicitHeight + 5" not in candidate
assert original.count("AbyssCompanion {") == candidate.count("AbyssCompanion {")
assert original.count("mask: window.overviewDragging") == candidate.count(
    "mask: window.overviewDragging")
assert original.count("AbyssBar {") == candidate.count("AbyssBar {")
try:
    x["candidate"](perimeter + b"\n// drift")
except ValueError as exc:
    assert str(exc) == "FIELD_ATTACHMENT_PERIMETER_MISMATCH"
else:
    raise AssertionError("Accepted unreviewed field attachment source")

# Strictly synthetic geometry: local 48px or 64px field depth must
# move the same Wull m025 INWARD relative to old fixed 16px perimeter.
# These positions are geometry witnesses, NOT pixel/visual acceptance.
def bottom_origin(viewport, rest_depth, item_height=98, overlap=5):
    return viewport - rest_depth - item_height + overlap
assert bottom_origin(720, 16) == 611
assert bottom_origin(720, 48) == 579
assert bottom_origin(720, 64) == 563
assert bottom_origin(720, 48) - bottom_origin(720, 16) == -32

with tempfile.TemporaryDirectory(prefix="wull-paint-canary.") as temp:
    work = Path(temp)
    clone = work / "repo"
    body = clone / base["ORIGINAL"]
    body.parent.mkdir(parents=True, mode=0o700)
    body.write_bytes(BODY.read_bytes())
    (clone / "modules" / "common").mkdir(mode=0o700)
    (clone / "modules" / "common" / "Other.qml").write_text("Item {}\n")
    (clone / "modules" / "abyss" / "Other.qml").write_text("Item {}\n")
    (clone / base["PERIMETER"]).write_bytes(perimeter)
    for name in DEPS:
        item = clone / name
        item.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
        item.write_bytes(dependency_bytes(name))
    (clone / "scripts").mkdir(mode=0o700)
    (clone / x["OLD"]).write_bytes(ORIGINAL_BASE.read_bytes())
    shell0 = work / "private" / "baseline" / "shell"
    shell1 = work / "private" / "candidate" / "shell"
    for shell in (shell0, shell1):
        shell.mkdir(parents=True, mode=0o700)
    same = x["stage"](clone, shell0, "screen_boundary_m025")
    moved = x["stage"](clone, shell1, "inner_field_rim_m025")
    assert same.read_bytes() == moved.read_bytes() == base["generate"](
        BODY.read_bytes())
    source0 = shell0 / x["PERIMETER"]
    source1 = shell1 / x["PERIMETER"]
    assert source0.read_bytes() == perimeter
    assert source1.read_bytes().decode() == candidate
    assert source0.read_bytes() != source1.read_bytes()
    assert stat.S_IMODE(source1.stat().st_mode) == 0o600
    assert (clone / x["PERIMETER"]).read_bytes() == perimeter
    assert body.read_bytes() == BODY.read_bytes()
    try:
        x["stage"](clone, shell1, "inner_field_rim_m025")
    except ValueError:
        pass
    else:
        raise AssertionError("Accepted preexisting private QML shadow")
    try:
        x["stage"](clone, work / "invalid", "unreviewed")
    except ValueError as exc:
        assert str(exc) == "UNREVIEWED_FIELD_ATTACHMENT_MODE"
    else:
        raise AssertionError("Accepted unreviewed mode")
    reviewed_field = clone / x["FIELD"]
    reviewed_field.write_bytes(reviewed_field.read_bytes() + b"\n// drift")
    try:
        x["original_pins"](clone)
    except ValueError as exc:
        assert str(exc) == "FIELD_ATTACHMENT_REVIEWED_SOURCE_MISMATCH"
    else:
        raise AssertionError("Accepted drift in a frozen field dependency")

print("WULL_PRIVATE_FIELD_RIM_ATTACHMENT_INERT_PASS")
