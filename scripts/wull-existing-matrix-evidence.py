#!/usr/bin/env python3
"""Read ONLY the retained exact-source private synthetic Wull matrix.

No Qt rerun, screenshot creation, private pixels/paths in stdout, Git writes
or host desktop access. If retained evidence is unavailable, fail closed.
All final findings are mechanical RGBA tests, NOT aesthetic acceptance.
"""
import hashlib
import json
import os
from pathlib import Path
import runpy
import stat
import struct
import subprocess
import sys
import zlib

ROOT = Path(__file__).resolve().parents[1]
SOURCE = "8325d22cd7f37d92d36239e015902a52ed6ee986"
JOB = "JOB-WULL-VM-P1E0042-20261002-03"
PROFILE = "profile-1e0042aca8e24db2"
ROI = ((75, 80, 240, 235), (290, 80, 480, 235),
       (75, 310, 240, 485), (290, 310, 480, 485))
MANIFEST = ROOT / "docs/wull-visual/runs/20261002T160958Z-8325d22/manifest.json"
RECEIPT = ROOT / ("automation/results/" + JOB + ".json")
MODEL = ROOT / "scripts/wull-private-painted-alpha-model.py"
STAGES = ("BOOT", "FOUR_HOSTS_FROZEN", "SYNTHETIC_SHEET_SAVED")


class Unqualified(Exception):
    pass


def need(flag, reason):
    if not flag:
        raise Unqualified(reason)


def git_blob(rev, path):
    result = subprocess.run(
        ["git", "rev-parse", rev + ":" + path], cwd=ROOT,
        stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=10)
    need(result.returncode == 0 and len(result.stdout.strip()) == 40,
         "SOURCE_IDENTITY_UNQUALIFIED")
    return result.stdout.strip()


def audit():
    need(Path.cwd().resolve() == ROOT, "WORKSPACE_UNQUALIFIED")
    manifest = json.loads(MANIFEST.read_text())
    receipt = json.loads(RECEIPT.read_text())
    need(manifest.get("exact_source_sha") == SOURCE
         and manifest.get("worker_job") == JOB
         and manifest.get("image_publication", "").startswith("NOT_PUBLISHED")
         and receipt.get("job") == JOB
         and receipt.get("job_commit") == SOURCE
         and receipt.get("profile_id") == PROFILE
         and receipt.get("status") == "passed", "SOURCE_IDENTITY_UNQUALIFIED")
    actions = receipt.get("actions", [])
    need(len(actions) == 3 and all(
        a.get("evidence_id") == JOB + ":" + str(n)
        and a.get("exit_code") == 0
        and a.get("source_sha") == SOURCE
        and not a.get("timed_out")
        for n, a in enumerate(actions)), "SOURCE_IDENTITY_UNQUALIFIED")
    paths = (
        "modules/abyss/companion/WaterDropletBody.qml",
        "modules/abyss/companion/AbyssCompanion.qml",
        "modules/abyss/looks/AbyssStyle.qml",
        "scripts/wull-fixtures/visual-matrix/shell.qml",
        "scripts/wull-manual-visual-matrix.py",
        "defaults/config.json",
    )
    for path in paths:
        need(git_blob("HEAD", path) == git_blob(SOURCE, path),
             "RENDERER_CHANGED_AFTER_CAPTURE")


def owner_private(path, is_file):
    need(not path.is_symlink(), "PRIVATE_EVIDENCE_UNAVAILABLE")
    info = path.lstat()
    need(info.st_uid == os.getuid()
         and not stat.S_IMODE(info.st_mode) & 0o077
         and (stat.S_ISREG(info.st_mode) if is_file
              else stat.S_ISDIR(info.st_mode)),
         "PRIVATE_EVIDENCE_UNAVAILABLE")
    if is_file:
        need(0 < info.st_size <= 1024 * 1024,
             "PRIVATE_EVIDENCE_UNAVAILABLE")


def find_private():
    root = Path(os.environ.get(
        "XDG_STATE_HOME", str(Path.home() / ".local/state"))).expanduser()
    need(root.is_absolute() and not root.is_symlink(),
         "PRIVATE_EVIDENCE_UNAVAILABLE")
    shared = root / "hadalis-wull-visual-private"
    owner_private(shared, False)
    prefix = "matrix-" + SOURCE[:12] + "-"
    cases = [p for p in shared.iterdir()
             if p.name.startswith(prefix) and not p.is_symlink()
             and p.is_dir()]
    need(len(cases) == 1, "PRIVATE_EVIDENCE_UNAVAILABLE")
    folder = cases[0]
    owner_private(folder, False)
    png, log = folder / "four-pose.private.png", folder / "qt.private.log"
    owner_private(png, True)
    owner_private(log, True)
    stages, failed = [], []
    for line in log.read_text(encoding="utf-8", errors="replace").splitlines():
        if "WULL_VISUAL_MATRIX_STAGE=" in line:
            stages.append(line.split("WULL_VISUAL_MATRIX_STAGE=", 1)[1].strip())
        if "WULL_VISUAL_MATRIX_FAIL=" in line:
            failed.append(line)
    need(stages == list(STAGES) and not failed,
         "PRIVATE_STAGE_UNQUALIFIED")
    return png


