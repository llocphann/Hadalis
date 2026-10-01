#!/usr/bin/env python3
"""Opt-in, permission-private, SOURCE-PINNED inert Wull geometry receipt.

Runs ONLY two inert standalone tests and two pure arithmetic summaries.
Publishes one redacted evidence JSON from the disposable dev clone itself.
It never starts Quickshell/Niri/Rust, sends pointer input, edits production,
touches the maintainer's existing worktree, or force-pushes Git.
"""
import datetime as dt
import json
import os
from pathlib import Path
import secrets
import stat
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
SAFE_REMOTES = {
    "https://github.com/llocphann/Hadalis",
    "https://github.com/llocphann/Hadalis.git",
    "git@github.com:llocphann/Hadalis",
    "git@github.com:llocphann/Hadalis.git",
    "ssh://git@github.com/llocphann/Hadalis",
    "ssh://git@github.com/llocphann/Hadalis.git",
}
REVIEWED = {
    "scripts/wull-silhouette-band-prototype.py":
        "34dfa1710be2c7c1d1a500d04a5fd53c9b4489a4",
    "scripts/test-wull-silhouette-band-prototype.py":
        "e7161aa49f6c17c9213d47f7cefd21cbecf5bd1f",
    "scripts/wull-motion-footprint-feasibility.py":
        "2e307ee23bf076c99d0b1b60f8230c3bc40182cb",
    "scripts/test-wull-motion-footprint-feasibility.py":
        "7669ae72c86a0b1d17cf5efb847b0474ebfddfb2",
    "modules/abyss/companion/WaterDropletBody.qml":
        "fc5b1c227026786ab553685bc170daff74e82517",
    "modules/abyss/companion/CompanionBridge.qml":
        "93c8d99497988f86660547773e8c30d90ac4bb66",
    "modules/abyss/companion/AbyssCompanion.qml":
        "b5b01835a282458eba0d0268396ae2c350d919d2",
    "modules/abyss/AbyssPerimeter.qml":
        "a3cd2a7bfbdf32dac2c7e42057a1dfaaeea214ac",
}
TESTS = (
    ("bezier", "scripts/test-wull-silhouette-band-prototype.py",
     "WULL_SILHOUETTE_BAND_INERT_FEASIBILITY_PASS"),
    ("motion", "scripts/test-wull-motion-footprint-feasibility.py",
     "WULL_MOTION_FOOTPRINT_INERT_COUNTEREXAMPLE_PASS"),
)
MODELS = (
    ("bezier", "scripts/wull-silhouette-band-prototype.py"),
    ("motion", "scripts/wull-motion-footprint-feasibility.py"),
)
BASE = "9e346dfa93d1622e31223f9e836de40dfad631f2"


def stop(reason):
    raise RuntimeError(reason)


def git(*args):
    done = subprocess.run(["git", *args], cwd=ROOT, capture_output=True,
                          text=True, timeout=60)
    if done.returncode:
        stop("inert_clone_git_step_failed_" + args[0])
    return done.stdout.strip()


def clean():
    return not git("status", "--porcelain=v1", "--untracked-files=all")


def private_clone(state):
    parent = ROOT.parent
    if (Path.cwd().resolve() != ROOT
            or git("symbolic-ref", "--short", "HEAD") != "dev"
            or not clean()
            or ROOT.name != "repo"
            or parent.parent.resolve() != (state / "hadalis").resolve()
            or not parent.name.startswith("wull-motion-inert.")
            or (stat.S_IMODE(parent.stat().st_mode) & 0o077) != 0):
        stop("private_clean_owned_dev_clone_required")
    origin = git("remote", "get-url", "origin")
    push = git("remote", "get-url", "--push", "--all", "origin").splitlines()
    if origin not in SAFE_REMOTES or len(push) != 1 or push[0] not in SAFE_REMOTES:
        stop("unexpected_owned_dev_origin")


def audit(sha):
    if subprocess.run(
            ["git", "merge-base", "--is-ancestor", BASE, sha],
            cwd=ROOT, capture_output=True, timeout=10).returncode:
        stop("reviewed_static_inert_baseline_not_ancestor")
    for path, blob in REVIEWED.items():
        if git("rev-parse", sha + ":" + path) != blob:
            stop("reviewed_static_or_motion_dependency_changed")


