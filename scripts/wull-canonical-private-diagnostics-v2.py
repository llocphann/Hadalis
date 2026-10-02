#!/usr/bin/env python3
"""Bounded READ-ONLY classification of an EXISTING canonical validation log.

Never reruns the validator, reads live desktop state, publishes private paths,
outputs a failed command, or copies raw logs into Git receipts. This is a
diagnostic, not attribution of a Wull source regression.
"""
import json
import os
from pathlib import Path
import re
import stat
import sys
import tempfile

ROOT=Path(__file__).resolve().parents[1]
ORIGINAL="JOB-WULL-CANONICAL-P1E0042-20261003-40"
EXACT_SOURCE="303478eae6cebe601486ab84db17dd3a5b9c2750"
PROFILE="profile-1e0042aca8e24db2"
CATEGORIES={
    "translations / documentation drift":"DOCUMENTATION",
    "QML / module resolution / Connected Perimeter":"QML_MODULE",
    "install / relocation / packaging":"INSTALL_PACKAGE",
    "service lifecycle / timeout / recovery":"LIFECYCLE",
    "tracked source syntax":"SOURCE_SYNTAX",
    "other regression contracts":"OTHER_REGRESSION",
}


class Inconclusive(Exception):
    pass


def need(ok,code):
    if not ok:
        raise Inconclusive(code)


def owned(path, limit, require_private=True):
    need(not path.is_symlink(),"EVIDENCE_FILE_UNQUALIFIED")
    st=path.lstat()
    need(stat.S_ISREG(st.st_mode) and st.st_uid==os.getuid()
         and 0<st.st_size<=limit,"EVIDENCE_FILE_UNQUALIFIED")
    if require_private:
        need(not stat.S_IMODE(st.st_mode)&0o077,
             "PRIVATE_LOG_PERMISSION_UNQUALIFIED")


def summary(raw):
    """Returns sanitized suite categories only; no private test labels."""
    if len(raw)>1024*1024:
        return None
    failed=re.findall(r"(?m)^Failed: (\d{1,5})$",raw)
    result=re.findall(r"(?m)^Result: (PASS|FAIL)$",raw)
    if len(failed)!=1 or len(result)!=1:
        return ("CANONICAL_LOG_NO_SUMMARY",0,())
    number=int(failed[0])
    if number==0 or result[0]!="FAIL":
        return ("VALIDATOR_EXIT_INCONSISTENT",number,())
    region=re.search(
        r"(?ms)^Primary failure groups:\n(.*?)^Skipped checks:",raw)
    if not region:
        return ("CANONICAL_LOG_UNQUALIFIED",number,())
    groups=[]
    for line in region.group(1).splitlines():
        token=line.strip()
        if not token.startswith("- "):
            return ("CANONICAL_LOG_UNQUALIFIED",number,())
        group=CATEGORIES.get(token[2:])
        if not group:
            return ("CANONICAL_LOG_UNQUALIFIED",number,())
        if group not in groups:
            groups.append(group)
    if len(groups)==0:
        return ("CANONICAL_LOG_UNQUALIFIED",number,())
    return ("CANONICAL_FAILURE_GROUPS_CLASSIFIED",number,tuple(sorted(groups)))


