#!/usr/bin/env python3
"""Curate exactly four synthetic-owned nested-QML field cells after provenance.

Original PNG/Qt logs remain private; no host screenshot or old image is read.
All shared PNG/RGBA and non-force publish helpers are the already-tested
synthetic Wull curator's reviewed implementation, not a new image generator.
Publishing never takes place until a separate fake-only/preparation job PASS.
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
SOURCE = "a5de67680dae51b9dd688e4913af79f77a10d616"
OLD_JOB = "JOB-WULL-CRADLE-MATERIAL-P1E0042-20261003-36"
PROFILE = "profile-1e0042aca8e24db2"
RELATIVE = Path("docs/wull-visual/runs/20261002T183805Z-a5de67")
PNG = RELATIVE / "curated-nested-field-four-edge.png"
PROVENANCE = RELATIVE / "curated-provenance.json"
MANIFEST = ROOT / RELATIVE / "manifest.json"
RECEIPT = ROOT / "automation/results" / (OLD_JOB + ".json")
REMOTE = "https://github.com/llocphann/Hadalis.git"
SSH_REMOTE = "git@github.com:llocphann/Hadalis.git"
MAX_SAFE = 512 * 1024
ROIS = ((8,8,232,232),(280,8,504,232),(8,280,232,504),(280,280,504,504))
EXACT_QT_STAGES = ("BOOT","REAL_FIELD_FOUR_HOSTS_READY","PNG_SAVED")


class Unsafe(Exception):
    pass


def need(flag, code):
    if not flag:
        raise Unsafe(code)


def exact_blob(revision, path):
    p = subprocess.run(["git","rev-parse",revision+":"+path],
                       cwd=ROOT,stdin=subprocess.DEVNULL,
                       stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,
                       text=True,timeout=10)
    need(p.returncode==0 and len(p.stdout.strip())==40,
         "SOURCE_IDENTITY_UNQUALIFIED")
    return p.stdout.strip()


def audit():
    need(Path.cwd().resolve()==ROOT,"ISOLATED_CLONE_UNVERIFIED")
    meta=json.loads(MANIFEST.read_text(encoding="utf-8"))
    receipt=json.loads(RECEIPT.read_text(encoding="utf-8"))
    need(meta.get("run_id")=="20261002T183805Z-a5de67"
         and meta.get("exact_source_sha")==SOURCE
         and meta.get("worker_job")==OLD_JOB
         and meta.get("image_publication","").startswith("NOT_PUBLISHED")
         and receipt.get("job")==OLD_JOB
         and receipt.get("job_commit")==SOURCE
         and receipt.get("profile_id")==PROFILE
         and receipt.get("status")=="passed", "SOURCE_IDENTITY_UNQUALIFIED")
    steps=receipt.get("actions",[])
    need(len(steps)==5 and all(
        x.get("evidence_id")==OLD_JOB+":"+str(i)
        and x.get("source_sha")==SOURCE
        and x.get("exit_code")==0
        and x.get("timed_out") is False
        for i,x in enumerate(steps)),"SOURCE_IDENTITY_UNQUALIFIED")
    # Prevent a later commit from silently using newer Wull/shader/config
    # while claiming that the earlier old-image source was reproduced.
    for path in (
        "modules/abyss/companion/WaterDropletBody.qml",
        "modules/abyss/companion/AbyssCompanion.qml",
        "modules/abyss/looks/AbyssField.qml",
        "modules/abyss/looks/AbyssStyle.qml",
        "scripts/wull-fixtures/real-field-canary/shell.qml",
        "scripts/wull-manual-nested-field-capture.py",
        "defaults/config.json",
    ):
        need(exact_blob("HEAD",path)==exact_blob(SOURCE,path),
             "RENDERER_CHANGED_AFTER_CAPTURE")


def owner_only(path,directory):
    need(not path.is_symlink(),"OWNER_PRIVATE_UNQUALIFIED")
    meta=path.lstat()
    need(meta.st_uid==os.getuid()
         and not stat.S_IMODE(meta.st_mode)&0o077
         and (stat.S_ISDIR(meta.st_mode) if directory
              else stat.S_ISREG(meta.st_mode)),
         "OWNER_PRIVATE_UNQUALIFIED")
    if not directory:
        need(0<meta.st_size<=1024*1024,"OWNER_PRIVATE_UNQUALIFIED")


def private_original():
    root=Path(os.environ.get(
        "XDG_STATE_HOME",str(Path.home()/".local/state"))).expanduser()
    need(root.is_absolute() and not root.is_symlink(),
         "OWNER_PRIVATE_UNQUALIFIED")
    collection=root/"hadalis-wull-nested-field-private"
    owner_only(collection,True)
    candidates=[p for p in collection.iterdir()
                if p.name.startswith("field-"+SOURCE[:12]+"-")
                and p.is_dir() and not p.is_symlink()]
    need(len(candidates)==1,"OWNER_PRIVATE_UNQUALIFIED")
    private=candidates[0]
    owner_only(private,True)
    png=private/"real-field.private.png"
    logfile=private/"qt.private.log"
    nestedlog=private/"nested.private.log"
    for f in (png,logfile,nestedlog):
        owner_only(f,False)
    # Internal Qt state and field readiness were independently captured,
    # while all verbose messages and raw logs stay on the private host.
    lines=logfile.read_text(encoding="utf-8",errors="replace").splitlines()
    stages=[s.split("WULL_FIELD_CANARY_STAGE=",1)[1].strip()
            for s in lines if "WULL_FIELD_CANARY_STAGE=" in s]
    bad=[True for s in lines if "WULL_FIELD_CANARY_FAILURE=" in s]
    need(stages==list(EXACT_QT_STAGES) and not bad,
         "PRIVATE_STAGE_UNQUALIFIED")
    return png.read_bytes()


def check_original_digest(raw):
    state=Path(os.environ.get(
        "XDG_STATE_HOME",str(Path.home()/".local/state"))).expanduser()
    receipt=state/"hadalis-automation"/"worker"/"actions"/OLD_JOB/"action-4.json"
    owner_only(receipt,False)
    record=json.loads(receipt.read_bytes())
    value=record.get("result",{})
    need(record.get("phase")=="finished"
         and value.get("evidence_id")==OLD_JOB+":4"
         and value.get("source_sha")==SOURCE
         and value.get("exit_code")==0
         and value.get("timed_out") is False,
         "OLD_CAPTURE_PROVENANCE_UNAVAILABLE")
    private_output=value.get("stdout","")
    need(type(private_output) is str and len(private_output)<2048
         and len(re.findall(r"(?m)^SOURCE_SHA="+SOURCE+r"$",
                            private_output))==1
         and "NESTED_ISOLATION=HOST_INVARIANT" in private_output
         and "REAL_FIELD_QML=FRAME_AND_FOUR_CELLS_PAINTED" in private_output,
         "OLD_CAPTURE_PROVENANCE_UNAVAILABLE")
    digest=re.findall(r"(?m)^SHEET_SHA256=([0-9a-f]{64})$",private_output)
    need(len(digest)==1 and digest[0]==hashlib.sha256(raw).hexdigest(),
         "OLD_CAPTURE_DIGEST_MISMATCH")


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
                          ["--publish-safe-only"]),"EXPLICIT_MODE_REQUIRED")
    audit()
    raw=private_original()
    check_original_digest(raw)
    inspector=runpy.run_path(
        str(ROOT/"scripts/wull-existing-matrix-evidence-v3.py"),
        run_name="nested_field_rgba_strict_decoder")
    field=runpy.run_path(
        str(ROOT/"scripts/wull-manual-real-field-canary.py"),
        run_name="nested_field_actual_corner_validator")
    width,height,rgba=inspector["rgba_verified"](raw)
    alpha=rgba[3::4]
    field["painted_cells"](alpha,width,height)
    curated=safe_pixels(width,height,rgba,ROIS)
    w,h,pixels=inspector["rgba_verified"](curated)
    field["painted_cells"](pixels[3::4],w,h)
    need(safe_pixels(w,h,pixels,ROIS)==curated,
         "CURATED_PNG_GATE_UNQUALIFIED")
    proof={
        "kind":"CURATED_SYNTHETIC_REAL_ABYSS_FIELD_QSB_NESTED_NIRI",
        "source_sha":SOURCE,
        "source_job":OLD_JOB,
        "source_evidence_id":OLD_JOB+":4",
        "source_fixture":"scripts/wull-fixtures/real-field-canary/shell.qml",
        "field_shader":"modules/abyss/looks/AbyssField.frag.qsb",
        "image_sha256":hashlib.sha256(curated).hexdigest(),
        "dimensions":[512,512],
        "retained_four_rois":[list(x) for x in ROIS],
        "pixel_policy":"only four owned synthetic field+Wull cells; outside RGBA zero",
        "metadata_policy":"new IHDR/IDAT/IEND only",
        "private_original_published":False,
        "source_has_host_screenshot":False,
        "host_output_invariant":"checked by source worker; no host capture",
        "original_references":"UNVERIFIED",
        "visual_review":"NOT_REVIEWED",
        "production_live_panel_weld":"NOT_TESTED",
        "input_popup_native_interaction":"NOT_TESTED",
    }
    if sys.argv[1:]==["--prepare-safe-only"]:
        print("GATE=NESTED_FIELD_CURATED_PRIVATE_VERIFIED")
        return
    publish_curated(curated,proof)
    print("GATE=NESTED_FIELD_CURATED_PUSH_RETURNED_SUCCESS")


if __name__=="__main__":
    try:
        main()
    except (Unsafe,OSError,ValueError,KeyError,subprocess.TimeoutExpired) as err:
        allowed={
            "EXPLICIT_MODE_REQUIRED","ISOLATED_CLONE_UNVERIFIED",
            "SOURCE_IDENTITY_UNQUALIFIED","RENDERER_CHANGED_AFTER_CAPTURE",
            "OWNER_PRIVATE_UNQUALIFIED","PRIVATE_STAGE_UNQUALIFIED",
            "OLD_CAPTURE_PROVENANCE_UNAVAILABLE","OLD_CAPTURE_DIGEST_MISMATCH",
            "CURATION_GEOMETRY_UNQUALIFIED","CURATED_IMAGE_OVERSIZED",
            "CURATED_PNG_GATE_UNQUALIFIED","ISOLATED_CLONE_DIRTY",
            "REMOTE_FETCH_UNAVAILABLE","REMOTE_CHANGED_OR_DIVERGED",
            "ALREADY_PUBLISHED_OR_CONFLICT","PUBLIC_STAGE_UNQUALIFIED",
            "PUBLIC_COMMIT_UNQUALIFIED","PUSH_REF_MOVED",
            "PUSH_AUTH_UNAVAILABLE","PUSH_RESULT_NEEDS_GITHUB_RECONCILIATION",
        }
        reason=str(err)
        print("GATE="+(reason if reason in allowed
                       else "NESTED_FIELD_CURATION_INCONCLUSIVE"))
        raise SystemExit(1)