def checked_run(script, expected_line):
    cmd = subprocess.run([sys.executable, str(ROOT / script)],
                         cwd=ROOT, capture_output=True, text=True, timeout=40)
    if cmd.returncode or cmd.stdout.strip() != expected_line:
        stop("inert_contract_failed_" + Path(script).stem)


def checked_model(script):
    item = subprocess.run([sys.executable, str(ROOT / script)],
                          cwd=ROOT, capture_output=True, text=True, timeout=40)
    if item.returncode or len(item.stdout) > 4096:
        stop("inert_model_failed")
    try:
        return json.loads(item.stdout)
    except (ValueError, TypeError):
        stop("untrusted_inert_model_output")


def allow_report(bezier, motion, source, parent):
    if (not isinstance(bezier, dict) or not isinstance(motion, dict)
            or type(source) is not str or len(source) != 40
            or type(parent) is not str or len(parent) != 40):
        stop("untrusted_inert_report_arguments")
    if (bezier.get("kind")
            != "inert_static_source_pinned_wull_curve_band_feasibility"
            or bezier.get("production_changes") is not False
            or bezier.get("live_pointer_and_hover") != "not_run"
            or bezier.get("animation_halo_scale_qualification") != "not_run"
            or bezier.get("static_body_bbox_pixels") != 6992
            or type(bezier.get("conservative_interior_pixels")) is not int
            or not 2750 <= bezier["conservative_interior_pixels"] <= 3300
            or type(bezier.get("max_rectangles_per_edge")) is not int
            or not 30 <= bezier["max_rectangles_per_edge"] <= 64):
        stop("unreviewed_static_model_result")
    edges = bezier.get("rectangles_by_edge")
    if (not isinstance(edges, dict)
            or set(edges) != {"top", "bottom", "left", "right"}
            or any(type(v) is not int or v != bezier["max_rectangles_per_edge"]
                   for v in edges.values())):
        stop("unreviewed_four_edge_static_results")
    if (motion.get("mask_or_production_changed") is not False
            or motion.get("compositor_motion_hover_or_hit_accuracy") != "not_run"
            or motion.get("independently_bounded_spring_runtime_extrema") is not False
            or motion.get("qt_transform_order_and_mask_coordinates_verified") is not False
            or motion.get("body_bbox") != [76, 92]
            or motion.get("source_host_top") != [112, 98]
            or motion.get("source_host_side") != [98, 112]
            or motion.get("state_xscale_nominal") != [.925, 1.075]
            or motion.get("state_yscale_nominal") != [.905, 1.095]
            or motion.get("parent_config_scale") != [.65, 1.5]
            or motion.get("parent_scale_1_5_nominal_bbox_top") != [114, 138]
            or motion.get("parent_scale_1_5_nominal_bbox_side") != [138, 114]):
        stop("unreviewed_motion_source_budget")
    tip = motion.get("nominal_stretched_tip")
    if (not isinstance(tip, dict)
            or tip != {
                "y_scale": 1.06,
                "tip_y_relative_to_static_body": -3.4,
                "tip_y_relative_to_host": -.4,
                "private_bbox_top_relative_to_host": 3,
            }):
        stop("unreviewed_source_stretch_counterexample")
    # Whitelist output fields, NOT arbitrary model text, private paths,
    # screen coordinates, rendered images or host diagnostics.
    return {
        "kind": "wull_static_bezier_and_nominal_motion_inert_contract",
        "source_sha": source,
        "status": "pass",
        "scope": "exact_source_static_formula_only_no_desktop_or_pointer",
        "contracts": {"static_bezier": "pass", "nominal_motion": "pass"},
        "static_interior_area_pixels": bezier["conservative_interior_pixels"],
        "static_body_bbox_pixels": 6992,
        "static_rectangles_each_edge": bezier["max_rectangles_per_edge"],
        "nominal_stretch_tip_host_y": -.4,
        "nominal_stretch_tip_outside_static_body_bbox": True,
        "scale_1_5_nominal_top_body_bbox": [114, 138],
        "scale_1_5_nominal_side_body_bbox": [138, 114],
        "spring_and_qt_composition": "unqualified",
        "actual_animated_rust_frame": "not_run",
        "quickshell_compositor_pointer_hover": "not_run",
        "canonical_validation": "not_run",
        "production_mask_changed": False,
        "host_user_config_changed": False,
        "raw_coordinates_or_screenshots": "never_collected",
        "publication_parent_sha": parent,
    }


