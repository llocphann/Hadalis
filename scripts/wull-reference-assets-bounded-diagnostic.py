#!/usr/bin/env python3
"""Read-only source-board manifest integrity diagnostic with a fixed one-line output.

No image bytes, filenames from machine state, absolute paths or log excerpts
are printed. M=match; B=byte-size mismatch; H=SHA256 mismatch;
P=invalid PNG header; X=file absent/symlink.
"""
import hashlib
import json
from pathlib import Path
import struct

BASE=Path(__file__).resolve().parents[1]
NAMES=("Water Droplet Companion.png",
       "Water Droplet Companion Expression.png",
       "Water Droplet Companion Animation.png",
       "Water Droplet Companion Animation Plus.png")
EXPECTED=("01_wull_blueprint.png","02_wull_expressions.png",
          "03_wull_animation.png","04_wull_animation_plus.png")
manifest=json.loads((BASE/"docs/wull-visual/reference/manifest.json").read_text())
files=manifest.get("files")
if manifest.get("schema")!=1 or not isinstance(files,list) or len(files)!=4 or (
    tuple(item.get("file") for item in files)!=EXPECTED
):
    print("WULL_REF_DIAG=MANIFEST_INVALID")
    raise SystemExit(0)
out=[]
for item,name in zip(files,NAMES):
    file=BASE/"assets"/name
    if not file.is_file() or file.is_symlink():
        out.append("X"); continue
    raw=file.read_bytes()
    if len(raw)!=item["bytes"]:
        out.append("B"); continue
    if hashlib.sha256(raw).hexdigest()!=item["sha256"]:
        out.append("H"); continue
    if (len(raw)<33 or raw[:8]!=b"\x89PNG\r\n\x1a\n" or raw[12:16]!=b"IHDR"
        or not all(100<=dimension<=16000
                   for dimension in struct.unpack_from(">II",raw,16))):
        out.append("P"); continue
    out.append("M")
print("WULL_REF_DIAG="+"".join(out))
