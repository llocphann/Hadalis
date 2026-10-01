#!/usr/bin/env python3
"""EXPLICIT, input-free publication of ONE existing LEFT margin drift finding.

Run from a clean, owned, permission-private temporary dev clone under the
user's XDG state. No original checkout merge/rebase, pointer input, Niri or
Rust invocation. Strict enum-only report, source-pinned retrospective.
"""
import json
import os
from pathlib import Path
import runpy
import stat
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
REPORT = "docs/wull-mask-left-20261001T175020Z-5a11aa42-5b72e0e3294c.json"
REPORT_BLOB = "6abfcef1fae0d360dad5a55ddf46351b87634507"
REPORT_SOURCE = "5b72e0e3294c32276c306b3c6911fd9fa4e79fb1"
DIAG = "scripts/wull-private-left-margin-diagnostic.py"
DIAG_BLOB = "b0c34ea4abd2977ddd3b5568e38050e1b1e40308"
ORIGINAL_CHILD_BLOB = "c099fc6a1a62b06218d69dd3ec526df18de701db"
ORIGINAL_TARGETS_BLOB = "527ebecd01e2fc51d497e0de73a0f3bcd83305ac"
DEST = "docs/wull-pointer-left-margin-drift-20261001T175020Z-5a11aa42-5b72e0e3294c.json"
SAFE_REMOTES = {
    "https://github.com/llocphann/Hadalis",
    "https://github.com/llocphann/Hadalis.git",
    "git@github.com:llocphann/Hadalis",
    "git@github.com:llocphann/Hadalis.git",
    "ssh://git@github.com/llocphann/Hadalis",
    "ssh://git@github.com/llocphann/Hadalis.git",
}
CHOICES = {
    "relative_offset_bucket": {
        "within_prior_witness_uncertainty", "eight_to_twenty_three",
        "twenty_four_to_ninety_five", "ninety_six_or_more"},
    "relative_axes": {
        "within_prior_witness_uncertainty", "horizontal", "vertical", "both"},
    "horizontal_direction": {"positive", "negative", "within_uncertainty"},
    "vertical_direction": {"positive", "negative", "within_uncertainty"},
    "measurement_basis": {"same_left_body_x_and_relative_y_minus_47"},
    "interpretation": {"retrospective_witness_relative_not_cause"},
}
BOOLEANS = {
    "near_previous_disabled_body_position",
    "near_previous_candidate_exterior_position",
}


def stop(code):
    raise RuntimeError(code)


def git(*args):
    proc = subprocess.run(
        ["git", *args], cwd=ROOT, capture_output=True, text=True,
        timeout=50)
    if proc.returncode:
        stop("private_clone_git_" + args[0] + "_failed")
    return proc.stdout.strip()


def clean():
    return not git("status", "--porcelain=v1", "--untracked-files=all")


def guard_private_clone(state):
    if (Path.cwd().resolve() != ROOT
            or git("symbolic-ref", "--short", "HEAD") != "dev"
            or not clean()
            or ROOT.name != "repo"
            or ROOT.parent.parent.resolve() != (state / "hadalis").resolve()
            or not ROOT.parent.name.startswith("wull-left-drift-publish.")
            or stat.S_IMODE(ROOT.parent.stat().st_mode) & 0o077):
        stop("owned_clean_temporary_dev_clone_required")
    origin = git("remote", "get-url", "origin")
    push = git("remote", "get-url", "--push", "--all", "origin").splitlines()
    if origin not in SAFE_REMOTES or len(push) != 1 or push[0] not in SAFE_REMOTES:
        stop("unexpected_private_clone_remote")


def audit(revision):
    if git("rev-parse", revision + ":" + DIAG) != DIAG_BLOB:
        stop("reviewed_left_diagnostic_blob_changed")
    if git("rev-parse", revision + ":" + REPORT) != REPORT_BLOB:
        stop("original_sanitized_left_report_changed")
    if git("rev-parse", REPORT_SOURCE + ":scripts/wull-manual-pointer-child.py"
           ) != ORIGINAL_CHILD_BLOB:
        stop("original_left_child_source_unverified")
    if git("rev-parse", REPORT_SOURCE + ":scripts/wull-pointer-targets.py"
           ) != ORIGINAL_TARGETS_BLOB:
        stop("original_left_geometry_source_unverified")
    if subprocess.run(
            ["git", "merge-base", "--is-ancestor", REPORT_SOURCE, revision],
            cwd=ROOT, capture_output=True, timeout=10).returncode:
        stop("original_left_run_not_ancestor_of_dev")


