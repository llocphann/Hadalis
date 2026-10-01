#!/usr/bin/env python3
"""Explicit PRIVATE, READ-ONLY old-log classification; sanitized Git report.

Run ONLY from a throwaway clean dev clone under the current user's
private XDG state directory. Never runs Niri, Quickshell or wdotool;
never changes the user's original Hadalis checkout. No force pushes.
"""
import json
import os
from pathlib import Path
import runpy
import stat
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
REPORT = "wull-mask-candidate-20261001T170950Z-105fd7a8-1518db798d10.json"
REPORT_SOURCE = "1518db798d1012592cdbceb29115cceb72cffd9b"
REPORT_BLOB = "973ffcccab705359fdbe1bdc12976cb1e04e2db5"
DIAGNOSTIC = "scripts/wull-private-pointer-drift-diagnostic.py"
DIAGNOSTIC_BLOB = "91c2207e7d96aa8852f6d6f8df0ea1cb28d647d2"
TARGET = "docs/wull-pointer-drift-20261001T170950Z-105fd7a8-1518db798d10.json"
SAFE_REMOTES = {
    "https://github.com/llocphann/Hadalis",
    "https://github.com/llocphann/Hadalis.git",
    "git@github.com:llocphann/Hadalis",
    "git@github.com:llocphann/Hadalis.git",
    "ssh://git@github.com/llocphann/Hadalis",
    "ssh://git@github.com:llocphann/Hadalis.git",
}
ALLOWED = {
    "offset_bucket": {
        "within_six", "seven_to_twenty_three",
        "twenty_four_to_ninety_five", "ninety_six_or_more"},
    "offset_axes": {"both", "horizontal", "vertical", "within_tolerance"},
    "horizontal_direction": {"positive", "negative", "near"},
    "vertical_direction": {"positive", "negative", "near"},
}


def stop(reason):
    raise RuntimeError(reason)


def git(*args):
    done = subprocess.run(
        ["git", *args], cwd=ROOT, capture_output=True, text=True,
        timeout=50)
    if done.returncode:
        stop("git_step_failed_" + args[0])
    return done.stdout.strip()


def no_changes():
    return not git("status", "--porcelain=v1", "--untracked-files=all")


def controlled_checkout(state):
    if (Path.cwd().resolve() != ROOT
            or git("symbolic-ref", "--short", "HEAD") != "dev"
            or not no_changes()
            or ROOT.parent.parent.resolve() != (state / "hadalis").resolve()
            or not ROOT.parent.name.startswith("wull-drift-publish.")
            or ROOT.name != "repo"
            or stat.S_IMODE(ROOT.parent.stat().st_mode) & 0o077):
        stop("isolated_clean_private_dev_clone_required")
    origin = git("remote", "get-url", "origin")
    push = git("remote", "get-url", "--push", "--all", "origin").splitlines()
    if origin not in SAFE_REMOTES or len(push) != 1 or push[0] not in SAFE_REMOTES:
        stop("unexpected_origin_or_push_url")


def audit_source(revision):
    if git("rev-parse", revision + ":" + DIAGNOSTIC) != DIAGNOSTIC_BLOB:
        stop("diagnostic_source_changed_after_review")
    if git("rev-parse", revision + ":docs/" + REPORT) != REPORT_BLOB:
        stop("sanitized_original_report_changed_after_review")
    if subprocess.run(
            ["git", "merge-base", "--is-ancestor", REPORT_SOURCE, revision],
            cwd=ROOT, capture_output=True, timeout=10).returncode:
        stop("original_real_pointer_source_not_ancestor")


def private_classification(state):
    report_path = ROOT / "docs" / REPORT
    if (report_path.is_symlink() or not report_path.is_file()
            or not 0 < report_path.stat().st_size <= 65536):
        stop("public_receipt_unavailable")
    receipt = json.loads(report_path.read_text(encoding="utf-8"))
    if receipt.get("source_sha") != REPORT_SOURCE:
        stop("original_source_id_mismatch")
    # Read only the exact private log associated with that public report.
    # Never print or place full pointer coordinates in a Git worktree.
    match = runpy.run_path(
        str(ROOT / DIAGNOSTIC), run_name="wull_drift_read_only_import")
    parsed = match["NAME"].fullmatch(REPORT)
    if parsed is None:
        stop("public_report_identity_unverified")
    session = state / "hadalis" / (
        "wull-pointer-" + parsed.group(1) + "-" + parsed.group(2))
    log = session / "nested/child/underlay/quickshell.private.log"
    if (not session.is_dir() or session.is_symlink()
            or session.stat().st_uid != os.getuid()
            or not log.is_file() or log.is_symlink()
            or log.stat().st_uid != os.getuid()
            or not 0 < log.stat().st_size <= match["MAX_LOG"]):
        stop("private_prior_run_log_unavailable")
    categories = match["classify"](
        receipt, REPORT, log.read_text(encoding="utf-8", errors="replace"))
    if (set(categories) != set(ALLOWED) |
            {"candidate_near_previous_disabled_center"}):
        stop("diagnostic_output_schema_changed")
    if any(categories[k] not in allowed for k, allowed in ALLOWED.items()):
        stop("unreviewed_diagnostic_value")
    if type(categories["candidate_near_previous_disabled_center"]) is not bool:
        stop("unreviewed_diagnostic_boolean")
    return categories


