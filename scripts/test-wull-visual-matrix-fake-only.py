#!/usr/bin/env python3
"""No Qt/no desktop: real matrix PNG gate with fake transparent RGBA frames."""
import hashlib
import os
from pathlib import Path
import runpy
import struct
import tempfile
import zlib

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = (ROOT / "scripts/wull-fixtures/visual-matrix/shell.qml").read_text()
RUNNER = (ROOT / "scripts/wull-manual-visual-matrix.py").read_text()
assert FIXTURE.count("AbyssCompanion {") == 4
assert "captureStage.grabToImage" not in FIXTURE  # the owned Item is sheet
assert "sheet.grabToImage" in FIXTURE
for marker in ("FOUR_HOSTS_FROZEN", "SYNTHETIC_SHEET_SAVED",
               'Quickshell.env("WULL_VISUAL_MATRIX_PRIVATE_FILE")',
               'Qt.size(512, 512)'):
    assert marker in FIXTURE
for marker in ('"QT_QPA_PLATFORM": "offscreen"', '"WAYLAND_DISPLAY"',
               '"WAYLAND_SOCKET"', '"NIRI_SOCKET"', '"DISPLAY"',
               "stdin=subprocess.DEVNULL", "start_new_session=True",
               'stat.S_IMODE(entry.st_mode) & 0o077',
               "REFERENCE_SIMILARITY=UNREVIEWED",
               "REAL_PANEL_OR_POINTER=NOT_TESTED"):
    assert marker in RUNNER, marker
assert "shell=True" not in RUNNER
assert "grim " not in RUNNER and "git push" not in RUNNER

mod = runpy.run_path(str(ROOT / "scripts/wull-manual-visual-matrix.py"),
                     run_name="wull_fake_only_matrix")
assert len(mod["ROI"]) == 4
assert all(0 <= x0 < x1 <= 512 and 0 <= y0 < y1 <= 512
           for x0, y0, x1, y1 in mod["ROI"])


def chunk(kind, content):
    return (struct.pack(">I", len(content)) + kind + content +
            struct.pack(">I", zlib.crc32(kind + content) & 0xffffffff))


def rgba_sheet(enabled=(0, 1, 2, 3)):
    w = h = 512
    pixels = bytearray()
    for y in range(h):
        pixels.append(0)
        for x in range(w):
            active = any(i in enabled and x0 + 12 <= x < x0 + 46
                         and y0 + 12 <= y < y0 + 46
                         for i, (x0, y0, _, _) in enumerate(mod["ROI"]))
            pixels.extend((48, 170, 210, 255 if active else 0))
    header = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) +
            chunk(b"IDAT", zlib.compress(bytes(pixels), 9)) +
            chunk(b"IEND", b""))


with tempfile.TemporaryDirectory(prefix="wull-matrix-fake-") as root:
    image = Path(root) / "synthetic.png"
    valid = rgba_sheet()
    image.write_bytes(valid)
    image.chmod(0o600)
    assert mod["classify"](image) == hashlib.sha256(valid).hexdigest()
    image.write_bytes(rgba_sheet((0, 1, 2)))
    try:
        mod["classify"](image)
        raise AssertionError("unpainted fourth cell accepted")
    except mod["NotQualified"] as error:
        assert str(error) == "PRIVATE_CELL_PAINT_UNQUALIFIED"
    image.write_bytes(valid[:-7] + b"bad-png")
    try:
        mod["classify"](image)
        raise AssertionError("corrupted PNG accepted")
    except mod["NotQualified"] as error:
        assert str(error) == "PRIVATE_PNG_FORMAT_UNQUALIFIED"

print("WULL_VISUAL_MATRIX_FAKE_ONLY_PASS")
