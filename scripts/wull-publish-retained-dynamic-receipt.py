#!/usr/bin/env python3
"""Source-pinned, opt-in publication of OLD Wull Qt samples. No Qt execution."""
import json
import os
from pathlib import Path
import runpy
import stat
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
SOURCE = "4caccd2058f1b3089ec398a131241f800eaae890"
RUNNER_BLOB = "9cab00fca46212c819ac7308cfc0d6923d1139d3"
INERT_BLOB = "023cdaccd9d0f8234b9dea0b4fb1bdc43c1c3754"
POSTMORTEM_BLOB = "73904dbda1de437a8586925d32fa774af6b04d5e"
FIXTURE_BLOB = "6e3b5402d32d263868c1ec688925adba0fd7250b"
FROZEN_BLOB = "dc2f36b525ef7e412869f155153dc4e48720f898"
PATH = Path("docs/wull-qt-dynamic-retained-4caccd2058f1-scale-parser.json")
SCRATCH = Path("/tmp/wull-qt-state.TwSIa1/hadalis/wull-qt-motion.y2aZdO")
ORIGINS = {
    "https://github.com/llocphann/Hadalis.git",
    "https://github.com/llocphann/Hadalis",
    "git@github.com:llocphann/Hadalis.git",
    "git@github.com:llocphann/Hadalis",
    "ssh://git@github.com/llocphann/Hadalis.git",
    "ssh://git@github.com/llocphann/Hadalis",
}


class Stop(Exception):
    pass


def gate(ok, code):
    if not ok:
        raise Stop(code)


def git(*args):
    p = subprocess.run(["git", *args], cwd=ROOT, capture_output=True,
                       text=True, stdin=subprocess.DEVNULL, timeout=45)
    gate(p.returncode == 0, "GIT_STEP_FAILED")
    return p.stdout.strip()


def remote_head():
    refs = git("ls-remote", "origin", "refs/heads/dev").splitlines()
    gate(len(refs) == 1 and len(refs[0].split()) == 2,
         "UNVERIFIED_REMOTE_HEAD")
    return refs[0].split()[0]


def audited_clone():
    gate(ROOT.name == "repo" and
         ROOT.parent.name.startswith("wull-retained-receipt.") and
         not ROOT.is_symlink() and not ROOT.parent.is_symlink() and
         Path.cwd().resolve() == ROOT, "UNREVIEWED_CLONE")
    for path in (ROOT, ROOT.parent):
        s = path.stat()
        gate(s.st_uid == os.getuid() and
             not stat.S_IMODE(s.st_mode) & 0o077, "UNSAFE_CLONE_PERMISSIONS")
    gate(git("branch", "--show-current") == "dev" and
         not git("status", "--porcelain=v1", "--untracked-files=all"),
         "WRONG_BRANCH_OR_DIRTY_CLONE")
    gate(git("remote", "get-url", "origin") in ORIGINS and
         git("remote", "get-url", "--push", "origin") in ORIGINS,
         "UNVERIFIED_REMOTE")
    head = git("rev-parse", "HEAD")
    gate(head == remote_head(), "REMOTE_MOVED")
    required = {
        "scripts/wull-manual-offscreen-dynamic-geometry.py": RUNNER_BLOB,
        "scripts/test-wull-offscreen-dynamic-geometry-contract.py": INERT_BLOB,
        "scripts/wull-private-dynamic-parser-postmortem.py": POSTMORTEM_BLOB,
        "scripts/wull-fixtures/motion-envelope/shell.qml": FIXTURE_BLOB,
        "docs/wull-qt-motion-20261001T185752Z-53e5c5cc-72ac0580b12e.json":
            FROZEN_BLOB,
    }
    for path, blob in required.items():
        gate(git("rev-parse", "HEAD:" + path) == blob, "SOURCE_BLOB_CHANGED")
    gate(not (ROOT / PATH).exists() and not (ROOT / PATH).is_symlink(),
         "RECEIPT_ALREADY_EXISTS")
    return head


