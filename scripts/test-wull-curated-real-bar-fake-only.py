#!/usr/bin/env python3
"""Inert, fake-RGBA source/ROI/redaction test: no owner files or Git writes."""
import ast
import struct
from pathlib import Path
import runpy
ROOT=Path(__file__).resolve().parents[1]
P=ROOT/"scripts/wull-curated-real-bar-export.py"
source=P.read_text(encoding="utf-8")
ast.parse(source)
for required in (
    'SOURCE="f53348cbdb270ba2b2ed1a4d4951b0afa33c938a"',
    'OLD_JOB="JOB-WULL-REAL-BAR-P1E0042-20261003-41"',
    'RUN="20261002T185710Z-f53348"',
    'item.get("source_sha")==SOURCE',
    "meta.get(\"public_image\",\"\").startswith(\"NOT_PUBLISHED\")",
    '"action-2.json"',
    'LEFT', 'RIGHT',
    'verify_worker_digest(sources)',
    'owner_only(private/"nested.private.log",False)',
    'owner_only(logfile,False)',
    'source_rgba["left"],source_rgba["right"]',
    'safe_pixels(512,512,joined,ROIS)',
    'witness["panel_alpha"](final[3::4],w,h,side)',
    'private_original_published',
    'git_options(PROFILE, push_remote)',
    '"HEAD:refs/heads/dev"',
    'PUSH_RESULT_NEEDS_GITHUB_RECONCILIATION',
):
    # "raw_images_published" is the actual public marker. This test
    # deliberately checks the concrete provenance and no-raw policy below.
    if required=="private_original_published":
        assert '"raw_images_published":False' in source
    else:
        assert required in source,required
for forbidden in (
    "grabToImage", "grim ", "subprocess.Popen", "shell=True",
    "git reset --hard", "git push --force", "WAYLAND_DISPLAY="):
    assert forbidden not in source,forbidden

mod=runpy.run_path(str(P),run_name="curated_real_bar_inert")
dec=runpy.run_path(
    str(ROOT/"scripts/wull-existing-matrix-evidence-v3.py"),
    run_name="curated_real_bar_fake_rgba_decoder")
w=h=512
assert mod["ROIS"]==((0,300,160,389),(0,389,160,477),
                    (352,300,512,389),(352,389,512,477))
left=bytearray(w*h*4)
right=bytearray(w*h*4)
for image,side in ((left,"left"),(right,"right")):
    # Fake image contains private-like garbage outside allowlisted region.
    image[:]=bytes((240,11,61,255))*(w*h)
    aa,bb=(0,150) if side=="left" else (362,512)
    for y in range(330,418):
        for x in range(aa,bb):
            at=(y*w+x)*4
            image[at:at+4]=bytes((55,105,181,255))
    # Some transparent-but-nonzero RGB inside ROI must also be zeroed.
    at=(332*w+(11 if side=="left" else 501))*4
    image[at:at+4]=bytes((190,77,210,0))
joined=mod["compose"](left,right)
curated=mod["safe_pixels"](w,h,joined,mod["ROIS"])
cw,ch,out=dec["rgba_verified"](curated)
assert (cw,ch)==(512,512)
assert mod["safe_pixels"](cw,ch,out,mod["ROIS"])==curated
for y in range(h):
    for x in range(w):
        p=(y*w+x)*4
        inside=(300<=y<477 and (x<160 or x>=352))
        if inside:
            raw=left if x<160 else right
            want=raw[p:p+4] if raw[p+3]>=8 else b"\0\0\0\0"
        else:
            want=b"\0\0\0\0"
        assert out[p:p+4]==want
assert all(out[(y*w+x)*4+3]==0 for y in range(0,300)
           for x in (2,85,400,507))
chunks=[]
at=8
while at<len(curated):
    n=struct.unpack_from(">I",curated,at)[0]
    chunks.append(curated[at+4:at+8])
    at+=n+12
assert chunks==[b"IHDR",b"IDAT",b"IEND"]
try:
    mod["compose"](bytes(5),right)
    raise AssertionError("wrong source bytes accepted")
except mod["Unsafe"] as exc:
    assert str(exc)=="CURATION_GEOMETRY_UNQUALIFIED"
print("WULL_CURATED_REAL_BAR_FAKE_ONLY_PASS")
