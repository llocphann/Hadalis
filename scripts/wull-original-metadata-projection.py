#!/usr/bin/env python3
"""Project only existing -52 ORIGINAL source metadata into an audited public metadata artifact.

The tracked source images are already published repository assets, not machine
screenshots. Private worker stdout/logs never become Git result payloads.
Prepare and publish are distinct explicit jobs; unknown push outcome is terminal.
"""
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import struct
import subprocess
import sys
import zlib

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
PROFILE="profile-1e0042aca8e24db2"
OLD_JOB="JOB-WULL-ORIGINAL-PNG-METADATA-P1E0042-20261003-52"
OLD_SHA="d1f1231790bd8d683cced6bd52bcc966cc95b75b"
OLD_BASE="4e6c48a22973b29f55d0c0a855a8586f475e037e"
REL="docs/wull-visual/reference/source-metadata.json"
SCRIPT="scripts/wull-original-metadata-projection.py"
REMOTE="https://github.com/llocphann/Hadalis.git"
SSH_REMOTE="git@github.com:llocphann/Hadalis.git"
EXPECTED=(
 ("Water Droplet Companion.png","d232af73adeb2e9d4673ced04269f73a5d84a06d",2109568),
 ("Water Droplet Companion Expression.png","f11033572cd43634be1c5a6451f5d172989c17a8",2179910),
 ("Water Droplet Companion Animation.png","dbeabf0c00b58f5ef1e32a5f86016fbd1e71881a",1896556),
 ("Water Droplet Companion Animation Plus.png","01d76718c365fe675359b3bfc9e5b303bbacaff6",1930250),
)

class Unsafe(Exception):
    pass

def need(condition, tag):
    if not condition:
        raise Unsafe(tag)

def source_file(name):
    path=ROOT/"assets"/name
    need(path.is_file() and not path.is_symlink(),"SOURCE_ASSET_UNQUALIFIED")
    return path.read_bytes()

def check_assets(rows):
    need(isinstance(rows,list) and len(rows)==4,"METADATA_SHAPE_UNQUALIFIED")
    safe=[]
    for row,(name,blob,size) in zip(rows,EXPECTED):
        need(type(row)==dict and set(row)=={"file","git_blob","bytes","sha256","width","height","bit_depth","color_type"},
             "METADATA_SHAPE_UNQUALIFIED")
        need(row["file"]=="assets/"+name and row["git_blob"]==blob and row["bytes"]==size,
             "METADATA_SOURCE_MISMATCH")
        raw=source_file(name)
        actual_blob=hashlib.sha1(("blob "+str(len(raw))+"\0").encode("ascii")+raw).hexdigest()
        need(len(raw)==size and actual_blob==blob,"SOURCE_ASSET_CHANGED")
        need(row["sha256"]==hashlib.sha256(raw).hexdigest() and re.fullmatch("[0-9a-f]{64}",row["sha256"]) is not None,
             "METADATA_DIGEST_MISMATCH")
        need(len(raw)>=33 and raw[:8]==b"\x89PNG\r\n\x1a\n" and raw[12:16]==b"IHDR" and raw[8:12]==b"\0\0\0\r",
             "SOURCE_PNG_UNQUALIFIED")
        need((zlib.crc32(raw[12:29])&0xffffffff)==struct.unpack_from(">I",raw,29)[0],
             "SOURCE_PNG_UNQUALIFIED")
        w,h=struct.unpack_from(">II",raw,16)
        need(100<=w<=16000 and 100<=h<=16000 and row["width"]==w and row["height"]==h
             and row["bit_depth"]==raw[24] and row["color_type"]==raw[25],
             "METADATA_IHDR_MISMATCH")
        safe.append(dict(row))
    return safe

def owner_private(path):
    need(not path.is_symlink() and path.is_file(),"PRIVATE_RECEIPT_UNAVAILABLE")
    s=path.stat()
    need(s.st_uid==os.getuid() and stat.S_IMODE(s.st_mode)&0o077==0
         and 0<s.st_size<=16384,"PRIVATE_RECEIPT_UNAVAILABLE")

def read_existing_metadata():
    receipt=ROOT/"automation/results"/(OLD_JOB+".json")
    pub=json.loads(receipt.read_text(encoding="utf-8"))
    a=pub.get("actions",[])
    need(pub.get("job")==OLD_JOB and pub.get("job_commit")==OLD_SHA
         and pub.get("base_sha")==OLD_BASE and pub.get("profile_id")==PROFILE
         and pub.get("status")=="passed" and len(a)==1,
         "HISTORICAL_RECEIPT_UNQUALIFIED")
    action=a[0]
    need(action.get("evidence_id")==OLD_JOB+":0"
         and action.get("source_sha")==OLD_SHA and action.get("exit_code")==0
         and action.get("timed_out") is False and action.get("cancelled") is False
         and action.get("stdout_truncated") is False and action.get("stderr_bytes")==0,
         "HISTORICAL_RECEIPT_UNQUALIFIED")
    state=Path(os.environ.get("XDG_STATE_HOME",str(Path.home()/".local/state"))).expanduser()
    need(state.is_absolute() and not state.is_symlink(),"PRIVATE_RECEIPT_UNAVAILABLE")
    p=state/"hadalis-automation"/"worker"/"actions"/OLD_JOB/"action-0.json"
    owner_private(p)
    record=json.loads(p.read_text(encoding="utf-8"))
    result=record.get("result",{})
    need(record.get("phase")=="finished"
         and result.get("evidence_id")==action["evidence_id"]
         and result.get("source_sha")==OLD_SHA and result.get("exit_code")==0
         and result.get("timed_out") is False,
         "PRIVATE_EVIDENCE_UNQUALIFIED")
    out=result.get("stdout")
    need(type(out)==str and len(out.encode("utf-8"))==action["stdout_bytes"]
         and hashlib.sha256(out.encode("utf-8")).hexdigest()==action["stdout_sha256"],
         "PRIVATE_EVIDENCE_DIGEST_MISMATCH")
    data=json.loads(out)
    need(type(data)==dict and set(data)=={"schema","source","original_png_pixels_inspected","assets"}
         and data["schema"]==1 and data["source"]=="immutable-tracked-assets"
         and data["original_png_pixels_inspected"] is False,
         "METADATA_SHAPE_UNQUALIFIED")
    rows=check_assets(data["assets"])
    version=hashlib.sha256(json.dumps(rows,sort_keys=True,separators=(",",":")).encode()).hexdigest()
    return {
      "schema":1,"kind":"AUTHENTIC_TRACKED_WULL_REFERENCE_SOURCE_METADATA",
      "reference_version":"authentic-assets-sha256-"+version[:16],
      "identity_status":"FOUR_SOURCE_BYTES_SHA256_IHDR_VERIFIED",
      "visual_review":"ORIGINAL_PIXELS_NOT_YET_VIEWED",
      "original_assets_unchanged":True,
      "source_job":OLD_JOB,"source_evidence_id":OLD_JOB+":0",
      "source_job_sha":OLD_SHA,"observed_at_unix":action["observed_at_unix"],
      "stdout_digest_verified":action["stdout_sha256"],
      "assets":rows
    }

