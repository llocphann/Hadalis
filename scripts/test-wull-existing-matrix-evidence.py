#!/usr/bin/env python3
"""Fake-only PNG/channel tests for retained private matrix inspector.

No Qt, no retained-file scan, no Git writes, no compositor, no publishing.
"""
import hashlib
from pathlib import Path
import runpy
import struct
import zlib

ROOT = Path(__file__).resolve().parents[1]
FILE = ROOT / "scripts/wull-existing-matrix-evidence.py"
source = FILE.read_text()
for required in (
    "RETAINED_FOUR_POSE_IMAGE=READ_ONLY_VERIFIED",
    "SEMANTIC_EXPRESSION_DIFFERENCE=NOT_PROVEN",
    "RENDERER_CHANGED_AFTER_CAPTURE", "PRIVATE_STAGE_UNQUALIFIED",
    "PRIVATE_EVIDENCE_UNAVAILABLE", 'not path.is_symlink()',
    'not stat.S_IMODE(info.st_mode) & 0o077',
    "SOURCE_IDENTITY_UNQUALIFIED", "rgba_verified", "mechanical_cells",
):
    assert required in source, required
for prohibited in ("git push", "grabToImage", "grim -o", "WAYLAND_DISPLAY=",
                   "shutil.rmtree", "stdout=output", "subprocess.Popen"):
    assert prohibited not in source, prohibited
mod = runpy.run_path(str(FILE), run_name="wull_fake_only_inspection")
assert len(mod["ROI"]) == 4


def chunk(name, value):
    return (struct.pack(">I", len(value)) + name + value
            + struct.pack(">I", zlib.crc32(name + value) & 0xffffffff))


def synthetic_rgba(enabled=(0, 1, 2, 3), colors=True):
    w = h = 512
    rows = bytearray()
    for y in range(h):
        rows.append(0)
        for x in range(w):
            matching = [
                i for i, (x0, y0, _, _) in enumerate(mod["ROI"])
                if i in enabled and x0 + 10 <= x < x0 + 67
                and y0 + 10 <= y < y0 + 67
            ]
            if matching:
                shade = x % 3 if colors else 0
                rgb = ((32, 90, 180), (86, 150, 230),
                       (160, 209, 255))[shade]
                rows.extend((*rgb, 255))
            else:
                rows.extend((0, 0, 0, 0))
    png = (b"\x89PNG\r\n\x1a\n"
           + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
           + chunk(b"IDAT", zlib.compress(bytes(rows), 9))
           + chunk(b"IEND", b""))
    return png


positive = synthetic_rgba()
w, h, rgba = mod["rgba_verified"](positive)
cells = mod["mechanical_cells"](w, h, rgba)
assert len(cells) == 4 and all(
    r["painted"] and r["multiple_rgba_color_bands"]
    and r["bounded_footprint"] for r in cells
)
assert hashlib.sha256(positive).digest()
w, h, rgba = mod["rgba_verified"](synthetic_rgba(colors=False))
assert all(not c["multiple_rgba_color_bands"]
           for c in mod["mechanical_cells"](w, h, rgba))
w, h, rgba = mod["rgba_verified"](synthetic_rgba(enabled=(0, 1, 2)))
try:
    mod["mechanical_cells"](w, h, rgba)
    raise AssertionError("unpainted fourth ROI accepted")
except mod["Unqualified"] as e:
    assert str(e) == "CELL_UNPAINTED"
try:
    mod["rgba_verified"](positive[:-9] + b"not-a-valid-png")
    raise AssertionError("corrupt RGBA PNG accepted")
except (ValueError, mod["Unqualified"]):
    pass
print("WULL_RETAINED_MATRIX_FAKE_ONLY_PASS")
