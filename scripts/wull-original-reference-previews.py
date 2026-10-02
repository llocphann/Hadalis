#!/usr/bin/env python3
"""Deterministic source-only, public ORIGINAL reference overview previews.

NEVER acquires desktop/worker-private images. Every input comes exclusively
from four tracked immutable public assets checked against the canonical source
metadata and manifest. Nearest-center pixel sampling retains exact sampled
original RGB values; overview downsizing is NOT full-resolution visual review.
Prepare and publish are separate distinct explicit profile jobs.
"""
import hashlib
import json
from pathlib import Path
import re
import struct
import subprocess
import sys
import zlib

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
REL=Path("docs/wull-visual/reference/previews")
SOURCE=Path("docs/wull-visual/reference/source-metadata.json")
MANIFEST=Path("docs/wull-visual/reference/manifest.json")
SELF="scripts/wull-original-reference-previews.py"
PROFILE="profile-1e0042aca8e24db2"
REMOTE="https://github.com/llocphann/Hadalis.git"
SSH_REMOTE="git@github.com:llocphann/Hadalis.git"
OUTPUTS=("blueprint-overview.png","expressions-overview.png","animation-overview.png","animation-plus-overview.png")
FILES=("assets/Water Droplet Companion.png","assets/Water Droplet Companion Expression.png",
       "assets/Water Droplet Companion Animation.png","assets/Water Droplet Companion Animation Plus.png")
WIDTH=512
SIG=b"\x89PNG\r\n\x1a\n"

class Unsafe(Exception):
    pass

def need(ok,tag):
    if not ok:
        raise Unsafe(tag)

def chunk(kind,data):
    return (struct.pack(">I",len(data))+kind+data
            +struct.pack(">I",zlib.crc32(kind+data)&0xffffffff))

def png_rgb(width,height,rgb):
    need(1<=width<=1024 and 1<=height<=1024 and len(rgb)==width*height*3,
         "PREVIEW_ENCODE_GEOMETRY_INVALID")
    stride=width*3
    rows=b"".join(b"\0"+rgb[y*stride:(y+1)*stride] for y in range(height))
    ihdr=struct.pack(">IIBBBBB",width,height,8,2,0,0,0)
    return SIG+chunk(b"IHDR",ihdr)+chunk(b"IDAT",zlib.compress(rows,9))+chunk(b"IEND",b"")