def main():
    need(sys.argv[1:]==["--read-only-classify"],
         "EXPLICIT_READ_ONLY_MODE_REQUIRED")
    receipts=ROOT/"automation/results"/(ORIGINAL+".json")
    doc=json.loads(receipts.read_text(encoding="utf-8"))
    actions=doc.get("actions",[])
    need(doc.get("job")==ORIGINAL
         and doc.get("profile_id")==PROFILE
         and doc.get("job_commit")==EXACT_SOURCE
         and doc.get("status")=="failed"
         and len(actions)==1
         and actions[0].get("evidence_id")==ORIGINAL+":0"
         and actions[0].get("source_sha")==EXACT_SOURCE
         and actions[0].get("exit_code")==1
         and actions[0].get("timed_out") is False,
         "IMMUTABLE_RECEIPT_UNQUALIFIED")
    base=Path(os.environ.get(
        "XDG_STATE_HOME",str(Path.home()/".local/state"))).expanduser()
    need(base.is_absolute() and not base.is_symlink(),
         "EVIDENCE_SCOPE_UNQUALIFIED")
    private=base/"hadalis-automation"/"worker"/"actions"/ORIGINAL/"action-0.json"
    owned(private,64*1024,True)
    ledger=json.loads(private.read_bytes())
    result=ledger.get("result",{})
    need(ledger.get("phase")=="finished"
         and result.get("evidence_id")==ORIGINAL+":0"
         and result.get("source_sha")==EXACT_SOURCE
         and result.get("exit_code")==1
         and result.get("observed_at_unix")==actions[0]["observed_at_unix"]
         and result.get("timed_out") is False,
         "PRIVATE_WORKER_LEDGER_UNQUALIFIED")
    stdout=result.get("stdout","")
    need(isinstance(stdout,str) and len(stdout)<64*1024
         and len(re.findall("(?m)^SHA: "+EXACT_SOURCE+r"$",stdout))==1,
         "PINNED_VALIDATOR_OUTPUT_UNQUALIFIED")
    found=re.findall(r"(?m)^FINAL LOG: (/[^\n]{1,180})$",stdout)
    need(len(found)==1,"PRIVATE_LOG_REFERENCE_MISSING")
    target=Path(found[0])
    # The canonical runner's reviewed default is /tmp. Refuse arbitrary
    # paths printed by untrusted process output; do not resolve symlinks.
    need(target.parent==Path(tempfile.gettempdir()).resolve()
         and re.fullmatch(
             r"hadalis-maintainer-validation-[0-9-]{8}-[0-9]{6}\.log",
             target.name) is not None,"PRIVATE_LOG_SCOPE_UNQUALIFIED")
    # The original validator ran BEFORE the newly added owner-only umask.
    # This one OLD, exact-worker-verified log may have permissive mode;
    # never expand pathname scope, emit raw log content, or change old files.
    # Newly generated validation logs must remain 0600 by source contract.
    owned(target,1024*1024,False)
    legacy_permissive = bool(stat.S_IMODE(target.lstat().st_mode)&0o077)
    content=target.read_text(encoding="utf-8",errors="replace")
    need(len(content)<1024*1024
         and len(re.findall(r"(?m)^Exact SHA: "+EXACT_SOURCE+r"$",content))==1,
         "PINNED_VALIDATOR_LOG_UNQUALIFIED")
    gate, failed, categories=summary(content)
    need(gate=="CANONICAL_FAILURE_GROUPS_CLASSIFIED",gate)
    print("LEGACY_LOG_PERMISSIONS="+("NOT_PRIVATE" if legacy_permissive else "PRIVATE"))
    print("CANONICAL_SOURCE_SHA="+EXACT_SOURCE)
    print("CANONICAL_RECEIPT_ID="+ORIGINAL+":0")
    print("CANONICAL_FAILED_CHECKS="+str(failed))
    print("CANONICAL_FAILURE_CATEGORIES="+",".join(categories))
    print("PRIVATE_LOG_PATH_OR_FAILED_COMMAND=NOT_PUBLISHED")
    print("GATE=CANONICAL_FAILURE_GROUPS_CLASSIFIED")


if __name__=="__main__":
    try:
        main()
    except (Inconclusive,OSError,ValueError,KeyError) as err:
        allowed={
            "EXPLICIT_READ_ONLY_MODE_REQUIRED","IMMUTABLE_RECEIPT_UNQUALIFIED",
            "EVIDENCE_SCOPE_UNQUALIFIED","EVIDENCE_FILE_UNQUALIFIED",
            "PRIVATE_LOG_PERMISSION_UNQUALIFIED","PRIVATE_WORKER_LEDGER_UNQUALIFIED",
            "PINNED_VALIDATOR_OUTPUT_UNQUALIFIED",
            "PRIVATE_LOG_REFERENCE_MISSING","PRIVATE_LOG_SCOPE_UNQUALIFIED",
            "PINNED_VALIDATOR_LOG_UNQUALIFIED","CANONICAL_LOG_NO_SUMMARY",
            "VALIDATOR_EXIT_INCONSISTENT","CANONICAL_LOG_UNQUALIFIED",
        }
        message=str(err)
        print("GATE="+(message if message in allowed
                       else "CANONICAL_DIAGNOSTICS_INCONCLUSIVE"))
        raise SystemExit(1)
