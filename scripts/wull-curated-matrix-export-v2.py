#!/usr/bin/env python3
"""Produce ONLY a bounded, curated image from the previously verified owned
Qt-offscreen synthetic Wull matrix. Never ingest a desktop screenshot.
The raw 0600 source stays private. Explicit publication is a separate mode
with no interactive Git authentication and a non-force, fast-forward push.
"""
import hashlib
import json
import os
from pathlib import Path
import re
import runpy
import stat
import struct
import subprocess
import sys
import zlib

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
INSPECTOR = ROOT / "scripts/wull-existing-matrix-evidence-v2.py"
SOURCE = "608cc6b5f95b5df7701e3f23ed29d2a44a2be54f"
OLD_JOB = "JOB-WULL-VISUAL-FACE-P1E0042-20261002-13"
RELATIVE = Path("docs/wull-visual/runs/20261002T165800Z-608cc6")
PNG = RELATIVE / "curated-four-pose.png"
PROVENANCE = RELATIVE / "curated-provenance.json"
REMOTE = "https://github.com/llocphann/Hadalis.git"
SSH_REMOTE = "git@github.com:llocphann/Hadalis.git"
PROFILE = "profile-1e0042aca8e24db2"
MAX_SAFE = 512 * 1024

class Unsafe(Exception):
    pass

def need(flag, label):
    if not flag:
        raise Unsafe(label)

def chunk(kind, value):
    return (struct.pack(">I", len(value)) + kind + value +
            struct.pack(">I", zlib.crc32(kind + value) & 0xffffffff))

def safe_pixels(width, height, rgba, rois):
    """Pixel allowlist ONLY; zero RGB as well as alpha outside four cells."""
    need(width == height == 512 and len(rgba) == width * height * 4
         and len(rois) == 4, "CURATION_GEOMETRY_UNQUALIFIED")
    output = bytearray(width * height * 4)
    for x0, y0, x1, y1 in rois:
        need(0 <= x0 < x1 <= width and 0 <= y0 < y1 <= height
             and x1 - x0 < 256 and y1 - y0 < 256,
             "CURATION_GEOMETRY_UNQUALIFIED")
        for y in range(y0, y1):
            for x in range(x0, x1):
                pos = (y * width + x) * 4
                if rgba[pos + 3] >= 8:
                    output[pos:pos + 4] = rgba[pos:pos + 4]
    rows = b"".join(
        b"\0" + bytes(output[y * width * 4:(y + 1) * width * 4])
        for y in range(height))
    raw = (b"\x89PNG\r\n\x1a\n"
           + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height,
                                          8, 6, 0, 0, 0))
           + chunk(b"IDAT", zlib.compress(rows, 9))
           + chunk(b"IEND", b""))
    need(0 < len(raw) <= MAX_SAFE, "CURATED_IMAGE_OVERSIZED")
    return raw

def old_output_provenance(raw):
    """Check current bytes against SHA printed by the exact old Qt worker."""
    base = Path(os.environ.get(
        "XDG_STATE_HOME", str(Path.home() / ".local/state")))
    original = (base / "hadalis-automation" / "worker" / "actions"
                / OLD_JOB / "action-4.json")
    need(original.is_file() and not original.is_symlink(),
         "OLD_CAPTURE_PROVENANCE_UNAVAILABLE")
    st = original.stat()
    need(st.st_uid == os.getuid() and not stat.S_IMODE(st.st_mode) & 0o077
         and 0 < st.st_size <= 32 * 1024,
         "OLD_CAPTURE_PROVENANCE_UNAVAILABLE")
    record = json.loads(original.read_bytes())
    result = record.get("result", {})
    need(record.get("phase") == "finished"
         and result.get("evidence_id") == OLD_JOB + ":4"
         and result.get("source_sha") == SOURCE
         and result.get("exit_code") == 0
         and result.get("timed_out") is False,
         "OLD_CAPTURE_PROVENANCE_UNAVAILABLE")
    old_output = result.get("stdout", "")
    need(type(old_output) is str and len(old_output) <= 2048,
         "OLD_CAPTURE_PROVENANCE_UNAVAILABLE")
    markers = re.findall(r"(?m)^SHEET_SHA256=([0-9a-f]{64})$",
                         old_output)
    need(len(markers) == 1 and markers[0] == hashlib.sha256(raw).hexdigest(),
         "OLD_CAPTURE_DIGEST_MISMATCH")

def command(argv, timeout=25):
    from automation.manager.credentials import git_env
    env = git_env()
    env.update({"GIT_TERMINAL_PROMPT": "0",
                "GCM_INTERACTIVE": "never", "GIT_ASKPASS": "/bin/false",
                "SSH_ASKPASS": "/bin/false"})
    return subprocess.run(argv, cwd=ROOT, env=env, stdin=subprocess.DEVNULL,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                          text=True, timeout=timeout, check=False)