def cmd(argv,timeout=25):
    from automation.manager.credentials import git_env
    env=git_env()
    env.update({"GIT_TERMINAL_PROMPT":"0","GCM_INTERACTIVE":"never",
                "GIT_ASKPASS":"/bin/false","SSH_ASKPASS":"/bin/false"})
    return subprocess.run(argv,cwd=ROOT,env=env,stdin=subprocess.DEVNULL,
                          stdout=subprocess.PIPE,stderr=subprocess.PIPE,
                          text=True,timeout=timeout,check=False)

def git_object(path):
    r=cmd(["git","rev-parse","HEAD:"+path],10)
    need(r.returncode==0 and re.fullmatch("[0-9a-f]{40}",r.stdout.strip()) is not None,
         "GIT_SOURCE_UNQUALIFIED")
    return r.stdout.strip()

def publish(metadata):
    need(cmd(["git","status","--porcelain=v1"]).stdout.strip()=="",
         "ISOLATED_CLONE_DIRTY")
    script_blob=git_object(SCRIPT)
    before=[git_object("assets/"+name) for name,_,_ in EXPECTED]
    need(before==[blob for _,blob,_ in EXPECTED],"GIT_ASSET_SOURCE_CHANGED")
    fetched=cmd(["git","fetch","--no-tags",REMOTE,"refs/heads/dev"],35)
    need(fetched.returncode==0,"REMOTE_FETCH_UNAVAILABLE")
    merged=cmd(["git","merge","--ff-only","FETCH_HEAD"],20)
    need(merged.returncode==0,"REMOTE_CHANGED_OR_DIVERGED")
    need(git_object(SCRIPT)==script_blob
         and [git_object("assets/"+name) for name,_,_ in EXPECTED]==before,
         "SOURCE_CHANGED_DURING_PUBLISH")
    need(not (ROOT/REL).exists(),"METADATA_ALREADY_PUBLISHED")
    # Check genuine bytes AGAIN after remote fast-forward, never a guessed hash.
    check_assets(metadata["assets"])
    (ROOT/REL).write_text(json.dumps(metadata,indent=2,sort_keys=True)+"\n",encoding="utf-8")
    staged=cmd(["git","add","--",REL])
    need(staged.returncode==0,"ARTIFACT_STAGE_UNQUALIFIED")
    changed=cmd(["git","diff","--cached","--name-only"])
    need(changed.returncode==0 and changed.stdout.strip()==REL,
         "ARTIFACT_STAGE_UNQUALIFIED")
    committed=cmd(["git","-c","user.name=Hadalis-Wull-Evidence",
                   "-c","user.email=actions@users.noreply.github.com",
                   "commit","-m","test(wull): publish verified authentic source metadata only"])
    need(committed.returncode==0,"ARTIFACT_COMMIT_UNQUALIFIED")
    from automation.manager.credentials import git_options,has_token
    remote=REMOTE if has_token(PROFILE) else SSH_REMOTE
    pushed=cmd(["git",*git_options(PROFILE,remote),"push",remote,
                "HEAD:refs/heads/dev"],35)
    need(pushed.returncode==0,"PUSH_RESULT_REQUIRES_GITHUB_RECONCILIATION")

def main():
    need(sys.argv[1:] in (["--prepare-safe-only"],["--publish-safe-only"]),
         "EXPLICIT_MODE_REQUIRED")
    need(Path.cwd().resolve()==ROOT,"ISOLATED_CLONE_UNQUALIFIED")
    meta=read_existing_metadata()
    # No SHA-256 values or original pixels are printed to private logs.
    if sys.argv[1:]==["--prepare-safe-only"]:
        print("GATE=ORIGINAL_REFERENCE_PRIVATE_RECEIPT_METADATA_QUALIFIED")
    else:
        publish(meta)
        print("GATE=ORIGINAL_REFERENCE_SOURCE_METADATA_SAFE_PUSH_RETURNED_SUCCESS")

if __name__=="__main__":
    try:
        main()
    except Exception as e:
        # Only a bounded enum escapes; private exception text and paths never do.
        tag=str(e) if isinstance(e,Unsafe) else "PROJECTION_UNCLASSIFIED"
        print("GATE="+tag)
        raise SystemExit(1)