def rgba_verified(raw):
    # The source-reviewed decoder enforces strict PNG size, dimensions,
    # chunk order, CRC, RGBA8 and bounded decompression; cross-check RGBA.
    model = runpy.run_path(str(MODEL), run_name="wull_rgba_private_inspection")
    width, height, alpha = model["png_alpha"](raw)
    need((width, height) == (512, 512), "RGBA_UNQUALIFIED")
    pos, pieces = 8, []
    while pos < len(raw):
        count = struct.unpack_from(">I", raw, pos)[0]
        kind = raw[pos + 4:pos + 8]
        if kind == b"IDAT":
            pieces.append(raw[pos + 8:pos + 8 + count])
        pos += 12 + count
    expected = height * (1 + width * 4)
    dec = zlib.decompressobj()
    compressed = b"".join(pieces)
    plain = dec.decompress(compressed, expected + 1)
    need(len(plain) == expected and dec.eof and not dec.unused_data
         and not dec.unconsumed_tail, "RGBA_UNQUALIFIED")
    output = bytearray(width * height * 4)
    prior = bytearray(width * 4)
    stride = width * 4
    for y in range(height):
        f = plain[y * (stride + 1)]
        row = bytearray(plain[y * (stride + 1) + 1:(y + 1) * (stride + 1)])
        for j in range(stride):
            a = row[j - 4] if j >= 4 else 0
            b = prior[j]
            c = prior[j - 4] if j >= 4 else 0
            # PNG filter type 0 is the identity transform, not a failure.
            if f == 0:
                continue
            elif f == 1:
                row[j] = (row[j] + a) & 255
            elif f == 2:
                row[j] = (row[j] + b) & 255
            elif f == 3:
                row[j] = (row[j] + (a + b) // 2) & 255
            elif f == 4:
                p = a + b - c
                d = (abs(p - a), abs(p - b), abs(p - c))
                row[j] = (row[j] + (a if d[0] == min(d)
                                  else b if d[1] == min(d) else c)) & 255
            else:
                raise Unqualified("RGBA_UNQUALIFIED")
        output[y * stride:(y + 1) * stride] = row
        prior = row
    need(output[3::4] == alpha, "RGBA_UNQUALIFIED")
    return width, height, output


def mechanical_cells(width, height, rgba):
    result = []
    for x0, y0, x1, y1 in ROI:
        pixels = []
        for y in range(y0, y1):
            for x in range(x0, x1):
                at = (y * width + x) * 4
                if rgba[at + 3] >= 24:
                    pixels.append((x, y, tuple(rgba[at:at + 3])))
        need(len(pixels) >= 400, "CELL_UNPAINTED")
        xlo, xhi = min(p[0] for p in pixels), max(p[0] for p in pixels)
        ylo, yhi = min(p[1] for p in pixels), max(p[1] for p in pixels)
        palette = {(p[2][0] // 16, p[2][1] // 16, p[2][2] // 16)
                   for p in pixels}
        need(xhi - xlo >= 22 and yhi - ylo >= 22,
             "CELL_RENDER_ENVELOPE_UNQUALIFIED")
        result.append({"painted": True, "multiple_rgba_color_bands":
                       len(palette) >= 3, "bounded_footprint": True})
    return result


def main():
    need(sys.argv[1:] == ["--retained-read-only"],
         "EXPLICIT_MODE_REQUIRED")
    audit()
    path = find_private()
    try:
        raw = path.read_bytes()
        cells = mechanical_cells(*rgba_verified(raw))
    except (ValueError, struct.error, zlib.error):
        raise Unqualified("RGBA_UNQUALIFIED")
    need(all(c["multiple_rgba_color_bands"] for c in cells),
         "MATERIAL_VARIATION_UNQUALIFIED")
    # Only fixed categories and SHA provenance. NEVER print pixels,
    # file paths, raw logs or subjective expression judgments.
    print("SOURCE_SHA=" + SOURCE)
    print("RETAINED_FOUR_POSE_IMAGE=READ_ONLY_VERIFIED")
    print("RGBA_FOUR_PAINTED_CELLS=YES")
    print("FOUR_CELLS_MULTICOLOR_MATERIAL=YES")
    print("RETROACTIVE_RENDERER_EQUIVALENCE=YES")
    print("SEMANTIC_EXPRESSION_DIFFERENCE=NOT_PROVEN")
    print("MAINTAINER_VISUAL_ACCEPTANCE=REQUIRED")
    print("GATE=RETAINED_MATRIX_MECHANICAL_QUALIFIED")


if __name__ == "__main__":
    try:
        main()
    except (Unqualified, OSError, ValueError, KeyError,
            subprocess.TimeoutExpired, json.JSONDecodeError) as err:
        reason = str(err)
        allowed = {"EXPLICIT_MODE_REQUIRED", "WORKSPACE_UNQUALIFIED",
                   "SOURCE_IDENTITY_UNQUALIFIED",
                   "RENDERER_CHANGED_AFTER_CAPTURE",
                   "PRIVATE_EVIDENCE_UNAVAILABLE", "PRIVATE_STAGE_UNQUALIFIED",
                   "RGBA_UNQUALIFIED", "CELL_UNPAINTED",
                   "CELL_RENDER_ENVELOPE_UNQUALIFIED",
                   "MATERIAL_VARIATION_UNQUALIFIED"}
        print("GATE=" + (reason if reason in allowed
                         else "PRIVATE_INSPECTION_INCONCLUSIVE"))
        raise SystemExit(1)