def publish_curated(curated, proof):
    need(command(["git", "status", "--porcelain=v1"]).stdout.strip() == "",
         "ISOLATED_CLONE_DIRTY")
    # Explicit single attempt. No credential prompts, no branch rewrite.
    fetched = command(["git", "fetch", "--no-tags", REMOTE,
                       "refs/heads/dev"], 35)
    need(fetched.returncode == 0, "REMOTE_FETCH_UNAVAILABLE")
    merged = command(["git", "merge", "--ff-only", "FETCH_HEAD"], 20)
    need(merged.returncode == 0, "REMOTE_CHANGED_OR_DIVERGED")
    need(not (ROOT / PNG).exists() and not (ROOT / PROVENANCE).exists(),
         "ALREADY_PUBLISHED_OR_CONFLICT")
    (ROOT / RELATIVE).mkdir(parents=True, exist_ok=True)
    (ROOT / PNG).write_bytes(curated)
    (ROOT / PROVENANCE).write_text(
        json.dumps(proof, indent=2, sort_keys=True) + "\n",
        encoding="utf-8")
    added = command(["git", "add", "--", str(PNG), str(PROVENANCE)])
    need(added.returncode == 0, "PUBLIC_STAGE_UNQUALIFIED")
    staged = command(["git", "diff", "--cached", "--name-only"])
    need(staged.returncode == 0 and set(staged.stdout.splitlines()) ==
         {str(PNG), str(PROVENANCE)}, "PUBLIC_STAGE_UNQUALIFIED")
    authored = command(["git", "-c", "user.name=Hadalis-Wull-Evidence",
                        "-c", "user.email=actions@users.noreply.github.com",
                        "commit", "-m",
                        "test(wull): publish curated synthetic-only exact-source visual sheet"])
    need(authored.returncode == 0, "PUBLIC_COMMIT_UNQUALIFIED")
    # Never blindly retry an uncertain push. GitHub effects must be inspected
    # before any distinct publication/recovery turn.
    # Match the canonical worker: only this profile’s saved helper, or
    # configured system SSH credentials when this profile has no token.
    from automation.manager.credentials import git_options, has_token
    push_remote = REMOTE if has_token(PROFILE) else SSH_REMOTE
    pushed = command(["git", *git_options(PROFILE, push_remote), "push",
                      push_remote, "HEAD:refs/heads/dev"], 35)
    if pushed.returncode:
        category = pushed.stderr.lower()
        if "non-fast-forward" in category or "fetch first" in category:
            raise Unsafe("PUSH_REF_MOVED")
        if ("authentication failed" in category or "permission denied" in category
                or "could not read username" in category):
            raise Unsafe("PUSH_AUTH_UNAVAILABLE")
        raise Unsafe("PUSH_RESULT_NEEDS_GITHUB_RECONCILIATION")

def main():
    need(sys.argv[1:] in (["--prepare-safe-only"],
                          ["--publish-safe-only"]),
         "EXPLICIT_MODE_REQUIRED")
    need(Path.cwd().resolve() == ROOT, "ISOLATED_CLONE_UNVERIFIED")
    inspector = runpy.run_path(str(INSPECTOR),
                               run_name="curated_matrix_inspector")
    inspector["audit"]()
    original = inspector["find_private"]().read_bytes()
    original_rgba = inspector["rgba_verified"](original)
    cells = inspector["mechanical_cells"](*original_rgba)
    need(all(c["multiple_rgba_color_bands"] for c in cells),
         "INSPECTOR_GATE_UNQUALIFIED")
    old_output_provenance(original)
    sanitized = safe_pixels(*original_rgba, inspector["ROI"])
    safe_rgba = inspector["rgba_verified"](sanitized)
    safe_cells = inspector["mechanical_cells"](*safe_rgba)
    need(all(c["multiple_rgba_color_bands"] for c in safe_cells),
         "CURATED_PNG_GATE_UNQUALIFIED")
    proof = {
        "kind": "CURATED_SYNTHETIC_QML_ONLY_NOT_HOST_CAPTURE",
        "exact_original_source_sha": SOURCE,
        "source_worker_evidence": OLD_JOB + ":4",
        "source_fixture": "scripts/wull-fixtures/visual-matrix/shell.qml",
        "curated_sha256": hashlib.sha256(sanitized).hexdigest(),
        "dimensions": [512, 512], "retained_cells": 4,
        "pixel_policy": "four reviewed RGBA rectangles only; outside zeroed",
        "metadata_policy": "new IHDR/IDAT/IEND only",
        "original_private_image_published": False,
        "reference_comparison": "UNAVAILABLE_NO_AUTHENTIC_FOUR_REFERENCES",
        "visual_acceptance": "NOT_REVIEWED",
        "live_panel_and_pointer": "NOT_TESTED",
    }
    if sys.argv[1:] == ["--prepare-safe-only"]:
        print("GATE=CURATED_SYNTHETIC_ONLY_PRIVATE_QUALIFIED")
        return
    publish_curated(sanitized, proof)
    print("GATE=CURATED_SYNTHETIC_ONLY_PUSH_RETURNED_SUCCESS")

if __name__ == "__main__":
    try:
        main()
    except (Unsafe, OSError, ValueError, KeyError,
            subprocess.TimeoutExpired) as exc:
        safe = {"EXPLICIT_MODE_REQUIRED", "ISOLATED_CLONE_UNVERIFIED",
                "CURATION_GEOMETRY_UNQUALIFIED", "CURATED_IMAGE_OVERSIZED",
                "OLD_CAPTURE_PROVENANCE_UNAVAILABLE",
                "OLD_CAPTURE_DIGEST_MISMATCH", "ISOLATED_CLONE_DIRTY",
                "REMOTE_FETCH_UNAVAILABLE", "REMOTE_CHANGED_OR_DIVERGED",
                "ALREADY_PUBLISHED_OR_CONFLICT", "PUBLIC_STAGE_UNQUALIFIED",
                "PUBLIC_COMMIT_UNQUALIFIED",
                "PUSH_RESULT_NEEDS_GITHUB_RECONCILIATION",
                "PUSH_REF_MOVED", "PUSH_AUTH_UNAVAILABLE",
                "INSPECTOR_GATE_UNQUALIFIED", "CURATED_PNG_GATE_UNQUALIFIED"}
        label = str(exc)
        print("GATE=" + (label if label in safe
                         else "CURATED_PUBLICATION_INCONCLUSIVE"))
        raise SystemExit(1)
