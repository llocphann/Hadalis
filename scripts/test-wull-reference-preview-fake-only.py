#!/usr/bin/env python3
"""Inert fake-only RGB/PNG-filter and preview geometry check. Never opens originals."""
import hashlib
from pathlib import Path
import runpy
import struct
import zlib

ROOT=Path(__file__).resolve().parents[1]
m=runpy.run_path(str(ROOT/"scripts/wull-original-reference-previews.py"),
                run_name="wull_original_previews_fake_only")
chunk=m["chunk"]
sig=m["SIG"]
w,h=9,5
stride=w*3
rows=[bytes((17+x*3+y*11)%256 for x in range(stride)) for y in range(h)]
raw=bytearray()
prev=bytes(stride)
for y,row in enumerate(rows):
    f=y
    buf=bytearray()
    for i,value in enumerate(row):
        a=row[i-3] if i>=3 else 0
        b=prev[i]
        c=prev[i-3] if i>=3 else 0
        if f==0: pred=0
        elif f==1: pred=a
        elif f==2: pred=b
        elif f==3: pred=(a+b)//2
        else:
            p=a+b-c
            d=(abs(p-a),abs(p-b),abs(p-c))
            pred=a if d[0]==min(d) else b if d[1]==min(d) else c
        buf.append((value-pred)&255)
    raw.extend(bytes((f,))+buf)
    prev=row
ihdr=struct.pack(">IIBBBBB",w,h,8,2,0,0,0)
fake=sig+chunk(b"IHDR",ihdr)+chunk(b"tEXt",b"fake only")+chunk(b"IDAT",zlib.compress(raw))+chunk(b"IEND",b"")
a,b,pixels=m["unfilter"](fake)
assert (a,b)==(w,h) and pixels==b"".join(rows)
encoded=m["png_rgb"](w,h,pixels)
assert m["unfilter"](encoded)==(w,h,pixels)
# Overview geometry and center-nearest source sampling.
large=bytes(i%251 for i in range(512*256*3))
out=m["overview"](512,256,large)
assert out==(512,256,large)
assert m["unfilter"](m["png_rgb"](*out))==out
bad=bytearray(fake)
bad[42]^=1
try:
    m["unfilter"](bytes(bad))
    raise AssertionError("corrupt CRC accepted")
except m["Unsafe"] as e:
    assert str(e)=="SOURCE_CHUNK_CRC_INVALID"
print("WULL_REFERENCE_SOURCE_PREVIEW_FAKE_RGB_FILTERS=PASS")
