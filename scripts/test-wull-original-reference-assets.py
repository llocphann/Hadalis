#!/usr/bin/env python3
"""Read-only checksum/PNG identity gate for the four original Wull boards.

Only repository-tracked assets and the reference manifest are read. No GUI,
network, host screenshot, asset transformation, write, or raw image output.
The manifest stores canonical reference-board names; this test maps them to
the actual unmodified, maintainer-named images kept under assets/.
"""
import hashlib
import json
from pathlib import Path
import struct

ROOT=Path(__file__).resolve().parents[1]
MANIFEST=ROOT/"docs/wull-visual/reference/manifest.json"
ORIGINALS=(
    ("01_wull_blueprint.png","Water Droplet Companion.png"),
    ("02_wull_expressions.png","Water Droplet Companion Expression.png"),
    ("03_wull_animation.png","Water Droplet Companion Animation.png"),
    ("04_wull_animation_plus.png","Water Droplet Companion Animation Plus.png"),
)
def png_dimensions(raw):
    if len(raw)<33 or raw[:8]!=b"\x89PNG\r\n\x1a\n" or raw[12:16]!=b"IHDR":
        raise ValueError("NOT_PNG")
    width,height=struct.unpack_from(">II",raw,16)
    if not (100<=width<=16000 and 100<=height<=16000):
        raise ValueError("DIMENSION_OUT_OF_RANGE")
    return width,height

def main():
    meta=json.loads(MANIFEST.read_text(encoding="utf-8"))
    assert meta.get("schema")==1 and len(meta.get("files",[]))==4
    assert tuple(entry.get("file") for entry in meta["files"]) == tuple(
        item[0] for item in ORIGINALS)
    for (declared,asset),item in zip(ORIGINALS,meta["files"]):
        path=ROOT/"assets"/asset
        assert path.is_file() and not path.is_symlink()
        raw=path.read_bytes()
        assert len(raw)==item["bytes"], "REFERENCE_BYTES_MISMATCH"
        assert hashlib.sha256(raw).hexdigest()==item["sha256"], (
            "REFERENCE_SHA256_MISMATCH")
        png_dimensions(raw)
        print("REFERENCE_MATCH="+declared)
    print("REFERENCE_ORIGINALS=4_OF_4_INTEGRITY_VERIFIED")
    print("REFERENCE_ASSETS=SOURCE_ONLY_NOT_MODIFIED")
    print("REFERENCE_VISUAL_CONTENT=NOT_YET_INSPECTED")

if __name__=="__main__":
    main()
