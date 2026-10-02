#!/usr/bin/env python3
"""Bounded read-only per-original diagnostic for current schema-2 manifest.

Historical -51 ran the old diagnostic at its pinned SHA; do not reinterpret
its original output as a current-source result. M match, B bytes, H digest,
G Git blob, P PNG/IHDR/CRC, X unavailable; invalid schema has its own tag.
No original pixels, private paths, image excerpts or freeform errors leak.
"""
import hashlib
import json
from pathlib import Path
import struct
import zlib

BASE=Path(__file__).resolve().parents[1]
FILES=(
 "assets/Water Droplet Companion.png",
 "assets/Water Droplet Companion Expression.png",
 "assets/Water Droplet Companion Animation.png",
 "assets/Water Droplet Companion Animation Plus.png",
)
def main():
    meta=json.loads((BASE/"docs/wull-visual/reference/manifest.json").read_text())
    rows=meta.get("files")
    if (meta.get("schema")!=2 or not isinstance(rows,list) or len(rows)!=4 or
        tuple(item.get("file") for item in rows)!=FILES):
        print("WULL_REF_DIAG=MANIFEST_INVALID")
        return
    out=[]
    for item,name in zip(rows,FILES):
        path=BASE/name
        if not path.is_file() or path.is_symlink():
            out.append("X"); continue
        raw=path.read_bytes()
        if len(raw)!=item.get("bytes"):
            out.append("B"); continue
        if hashlib.sha256(raw).hexdigest()!=item.get("sha256"):
            out.append("H"); continue
        blob=hashlib.sha1(("blob "+str(len(raw))+"\0").encode("ascii")+raw).hexdigest()
        if blob!=item.get("git_blob"):
            out.append("G"); continue
        if (len(raw)<33 or raw[:8]!=b"\x89PNG\r\n\x1a\n" or
            raw[8:16]!=b"\0\0\0\rIHDR" or
            (zlib.crc32(raw[12:29])&0xffffffff)!=struct.unpack_from(">I",raw,29)[0] or
            tuple(struct.unpack_from(">II",raw,16))!=(item.get("width"),item.get("height")) or
            not all(100<=n<=16000 for n in struct.unpack_from(">II",raw,16)) or
            raw[24]!=item.get("bit_depth") or raw[25]!=item.get("color_type")):
            out.append("P"); continue
        out.append("M")
    print("WULL_REF_DIAG="+"".join(out))

if __name__=="__main__":
    main()