def public_payload(found, source, parent):
    if (set(found) != set(CHOICES) | BOOLEANS
            or any(found[key] not in allowed
                   for key, allowed in CHOICES.items())
            or any(type(found[key]) is not bool for key in BOOLEANS)
            or not isinstance(source, str) or len(source) != 40
            or not isinstance(parent, str) or len(parent) != 40):
        stop("unsafe_or_unreviewed_left_public_classification")
    return {
        "kind": "wull_retrospective_left_margin_pointer_drift",
        "source_sha": source,
        "original_source_sha": REPORT_SOURCE,
        "original_sanitized_report": REPORT,
        "status": "categorized_from_private_prior_log",
        "diagnostic": dict(found),
        "input_backend_of_original_run": "forced_wlr_protocols_wdotool",
        "raw_pointer_coordinates": "private_local_only",
        "new_pointer_input": False,
        "real_niri_retest": "not_run",
        "production_mask_changed": False,
        "host_user_config_changed": False,
        "publication_parent_sha": parent,
    }


def publish(summary):
    path = Path(DEST)
    if path.exists() or path.is_symlink():
        stop("existing_left_drift_receipt_not_overwritten")
    path.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    git("add", "--", DEST)
    if git("diff", "--cached", "--name-only") != DEST:
        stop("unreviewed_path_staged")
    git("commit", "-m", "test(wull): publish redacted retrospective left margin witness",
        "--", DEST)
    for attempt in range(4):
        if (not clean() or
                git("diff-tree", "--no-commit-id", "--name-only",
                    "-r", "HEAD") != DEST):
            stop("unreviewed_unpublished_left_report_commit")
        pushed = subprocess.run(
            ["git", "push", "origin", "HEAD:refs/heads/dev"],
            cwd=ROOT, capture_output=True, timeout=60)
        if pushed.returncode == 0:
            print("WULL_LEFT_PRIVATE_DIAGNOSIS_PUBLISHED: " + DEST)
            return
        if attempt == 3:
            stop("private_only_left_report_push_refused")
        old_parent = git("rev-parse", "HEAD^")
        git("fetch", "--quiet", "origin",
            "refs/heads/dev:refs/remotes/origin/dev")
        newer = git("rev-parse", "refs/remotes/origin/dev")
        audit(newer)
        if subprocess.run(
                ["git", "merge-base", "--is-ancestor", old_parent, newer],
                cwd=ROOT, capture_output=True, timeout=10).returncode:
            stop("remote_history_diverged_private_report_kept")
        git("rebase", "--onto", newer, old_parent)
        if (not clean() or
                git("diff-tree", "--no-commit-id", "--name-only",
                    "-r", "HEAD") != DEST):
            stop("nonexclusive_private_report_replay_blocked")
        summary["publication_parent_sha"] = git("rev-parse", "HEAD^")
        path.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
        git("add", "--", DEST)
        if git("diff", "--cached", "--name-only") != DEST:
            stop("nonexclusive_replay_staging")
        git("commit", "--amend", "--no-edit")


def main():
    if sys.argv[1:] != ["--publish-existing-left-margin-off-target"]:
        stop("explicit_existing_left_margin_publication_required")
    os.umask(0o077)
    state = Path(os.environ.get(
        "XDG_STATE_HOME", str(Path.home() / ".local/state"))).expanduser().resolve()
    guard_private_clone(state)
    git("fetch", "--quiet", "origin",
        "refs/heads/dev:refs/remotes/origin/dev")
    remote = git("rev-parse", "refs/remotes/origin/dev")
    audit(remote)
    git("merge", "--ff-only", remote)
    if not clean():
        stop("private_clone_dirty_after_sync")
    exact_report = ROOT / REPORT
    if (exact_report.is_symlink() or not exact_report.is_file()
            or not 0 < exact_report.stat().st_size <= 65536):
        stop("unverified_old_left_public_report")
    diag = runpy.run_path(str(ROOT / DIAG),
                          run_name="wull_left_retrospective_read_only")
    diag["validate_report"](
        json.loads(exact_report.read_text(encoding="utf-8")),
        exact_report.name)
    found = diag["categorize"](
        diag["parse_clicks"](diag["private_log"](state)))
    # Re-verify current source and old source pins before publishing.
    git("fetch", "--quiet", "origin",
        "refs/heads/dev:refs/remotes/origin/dev")
    later = git("rev-parse", "refs/remotes/origin/dev")
    audit(later)
    git("merge", "--ff-only", later)
    if not clean():
        stop("private_clone_dirty_before_report")
    summary = public_payload(found, git("rev-parse", "HEAD"),
                             git("rev-parse", "HEAD"))
    print("WULL_LEFT_RETROSPECTIVE_CLASSIFIED")
    print("RELATIVE_OFFSET_BUCKET: " + found["relative_offset_bucket"])
    print("RELATIVE_AXES: " + found["relative_axes"])
    print("NO_INPUT_INJECTED_NO_PRIVATE_COORDINATES_EXPORTED")
    publish(summary)


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, OSError, ValueError, json.JSONDecodeError,
            subprocess.TimeoutExpired) as exc:
        print("INCONCLUSIVE:", str(exc).split(":")[0], file=sys.stderr)
        print("Original local checkout, private log and production untouched.",
              file=sys.stderr)
        raise SystemExit(1)