def unfilter(raw):
    """Strict bounded noninterlaced RGB8 PNG decoder; no Pillow dependency."""
    need(33<=len(raw)<=8_000_000 and raw.startswith(SIG),"SOURCE_PNG_UNQUALIFIED")
    pos=8
    ihdr=None
    idats=[]
    phase="START"
    width=height=None
    seen_iend=False
    while pos<len(raw):
        need(pos+12<=len(raw),"SOURCE_PNG_UNQUALIFIED")
        n=struct.unpack_from(">I",raw,pos)[0]
        kind=raw[pos+4:pos+8]
        need(n<=8_000_000 and pos+12+n<=len(raw),"SOURCE_PNG_UNQUALIFIED")
        data=raw[pos+8:pos+8+n]
        crc=struct.unpack_from(">I",raw,pos+8+n)[0]
        need(crc==(zlib.crc32(kind+data)&0xffffffff),"SOURCE_CHUNK_CRC_INVALID")
        if phase=="START":
            need(kind==b"IHDR" and n==13,"SOURCE_FORMAT_UNSUPPORTED")
            width,height,depth,color,compression,filter_method,interlace=struct.unpack(">IIBBBBB",data)
            need(1<=width<=4000 and 1<=height<=4000 and width*height<=8_000_000
                 and (depth,color,compression,filter_method,interlace)==(8,2,0,0,0),
                 "SOURCE_FORMAT_UNSUPPORTED")
            ihdr=data
            phase="BODY"
        elif kind==b"IDAT":
            need(phase in ("BODY","IDAT"),"SOURCE_PNG_UNQUALIFIED")
            idats.append(data)
            need(sum(map(len,idats))<=8_000_000,"SOURCE_PNG_UNQUALIFIED")
            phase="IDAT"
        elif kind==b"IEND":
            need(n==0 and bool(idats) and phase in ("IDAT","AFTER_IDAT"),
                 "SOURCE_PNG_UNQUALIFIED")
            pos+=n+12
            need(pos==len(raw),"SOURCE_PNG_UNQUALIFIED")
            seen_iend=True
            break
        else:
            # Ancillary chunks are already digest/CRC validated, but reject
            # unexpected critical chunk types; no hidden image sources.
            need(kind[0]&32 or kind==b"PLTE","SOURCE_FORMAT_UNSUPPORTED")
            if phase=="IDAT":
                phase="AFTER_IDAT"
        pos+=n+12
    need(seen_iend and ihdr is not None and bool(idats),"SOURCE_PNG_UNQUALIFIED")
    stride=width*3
    expected=height*(stride+1)
    obj=zlib.decompressobj()
    plain=obj.decompress(b"".join(idats),expected+1)
    need(len(plain)==expected and obj.eof and not obj.unused_data and not obj.unconsumed_tail,
         "SOURCE_PNG_DECODE_INVALID")
    output=bytearray(height*stride)
    prior=bytearray(stride)
    for y in range(height):
        at=y*(stride+1)
        f=plain[at]
        need(f<=4,"SOURCE_FORMAT_UNSUPPORTED")
        row=bytearray(plain[at+1:at+1+stride])
        if f:
            for k in range(stride):
                a=row[k-3] if k>=3 else 0
                b=prior[k]
                c=prior[k-3] if k>=3 else 0
                if f==1: pred=a
                elif f==2: pred=b
                elif f==3: pred=(a+b)//2
                else:
                    p=a+b-c
                    d=(abs(p-a),abs(p-b),abs(p-c))
                    pred=a if d[0]==min(d) else b if d[1]==min(d) else c
                row[k]=(row[k]+pred)&255
        output[y*stride:(y+1)*stride]=row
        prior=row
    return width,height,bytes(output)

