#!/usr/bin/env python3
"""Private two-image source verification and strict synthetic-only Bar curation.

Raw nested Qt/shell logs and full real-module images never leave owner state.
The published visual isolates only low-screen Wull + field rim portions and
deletes all other RGBA pixels/metadata, including the private clock area.
Publication is a distinct explicit non-force single-try worker action.
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

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
SOURCE="f53348cbdb270ba2b2ed1a4d4951b0afa33c938a"
OLD_JOB="JOB-WULL-REAL-BAR-P1E0042-20261003-41"
PROFILE="profile-1e0042aca8e24db2"
RUN="20261002T185710Z-f53348"
RELATIVE=Path("docs/wull-visual/runs")/RUN
PNG=RELATIVE/"curated-real-bar-left-right.png"
PROVENANCE=RELATIVE/"curated-provenance.json"
MANIFEST=ROOT/RELATIVE/"manifest.json"
RECEIPT=ROOT/"automation/results"/(OLD_JOB+".json")
REMOTE="https://github.com/llocphann/Hadalis.git"
SSH_REMOTE="git@github.com:llocphann/Hadalis.git"
MAX_SAFE=512*1024
# Split left/right bands into exactly four strictly source-owned sub-rectangles
# for the reviewed alpha-safe encoder. Nothing from the actual clock module's
# source-seeded upper screen position is allowed into the composite.
ROIS=((0,300,160,389),(0,389,160,477),
      (352,300,512,389),(352,389,512,477))
STAGES=("BOOT","BAR_LAYOUT_FIELD_AND_WULL_READY","PNG_SAVED")


class Unsafe(Exception):
    pass


def need(ok,reason):
    if not ok:
        raise Unsafe(reason)


def git_blob(revision,path):
    p=subprocess.run(["git","rev-parse",revision+":"+path],cwd=ROOT,
                     stdin=subprocess.DEVNULL,stdout=subprocess.PIPE,
                     stderr=subprocess.DEVNULL,text=True,timeout=10)
    need(p.returncode==0 and len(p.stdout.strip())==40,
         "SOURCE_IDENTITY_UNQUALIFIED")
    return p.stdout.strip()


def audit():
    need(Path.cwd().resolve()==ROOT,"ISOLATED_CLONE_UNVERIFIED")
    meta=json.loads(MANIFEST.read_text(encoding="utf-8"))
    r=json.loads(RECEIPT.read_text(encoding="utf-8"))
    need(meta.get("source_sha")==SOURCE and meta.get("run_id")==RUN
         and meta.get("job_id")==OLD_JOB
         and meta.get("public_image","").startswith("NOT_PUBLISHED")
         and r.get("job")==OLD_JOB
         and r.get("job_commit")==SOURCE
         and r.get("status")=="passed"
         and r.get("profile_id")==PROFILE,
         "SOURCE_IDENTITY_UNQUALIFIED")
    a=r.get("actions",[])
    need(len(a)==3 and all(
        item.get("evidence_id")==OLD_JOB+":"+str(i)
        and item.get("source_sha")==SOURCE
        and item.get("exit_code")==0
        and item.get("timed_out") is False
        for i,item in enumerate(a)),"SOURCE_IDENTITY_UNQUALIFIED")
    for name in (
        "modules/abyss/bar/AbyssBar.qml",
        "modules/abyss/bar/AbyssBarModule.qml",
        "modules/abyss/companion/AbyssCompanion.qml",
        "modules/abyss/companion/WaterDropletBody.qml",
        "modules/abyss/companion/WullSurfacePlacement.js",
        "modules/abyss/companion/WullHostPolicy.js",
        "modules/abyss/looks/AbyssLayout.js",
        "modules/abyss/looks/AbyssField.qml",
        "modules/abyss/looks/AbyssField.frag.qsb",
        "modules/abyss/looks/AbyssStyle.qml",
        "scripts/wull-fixtures/production-bar-field/shell.qml",
        "scripts/wull-manual-nested-production-bar.py",
        "defaults/config.json",
    ):
        need(git_blob("HEAD",name)==git_blob(SOURCE,name),
             "RENDERER_CHANGED_AFTER_CAPTURE")


def owner_only(path,is_dir):
    need(not path.is_symlink(),"OWNER_PRIVATE_UNQUALIFIED")
    st=path.lstat()
    need(st.st_uid==os.getuid()
         and not stat.S_IMODE(st.st_mode)&0o077
         and (stat.S_ISDIR(st.st_mode) if is_dir else
              stat.S_ISREG(st.st_mode)),
         "OWNER_PRIVATE_UNQUALIFIED")
    if not is_dir:
        need(0<st.st_size<=1024*1024,"OWNER_PRIVATE_UNQUALIFIED")


def raw_source():
    state=Path(os.environ.get("XDG_STATE_HOME",
        str(Path.home()/".local/state"))).expanduser()
    need(state.is_absolute() and not state.is_symlink(),
         "OWNER_PRIVATE_UNQUALIFIED")
    collection=state/"hadalis-wull-nested-bar-private"
    owner_only(collection,True)
    folders=[p for p in collection.iterdir()
             if p.name.startswith("bar-"+SOURCE[:12]+"-")
             and p.is_dir() and not p.is_symlink()]
    need(len(folders)==1,"OWNER_PRIVATE_UNQUALIFIED")
    private=folders[0]
    owner_only(private,True)
    owner_only(private/"nested.private.log",False)
    originals={}
    for side in ("left","right"):
        folder=private/side
        owner_only(folder,True)
        png=folder/"bar.private.png"
        logfile=folder/"qt.private.log"
        owner_only(png,False)
        owner_only(logfile,False)
        stages=[]
        failures=[]
        for line in logfile.read_text(
                encoding="utf-8",errors="replace").splitlines():
            if "WULL_PANEL_REAL_STAGE=" in line:
                stages.append(line.split("WULL_PANEL_REAL_STAGE=",1)[1].strip())
            if "WULL_PANEL_REAL_FAIL=" in line:
                failures.append(True)
        need(stages==list(STAGES) and not failures,
             "PRIVATE_STAGE_UNQUALIFIED")
        originals[side]=png.read_bytes()
    return originals


def verify_worker_digest(raws):
    state=Path(os.environ.get("XDG_STATE_HOME",
        str(Path.home()/".local/state"))).expanduser()
    file=state/"hadalis-automation"/"worker"/"actions"/OLD_JOB/"action-2.json"
    owner_only(file,False)
    record=json.loads(file.read_bytes())
    result=record.get("result",{})
    need(record.get("phase")=="finished"
         and result.get("evidence_id")==OLD_JOB+":2"
         and result.get("source_sha")==SOURCE
         and result.get("exit_code")==0
         and result.get("timed_out") is False,
         "CAPTURE_PROVENANCE_UNAVAILABLE")
    output=result.get("stdout","")
    need(type(output) is str and len(output)<2048
         and re.findall(r"(?m)^SOURCE_SHA="+SOURCE+r"$",output)
         and "NESTED_ISOLATION=HOST_INVARIANT" in output
         and "REAL_ABYSS_BAR_CLOCK_AND_FIELD=LEFT_RIGHT_PAINTED" in output
         and "ORIGINAL_PRIVATE_IMAGE=NOT_PUBLISHED" in output,
         "CAPTURE_PROVENANCE_UNAVAILABLE")
    for side in ("left","right"):
        marker=side.upper()+"_SHEET_SHA256="
        hashes=re.findall(r"(?m)^"+marker+r"([0-9a-f]{64})$",output)
        need(len(hashes)==1
             and hashes[0]==hashlib.sha256(raws[side]).hexdigest(),
             "CAPTURE_DIGEST_MISMATCH")


def compose(a,b):
    need(len(a)==len(b)==512*512*4,
         "CURATION_GEOMETRY_UNQUALIFIED")
    out=bytearray(len(a))
    # Keep only the lower edge regions, independent from where the clock
    # actually decides to draw (the full upper region is always blank).
    for y in range(300,477):
        for x in range(160):
            p=(y*512+x)*4
            out[p:p+4]=a[p:p+4]
        for x in range(352,512):
            p=(y*512+x)*4
            out[p:p+4]=b[p:p+4]
    return out


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
    audit()
    sources=raw_source()
    verify_worker_digest(sources)
    decoder=runpy.run_path(
        str(ROOT/"scripts/wull-existing-matrix-evidence-v3.py"),
        run_name="real_bar_strict_rgba")
    witness=runpy.run_path(
        str(ROOT/"scripts/wull-manual-nested-production-bar.py"),
        run_name="real_bar_alpha_witness")
    source_rgba={}
    for side in ("left","right"):
        w,h,rgba=decoder["rgba_verified"](sources[side])
        need((w,h)==(512,512),"SOURCE_RGBA_UNQUALIFIED")
        need(witness["panel_alpha"](rgba[3::4],w,h,side),
             "SOURCE_ALPHA_UNQUALIFIED")
        source_rgba[side]=rgba
    joined=compose(source_rgba["left"],source_rgba["right"])
    curated=safe_pixels(512,512,joined,ROIS)
    w,h,final=decoder["rgba_verified"](curated)
    for side in ("left","right"):
        need(witness["panel_alpha"](final[3::4],w,h,side),
             "CURATED_ALPHA_UNQUALIFIED")
    need(curated==safe_pixels(w,h,final,ROIS),
         "CURATED_PNG_UNQUALIFIED")
    # Reject accidental nonzero RGB, alpha, or inherited metadata beyond
    # exactly these deterministic, source-reviewed rectangular pixels.
    proof={
        "kind":"CURATED_SYNTHETIC_REAL_BAR_CLOCK_FIELD_WULL_NESTED_NIRI",
        "source_sha":SOURCE,
        "source_job":OLD_JOB,
        "source_evidence_id":OLD_JOB+":2",
        "source_fixture":"scripts/wull-fixtures/production-bar-field/shell.qml",
        "source_private_images":2,
        "curated_sha256":hashlib.sha256(curated).hexdigest(),
        "dimensions":[512,512],
        "retained_four_subrectangles":[list(r) for r in ROIS],
        "redaction":"entire upper output + center + all nonallowlisted pixels zeroed",
        "pixel_policy":"Wull/field rim lower side patches only",
        "metadata_policy":"new IHDR/IDAT/IEND only",
        "raw_images_published":False,
        "host_screen_published":False,
        "actual_bar_module":"one real clock per private 512 output (not in curated area)",
        "full_AbyssPerimeter_and_native_input":"NOT_TESTED",
        "reference_images":"UNVERIFIED",
        "visual_review":"NOT_REVIEWED",
    }
    if sys.argv[1:]==["--prepare-safe-only"]:
        print("GATE=CURATED_REAL_BAR_PRIVATE_QUALIFIED")
        return
    publish_curated(curated,proof)
    print("GATE=CURATED_REAL_BAR_SAFE_PUSH_RETURNED_SUCCESS")


if __name__=="__main__":
    try:
        main()
    except (Unsafe,OSError,ValueError,KeyError,subprocess.TimeoutExpired) as e:
        allowed={
            "EXPLICIT_MODE_REQUIRED","ISOLATED_CLONE_UNVERIFIED",
            "SOURCE_IDENTITY_UNQUALIFIED","RENDERER_CHANGED_AFTER_CAPTURE",
            "OWNER_PRIVATE_UNQUALIFIED","PRIVATE_STAGE_UNQUALIFIED",
            "CAPTURE_PROVENANCE_UNAVAILABLE","CAPTURE_DIGEST_MISMATCH",
            "CURATION_GEOMETRY_UNQUALIFIED","CURATED_IMAGE_OVERSIZED",
            "SOURCE_RGBA_UNQUALIFIED","SOURCE_ALPHA_UNQUALIFIED",
            "CURATED_ALPHA_UNQUALIFIED","CURATED_PNG_UNQUALIFIED",
            "ISOLATED_CLONE_DIRTY","REMOTE_FETCH_UNAVAILABLE",
            "REMOTE_CHANGED_OR_DIVERGED","ALREADY_PUBLISHED_OR_CONFLICT",
            "PUBLIC_STAGE_UNQUALIFIED","PUBLIC_COMMIT_UNQUALIFIED",
            "PUSH_REF_MOVED","PUSH_AUTH_UNAVAILABLE",
            "PUSH_RESULT_NEEDS_GITHUB_RECONCILIATION",
        }
        tag=str(e)
        print("GATE="+(tag if tag in allowed
                       else "REAL_BAR_CURATION_INCONCLUSIVE"))
        raise SystemExit(1)