def derive(raw, parser, head):
    gate("WULL_OFFSCREEN_DYNAMIC_INVALID" not in raw and
         "WULL_OFFSCREEN_DYNAMIC_TIMEOUT" not in raw, "INVALID_OLD_RUN")
    gate(parser["private_stage_summary"](raw) ==
         list(parser["EXPECTED_STAGES"]), "STAGE_SEQUENCE_INVALID")
    markers = [line.split(parser["MARKER"], 1)[1]
               for line in raw.splitlines() if parser["MARKER"] in line]
    gate(len(markers) == 1, "MARKER_COUNT_INVALID")
    proof = parser["model_summary"](
        json.loads(markers[0]), parser["known_frozen"]())
    gate(proof["status"] == "pass" and
         proof["all_dynamic_state_witnesses"] is True and
         proof["observed_host_cases"] == 12, "OLD_MODEL_NOT_PASS")
    report = parser["public_report"](
        proof, SOURCE, head, "0.3.1", "not_recorded")
    report.update({
        "kind": "wull_retrospective_requalified_private_qml_samples",
        "verification_method": "retained_pinned_log_corrected_parser",
        "corrected_parser_blob": RUNNER_BLOB,
        "original_private_qs_exit":
            "maintainer_reported_ZERO_not_reverified_from_log",
        "new_qt_execution": "not_run",
        "retrospective_receipt_not_production_acceptance": True,
    })
    return report


def main():
    gate(sys.argv[1:] == ["--acknowledge-retained-publication"],
         "EXPLICIT_OWNER_OPT_IN_REQUIRED")
    os.umask(0o077)
    head = audited_clone()
    old = runpy.run_path(str(ROOT /
        "scripts/wull-private-dynamic-parser-postmortem.py"),
        run_name="retained_only_guard")
    _, log = old["owner_guard"](SCRATCH)
    for item in (log.parent, log):
        s = item.stat()
        gate(not item.is_symlink() and s.st_uid == os.getuid() and
             not stat.S_IMODE(s.st_mode) & 0o077,
             "OLD_PRIVATE_LOG_NOT_RESTRICTED")
    parser = runpy.run_path(str(ROOT /
        "scripts/wull-manual-offscreen-dynamic-geometry.py"),
        run_name="retained_only_parser")
    report = derive(log.read_text(encoding="utf-8", errors="replace"),
                    parser, head)
    gate(head == remote_head() and
         not git("status", "--porcelain=v1", "--untracked-files=all"),
         "REMOTE_MOVED")
    with (ROOT / PATH).open("x", encoding="utf-8") as out:
        json.dump(report, out, indent=2, ensure_ascii=True)
        out.write("\n")
    git("add", "--", str(PATH))
    gate(git("diff", "--cached", "--name-only") == str(PATH) and
         not git("diff", "--name-only") and
         not git("ls-files", "--others", "--exclude-standard"),
         "EXCLUSIVITY_UNVERIFIED")
    gate(head == remote_head(), "REMOTE_MOVED")
    git("commit", "-m", "test(wull): publish bounded retained Qt sample receipt",
        "--", str(PATH))
    commit = git("rev-parse", "HEAD")
    push = subprocess.run(["git", "push", "origin", "HEAD:refs/heads/dev"],
                          cwd=ROOT, capture_output=True,
                          stdin=subprocess.DEVNULL, timeout=60)
    gate(push.returncode == 0, "PUBLICATION_SKIPPED_CONCURRENT_DEV")
    gate(remote_head() == commit, "PUBLICATION_IDENTITY_UNVERIFIED")
    print("SOURCE_SHA=" + SOURCE)
    print("MODEL_STATUS=pass")
    print("OBSERVED_HOST_CASES=12")
    print("NEW_QT_RUN=NO")
    print("PUBLICATION_COMMIT=" + commit)
    print("REPORT_PUBLISHED=" + str(PATH))
    print("GATE=RETROSPECTIVE_QT_RECEIPT_PUBLISHED")


if __name__ == "__main__":
    try:
        main()
    except (Stop, OSError, ValueError, TypeError, KeyError,
            subprocess.TimeoutExpired) as exc:
        safe = {
            "EXPLICIT_OWNER_OPT_IN_REQUIRED", "UNREVIEWED_CLONE",
            "UNSAFE_CLONE_PERMISSIONS", "WRONG_BRANCH_OR_DIRTY_CLONE",
            "UNVERIFIED_REMOTE", "UNVERIFIED_REMOTE_HEAD", "REMOTE_MOVED",
            "SOURCE_BLOB_CHANGED", "RECEIPT_ALREADY_EXISTS",
            "INVALID_OLD_RUN", "STAGE_SEQUENCE_INVALID",
            "MARKER_COUNT_INVALID", "OLD_MODEL_NOT_PASS",
            "OLD_PRIVATE_LOG_NOT_RESTRICTED", "EXCLUSIVITY_UNVERIFIED",
            "PUBLICATION_SKIPPED_CONCURRENT_DEV",
            "PUBLICATION_IDENTITY_UNVERIFIED", "GIT_STEP_FAILED",
        }
        code = str(exc)
        print("GATE=" + (code if code in safe else "OLD_EVIDENCE_UNAVAILABLE"))
        sys.exit(1)