def fetch():
    git("fetch", "--quiet", "origin",
        "refs/heads/dev:refs/remotes/origin/dev")
    return git("rev-parse", "refs/remotes/origin/dev")


def publish(data, path):
    for attempt in range(4):
        if (not clean()
                or git("diff-tree", "--no-commit-id", "--name-only",
                       "-r", "HEAD") != str(path)):
            stop("not_exclusive_single_inert_evidence_commit")
        done = subprocess.run(
            ["git", "push", "origin", "HEAD:refs/heads/dev"],
            cwd=ROOT, capture_output=True, timeout=60)
        if done.returncode == 0:
            print("WULL_INERT_GEOMETRY_RESULT: pass", flush=True)
            print("REPORT_PUBLISHED:", path, flush=True)
            return
        if attempt == 3:
            stop("inert_receipt_push_refused_kept_private")
        old_parent = git("rev-parse", "HEAD^")
        remote = fetch()
        audit(remote)
        if subprocess.run(
                ["git", "merge-base", "--is-ancestor", old_parent, remote],
                cwd=ROOT, capture_output=True, timeout=10).returncode:
            stop("remote_diverged_private_inert_receipt_retained")
        # Rebase ONLY this one disposable-clone unpublished receipt commit.
        git("rebase", "--onto", remote, old_parent)
        if (not clean()
                or git("diff-tree", "--no-commit-id", "--name-only",
                       "-r", "HEAD") != str(path)):
            stop("inert_receipt_retry_contaminated")
        data["publication_parent_sha"] = git("rev-parse", "HEAD^")
        path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
        git("add", "--", str(path))
        if git("diff", "--cached", "--name-only") != str(path):
            stop("inert_receipt_retry_unreviewed_staging")
        git("commit", "--amend", "--no-edit")


def main():
    if sys.argv[1:] != ["--acknowledge-inert-motion-receipt"]:
        stop("explicit_inert_motion_opt_in_required")
    os.umask(0o077)
    state = Path(os.environ.get(
        "XDG_STATE_HOME", str(Path.home() / ".local/state"))).resolve()
    private_clone(state)
    remote = fetch()
    audit(remote)
    git("merge", "--ff-only", remote)
    source = git("rev-parse", "HEAD")
    if not clean():
        stop("private_clone_dirty_after_review")
    for _, script, expected in TESTS:
        checked_run(script, expected)
    models = {name: checked_model(script) for name, script in MODELS}
    if not clean() or git("rev-parse", "HEAD") != source:
        stop("inert_model_changed_checkout")
    remote = fetch()
    audit(remote)
    if subprocess.run(
            ["git", "merge-base", "--is-ancestor", source, remote],
            cwd=ROOT, capture_output=True, timeout=10).returncode:
        stop("remote_source_diverged_before_inert_publication")
    git("merge", "--ff-only", remote)
    parent = git("rev-parse", "HEAD")
    data = allow_report(models["bezier"], models["motion"], source, parent)
    name = ("wull-motion-inert-"
            + dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
            + "-" + secrets.token_hex(4) + "-" + source[:12] + ".json")
    path = Path("docs") / name
    if path.exists() or path.is_symlink():
        stop("inert_receipt_collision")
    path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    git("add", "--", str(path))
    if (git("diff", "--cached", "--name-only") != str(path)
            or git("diff", "--name-only")
            or git("ls-files", "--others", "--exclude-standard")):
        stop("inert_receipt_exclusivity_failed")
    git("commit", "-m",
        "test(wull): publish source-pinned inert curve and motion evidence",
        "--", str(path))
    publish(data, path)


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, ValueError, OSError, subprocess.TimeoutExpired) as e:
        print("STOP:", str(e).split(":")[0], file=sys.stderr)
        print("No live input or production change; private evidence retained.",
              file=sys.stderr)
        raise SystemExit(1)
