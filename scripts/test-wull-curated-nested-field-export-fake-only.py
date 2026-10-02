#!/usr/bin/env python3
"""Inert curating/security test; generates FAKE matrix only, no user files/Git."""
import ast
from pathlib import Path
import runpy
import struct

ROOT=Path(__file__).resolve().parents[1]
SCRIPT=ROOT/"scripts/wull-curated-nested-field-export.py"
src=SCRIPT.read_text(encoding="utf-8")
ast.parse(src)
for marker in (
    "source_sha", "manifest", "ROOT / RELATIVE",
    'SOURCE = "42e67777f7e67c9dc58895d006efef2a2c272e5f"',
    'OLD_JOB = "JOB-WULL-NESTED-FIELD-P1E0042-20261003-30"',
    'OLD_JOB+":2"', "private_original()", "check_original_digest(raw)",
    "safe_pixels(width,height,rgba,ROIS)",
    "field[\"painted_cells\"](alpha,width,height)",
    "owner_only(receipt,False)", "host_output_invariant",
    "visual_review", "production_live_panel_weld",
    "RENDERER_CHANGED_AFTER_CAPTURE",
    "PUSH_RESULT_NEEDS_GITHUB_RECONCILIATION",
    'git_options(PROFILE, push_remote)',
    '"HEAD:refs/heads/dev"',
):
    assert marker in src, marker
for forbidden in ("grabToImage", "grim ", "subprocess.Popen", "shell=True",
                  "git reset --hard", "git push --force", "WAYLAND_DISPLAY="):
    assert forbidden not in src, forbidden

export=runpy.run_path(str(SCRIPT),run_name="nested_export_fake_only")
decoder=runpy.run_path(
    str(ROOT/"scripts/wull-existing-matrix-evidence-v3.py"),
    run_name="nested_export_fake_only_decoder")
field=runpy.run_path(
    str(ROOT/"scripts/wull-manual-real-field-canary.py"),
    run_name="nested_export_fake_only_field")
assert export["ROIS"]==(
    (8,8,232,232),(280,8,504,232),(8,280,232,504),(280,280,504,504))
w=h=512
raw=bytearray(w*h*4)
rois=export["ROIS"]
for y in range(h):
    for x in range(w):
        at=(y*w+x)*4
        within=any(a<=x<c and b<=y<d for a,b,c,d in rois)
        if within:
            rgb=((30,80,175),(85,148,219),(167,205,246))[x%3]
            raw[at:at+4]=bytes((*rgb,255))
        else:
            raw[at:at+4]=bytes((17,23,29,255))
# Preserve no hidden RGB where alpha=0, even in authorized regions.
zero=(9*w+9)*4
raw[zero:zero+4]=bytes((200,100,100,0))
curated=export["safe_pixels"](w,h,raw,rois)
cw,ch,rgba=decoder["rgba_verified"](curated)
assert (cw,ch)==(512,512)
assert export["safe_pixels"](cw,ch,rgba,rois)==curated
assert field["painted_cells"](rgba[3::4],cw,ch)
for y in range(h):
    for x in range(w):
        at=(y*w+x)*4
        within=any(a<=x<c and b<=y<d for a,b,c,d in rois)
        expected=raw[at:at+4] if within and at!=zero else b"\0\0\0\0"
        assert rgba[at:at+4]==expected
# No source metadata or stealth chunk can be inherited.
kinds=[]
at=8
while at<len(curated):
    size=struct.unpack_from(">I",curated,at)[0]
    kinds.append(curated[at+4:at+8])
    at+=size+12
assert kinds==[b"IHDR",b"IDAT",b"IEND"]
try:
    export["safe_pixels"](512,511,raw,rois)
    raise AssertionError("wrong size accepted")
except export["Unsafe"] as e:
    assert str(e)=="CURATION_GEOMETRY_UNQUALIFIED"
print("WULL_NESTED_FIELD_CURATED_FAKE_ONLY_PASS")