def payload(categories, source, parent):
    if (not isinstance(source, str) or len(source) != 40
            or not isinstance(parent, str) or len(parent) != 40):
        stop("invalid_publication_commit_identity")
    if (set(categories) != set(ALLOWED) |
            {"candidate_near_previous_disabled_center"}
            or any(categories[k] not in allowed
                   for k, allowed in ALLOWED.items())
            or type(categories["candidate_near_previous_disabled_center"])
            is not bool):
        stop("unreviewed_sanitized_result")
    return {
        "kind": "wull_retrospective_top_private_pointer_drift",
        "source_sha": source,
        "original_source_sha": REPORT_SOURCE,
        "original_sanitized_report": "docs/" + REPORT,
        "status": "categorized_from_private_prior_log",
        "diagnostic": dict(categories),
        "injection_backend_at_original_run": "forced_wlr_protocols_wdotool",
        "raw_log_coordinates": "private_local_only",
        "new_pointer_input": False,
        "real_native_retest": "not_run",
        "production_mask_changed": False,
        "host_user_config_changed": False,
        "publication_parent_sha": parent,
    }


def publish(report):
    target = ROOT / TARGET
    path = Path(TARGET)
    if target.exists() or target.is_symlink():
        stop("existing_drift_receipt_refuse_to_overwrite")
    target.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    git("add", "--", TARGET)
    if git("diff", "--cached", "--name-only") != TARGET:
        stop("unexpected_paths_staged")
    git("commit", "-m", "test(wull): publish sanitized retrospective pointer drift", "--", TARGET)
    for attempt in range(4):
        if not no_changes() or git(
                "diff-tree", "--no-commit-id", "--name-only",
                "-r", "HEAD") != TARGET:
            stop("not_an_exclusive_unpublished_drift_receipt")
        pushed = subprocess.run(
            ["git", "push", "origin", "HEAD:refs/heads/dev"],
            cwd=ROOT, capture_output=True, timeout=60)
        if pushed.returncode == 0:
            print("WULL_DRIFT_RECEIPT_PUBLISHED: " + TARGET, flush=True)
            return
        if attempt == 3:
            stop("push_refused_isolated_receipt_kept_local")
        parent = git("rev-parse", "HEAD^")
        git("fetch", "--quiet", "origin",
            "refs/heads/dev:refs/remotes/origin/dev")
        remote = git("rev-parse", "refs/remotes/origin/dev")
        audit_source(remote)
        if subprocess.run(
                ["git", "merge-base", "--is-ancestor", parent, remote],
                cwd=ROOT, capture_output=True, timeout=10).returncode:
            stop("remote_diverged_isolated_receipt_kept_local")
        git("rebase", "--onto", remote, parent)  # isolated receipt ONLY
        if (not no_changes() or git(
                "diff-tree", "--no-commit-id", "--name-only",
                "-r", "HEAD") != TARGET):
            stop("isolated_replay_integrity_failed")
        report["publication_parent_sha"] = git("rev-parse", "HEAD^")
        target.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        git("add", "--", TARGET)
        if git("diff", "--cached", "--name-only") != TARGET:
            stop("unexpected_replay_paths")
        git("commit", "--amend", "--no-edit")


def main():
    if sys.argv[1:] != ["--publish-existing-top-off-target"]:
        stop("explicit_retrospective_publication_opt_in_required")
    os.umask(0o077)
    state = Path(os.environ.get(
        "XDG_STATE_HOME", str(Path.home() / ".local/state"))).expanduser().resolve()
    controlled_checkout(state)
    git("fetch", "--quiet", "origin",
        "refs/heads/dev:refs/remotes/origin/dev")
    remote = git("rev-parse", "refs/remotes/origin/dev")
    audit_source(remote)
    git("merge", "--ff-only", remote)
    if not no_changes():
        stop("isolation_worktree_dirtied_during_fetch")
    source = git("rev-parse", "HEAD")
    categories = private_classification(state)
    # The source and exact reporter are re-reviewed immediately before commit.
    git("fetch", "--quiet", "origin",
        "refs/heads/dev:refs/remotes/origin/dev")
    later = git("rev-parse", "refs/remotes/origin/dev")
    audit_source(later)
    git("merge", "--ff-only", later)
    if not no_changes():
        stop("isolation_worktree_dirtied_before_publication")
    parent = git("rev-parse", "HEAD")
    summary = payload(categories, source, parent)
    print("WULL_RETROSPECTIVE_DRIFT_CLASSIFIED", flush=True)
    print("OFFSET_BUCKET: " + categories["offset_bucket"], flush=True)
    print("OFFSET_AXES: " + categories["offset_axes"], flush=True)
    print("RAW_COORDINATES: private_local_only", flush=True)
    publish(summary)


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, OSError, ValueError, json.JSONDecodeError,
            subprocess.TimeoutExpired) as e:
        print("INCONCLUSIVE:", str(e).split(":")[0], file=sys.stderr)
        print("No production files or original local checkout changed.",
              file=sys.stderr)
        raise SystemExit(1)