def overview(width,height,rgb):
    need(width>=WIDTH and height>=200 and len(rgb)==width*height*3,
         "PREVIEW_SOURCE_GEOMETRY_INVALID")
    w=WIDTH
    h=(height*WIDTH+width//2)//width
    need(1<=h<=WIDTH,"PREVIEW_SOURCE_GEOMETRY_INVALID")
    xmap=[min(width-1,((2*x+1)*width)//(2*w)) for x in range(w)]
    data=bytearray(w*h*3)
    for y in range(h):
        src_y=min(height-1,((2*y+1)*height)//(2*h))
        for x,src_x in enumerate(xmap):
            p=(src_y*width+src_x)*3
            q=(y*w+x)*3
            data[q:q+3]=rgb[p:p+3]
    return w,h,bytes(data)

def git_blob(content):
    return hashlib.sha1(("blob "+str(len(content))+"\0").encode("ascii")+content).hexdigest()

def inspect():
    source=json.loads((ROOT/SOURCE).read_text(encoding="utf-8"))
    ref=json.loads((ROOT/MANIFEST).read_text(encoding="utf-8"))
    need(ref.get("schema")==2 and source.get("schema")==1
         and ref.get("reference_version")==source.get("reference_version")
         and ref.get("source_metadata")==str(SOURCE)
         and ref.get("files")==source.get("assets")
         and ref.get("visual_review")=="ORIGINAL_PIXELS_NOT_YET_VIEWED",
         "REFERENCE_MANIFEST_UNQUALIFIED")
    from_source=source["assets"]
    need(tuple(r.get("file") for r in from_source)==FILES,
         "REFERENCE_ASSETS_UNQUALIFIED")
    result=[]
    for row,outname in zip(from_source,OUTPUTS):
        path=ROOT/row["file"]
        need(path.is_file() and not path.is_symlink(),"REFERENCE_ASSET_UNAVAILABLE")
        raw=path.read_bytes()
        need(len(raw)==row["bytes"] and hashlib.sha256(raw).hexdigest()==row["sha256"]
             and git_blob(raw)==row["git_blob"],
             "REFERENCE_ASSET_DIGEST_MISMATCH")
        w,h,pix=unfilter(raw)
        need((w,h,raw[24],raw[25])==(row["width"],row["height"],row["bit_depth"],row["color_type"]),
             "REFERENCE_ASSET_IHDR_MISMATCH")
        pw,ph,preview_rgb=overview(w,h,pix)
        png=png_rgb(pw,ph,preview_rgb)
        cw,ch,actual=unfilter(png)
        need((cw,ch)==(pw,ph) and actual==preview_rgb
             and 0<len(png)<=900_000,
             "PREVIEW_RECODE_MISMATCH")
        result.append((outname,png,{
            "kind":"NONCANONICAL_SOURCE_PIXEL_OVERVIEW",
            "file":str(REL/outname),
            "width":pw,"height":ph,"sha256":hashlib.sha256(png).hexdigest(),
            "source":row["file"],"source_sha256":row["sha256"],
            "source_git_blob":row["git_blob"],"source_width":w,
            "source_height":h,"method":"deterministic center-nearest RGB pixel selection",
            "original_png_unmodified":True,
        }))
    return source,result

def run(argv,timeout=30):
    from automation.manager.credentials import git_env
    env=git_env()
    env.update({"GIT_TERMINAL_PROMPT":"0","GCM_INTERACTIVE":"never",
                "GIT_ASKPASS":"/bin/false","SSH_ASKPASS":"/bin/false"})
    return subprocess.run(argv,cwd=ROOT,env=env,stdin=subprocess.DEVNULL,
                          stdout=subprocess.PIPE,stderr=subprocess.PIPE,
                          text=True,timeout=timeout,check=False)

def blob_at(path):
    out=run(["git","rev-parse","HEAD:"+path],10)
    need(out.returncode==0 and re.fullmatch("[0-9a-f]{40}",out.stdout.strip()) is not None,
         "GIT_SOURCE_UNQUALIFIED")
    return out.stdout.strip()

def publish(source,images):
    need(run(["git","status","--porcelain=v1"]).stdout.strip()=="",
         "ISOLATED_CLONE_DIRTY")
    stable=[SELF,str(SOURCE),str(MANIFEST),*FILES]
    before=[blob_at(s) for s in stable]
    fetched=run(["git","fetch","--no-tags",REMOTE,"refs/heads/dev"],35)
    need(fetched.returncode==0,"REMOTE_FETCH_UNAVAILABLE")
    merge=run(["git","merge","--ff-only","FETCH_HEAD"],20)
    need(merge.returncode==0,"REMOTE_CHANGED_OR_DIVERGED")
    need([blob_at(s) for s in stable]==before,"SOURCE_CHANGED_DURING_PUBLISH")
    need(not (ROOT/REL).exists(),"PREVIEWS_ALREADY_PRESENT")
    # The first preparation and the publish-only job use identical sources.
    # Recheck all bytes and exact in-memory pixels after the fast-forward.
    again,next_images=inspect()
    need(again==source and next_images==images,"SOURCE_CHANGED_DURING_PUBLISH")
    root=ROOT/REL
    root.mkdir(parents=True,exist_ok=False)
    provenance={
        "schema":1,"reference_version":source["reference_version"],
        "kind":"SOURCE_ONLY_DOWNSAMPLED_AUTHENTIC_ORIGINAL_OVERVIEWS",
        "purpose":"Overview only: small sampled derivatives of real source boards, not new canonical assets",
        "source_metadata":str(SOURCE),"source_originals_modified":False,
        "host_screen_accessed":False,"private_worker_logs_published":False,
        "original_full_resolution_visual_review":"NOT_PERFORMED",
        "preview_visual_review":"NOT_REVIEWED",
        "images":[item[2] for item in images],
    }
    for name,png,_ in images:
        (root/name).write_bytes(png)
    (root/"manifest.json").write_text(
        json.dumps(provenance,indent=2,sort_keys=True)+"\n",encoding="utf-8")
    staged=[str(REL/name) for name in (*OUTPUTS,"manifest.json")]
    add=run(["git","add","--",*staged],30)
    need(add.returncode==0,"PUBLIC_STAGE_UNQUALIFIED")
    changed=run(["git","diff","--cached","--name-only"],15)
    need(changed.returncode==0 and sorted(changed.stdout.splitlines())==sorted(staged),
         "PUBLIC_STAGE_UNQUALIFIED")
    commit=run(["git","-c","user.name=Hadalis-Wull-Evidence",
                "-c","user.email=actions@users.noreply.github.com",
                "commit","-m","docs(wull): publish verified source-only original visual overview previews"],30)
    need(commit.returncode==0,"PUBLIC_COMMIT_UNQUALIFIED")
    from automation.manager.credentials import git_options,has_token
    remote=REMOTE if has_token(PROFILE) else SSH_REMOTE
    push=run(["git",*git_options(PROFILE,remote),"push",remote,"HEAD:refs/heads/dev"],35)
    need(push.returncode==0,"PUSH_RESULT_REQUIRES_GITHUB_RECONCILIATION")

def main():
    need(sys.argv[1:] in (["--prepare-safe-only"],["--publish-safe-only"]),
         "EXPLICIT_MODE_REQUIRED")
    need(Path.cwd().resolve()==ROOT,"ISOLATED_CLONE_UNVERIFIED")
    source,images=inspect()
    if sys.argv[1:]==["--prepare-safe-only"]:
        print("GATE=FOUR_PUBLIC_ORIGINAL_SOURCE_OVERVIEWS_PREPARED_IN_MEMORY")
    else:
        publish(source,images)
        print("GATE=FOUR_ORIGINAL_PREVIEWS_SAFE_PUSH_RETURNED_SUCCESS")

if __name__=="__main__":
    try:
        main()
    except Exception as e:
        allowed={"EXPLICIT_MODE_REQUIRED","ISOLATED_CLONE_UNVERIFIED",
                 "SOURCE_PNG_UNQUALIFIED","SOURCE_CHUNK_CRC_INVALID",
                 "SOURCE_FORMAT_UNSUPPORTED","SOURCE_PNG_DECODE_INVALID",
                 "PREVIEW_SOURCE_GEOMETRY_INVALID","PREVIEW_ENCODE_GEOMETRY_INVALID",
                 "REFERENCE_MANIFEST_UNQUALIFIED","REFERENCE_ASSETS_UNQUALIFIED",
                 "REFERENCE_ASSET_UNAVAILABLE","REFERENCE_ASSET_DIGEST_MISMATCH",
                 "REFERENCE_ASSET_IHDR_MISMATCH","PREVIEW_RECODE_MISMATCH",
                 "ISOLATED_CLONE_DIRTY","GIT_SOURCE_UNQUALIFIED",
                 "REMOTE_FETCH_UNAVAILABLE","REMOTE_CHANGED_OR_DIVERGED",
                 "SOURCE_CHANGED_DURING_PUBLISH","PREVIEWS_ALREADY_PRESENT",
                 "PUBLIC_STAGE_UNQUALIFIED","PUBLIC_COMMIT_UNQUALIFIED",
                 "PUSH_RESULT_REQUIRES_GITHUB_RECONCILIATION"}
        tag=str(e) if isinstance(e,Unsafe) and str(e) in allowed else "PREVIEW_UNCLASSIFIED"
        print("GATE="+tag)
        raise SystemExit(1)
