#!/usr/bin/env python3
"""Explicit OFFSCREEN actual-QML 4-edge x 3-scale x 2-pose geometry witness.

No live Wayland connection, Niri, Rust, input device, production shadow or
mask edit. Uses exact-source unmodified QML and a source-pinned private
ShellRoot fixture; animation disabled IN THE FIXTURE to inspect static and
stretch=1 Qt transforms only. Never qualifies true motion/hover/Wayland masks.
"""
import datetime as dt
import json
import math
import os
from pathlib import Path
import re
import secrets
import shutil
import signal
import stat
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
BASE = "07c81fef4217f634a8a8910a1903a7d9007c878a"
FIXTURE = "scripts/wull-fixtures/motion-geometry/shell.qml"
SAFE_REMOTES = {
    "https://github.com/llocphann/Hadalis",
    "https://github.com/llocphann/Hadalis.git",
    "git@github.com:llocphann/Hadalis",
    "git@github.com:llocphann/Hadalis.git",
    "ssh://git@github.com/llocphann/Hadalis",
    "ssh://git@github.com/llocphann/Hadalis.git",
}
PINNED = {
    FIXTURE: "548daff91ca9a1d7961bedd098fd314159cb520d",
    "modules/abyss/companion/WaterDropletBody.qml":
        "fc5b1c227026786ab553685bc170daff74e82517",
    "modules/abyss/companion/AbyssCompanion.qml":
        "b5b01835a282458eba0d0268396ae2c350d919d2",
    "modules/abyss/looks/AbyssStyle.qml":
        "4cc05dbaf547a3eff366647cb388abe8c31af5d5",
    "modules/common/Config.qml":
        "2bdf7d37f183b976d928fa15b0eb2ec57c646b60",
    "defaults/config.json": "e10d98c0f26d3e47c51cb8452bcd0d2cea735501",
    "modules/abyss/AbyssPerimeter.qml":
        "a3cd2a7bfbdf32dac2c7e42057a1dfaaeea214ac",
}
EDGES = ("top", "right", "bottom", "left")
SCALES = (.65, 1.0, 1.5)
PHASES = ("neutral", "stretch_target")
MARKER = "WULL_OFFSCREEN_MOTION_GEOMETRY "
MAX_LOG = 1048576


def stop(reason):
    raise RuntimeError(reason)


def git(*args):
    p = subprocess.run(["git", *args], cwd=ROOT, capture_output=True,
                       text=True, timeout=60)
    if p.returncode:
        stop("private_git_step_failed_" + args[0])
    return p.stdout.strip()


def clean():
    return not git("status", "--porcelain=v1", "--untracked-files=all")


def guard(state):
    scratch = ROOT.parent
    if (Path.cwd().resolve() != ROOT
            or ROOT.name != "repo"
            or scratch.parent.resolve() != (state / "hadalis").resolve()
            or not scratch.name.startswith("wull-qt-motion.")
            or scratch.is_symlink()
            or scratch.stat().st_uid != os.getuid()
            or stat.S_IMODE(scratch.stat().st_mode) & 0o077
            or git("symbolic-ref", "--short", "HEAD") != "dev"
            or not clean()):
        stop("clean_private_owned_dev_clone_required")
    origin = git("remote", "get-url", "origin")
    push = git("remote", "get-url", "--push", "--all", "origin").splitlines()
    if origin not in SAFE_REMOTES or len(push) != 1 or push[0] not in SAFE_REMOTES:
        stop("unexpected_owned_clone_remote")


def audit(commit):
    if subprocess.run(["git", "merge-base", "--is-ancestor", BASE, commit],
                      cwd=ROOT, capture_output=True, timeout=10).returncode:
        stop("fixture_base_not_ancestor")
    for path, blob in PINNED.items():
        if git("rev-parse", commit + ":" + path) != blob:
            stop("offscreen_motion_source_changed_after_review")


def fetch():
    git("fetch", "--quiet", "origin",
        "refs/heads/dev:refs/remotes/origin/dev")
    return git("rev-parse", "refs/remotes/origin/dev")


def model_summary(rows):
    """Allowlist ONLY booleans and fixed edge/scale categories to publish."""
    if not isinstance(rows, list) or len(rows) != 24:
        raise ValueError("unverified_qt_24_sample_count")
    expected = {(edge, scale, phase)
                for edge in EDGES for scale in SCALES for phase in PHASES}
    observed = set()
    flags = {}
    for row in rows:
        if not isinstance(row, dict) or row.get("valid") is not True:
            raise ValueError("invalid_offscreen_qt_pose")
        edge = row.get("edge")
        phase = row.get("phase")
        scale = row.get("requested_scale")
        if (edge not in EDGES or phase not in PHASES
                or type(scale) not in (int, float) or scale not in SCALES
                or (edge, scale, phase) in observed):
            raise ValueError("duplicate_or_unreviewed_qt_pose")
        observed.add((edge, scale, phase))
        names = ("host_width", "host_height", "stage_host_width",
                 "stage_host_height", "bbox_left", "bbox_right",
                 "bbox_top", "bbox_bottom", "tip_x", "tip_y")
        if any(type(row.get(name)) not in (int, float)
               or not math.isfinite(row[name])
               or abs(row[name]) > 10000 for name in names):
            raise ValueError("invalid_offscreen_qt_numbers")
        host_width, host_height = ((98, 112)
                                  if edge in ("left", "right") else
                                  (112, 98))
        if (abs(row["host_width"] - host_width) > .1
                or abs(row["host_height"] - host_height) > .1
                or abs(row["stage_host_width"] - host_width * scale) > .65
                or abs(row["stage_host_height"] - host_height * scale) > .65
                or row["bbox_right"] <= row["bbox_left"]
                or row["bbox_bottom"] <= row["bbox_top"]):
            raise ValueError("unverified_actual_qt_parent_scale_or_host")
        x, y = (3, 18) if edge in ("left", "right") else (18, 3)
        w, height = (92, 76) if edge in ("left", "right") else (76, 92)
        eps = .12
        reference = {
            "bbox_inside_host":
                row["bbox_left"] >= -eps and row["bbox_top"] >= -eps
                and row["bbox_right"] <= host_width + eps
                and row["bbox_bottom"] <= host_height + eps,
            "tip_inside_host":
                -eps <= row["tip_x"] <= host_width + eps
                and -eps <= row["tip_y"] <= host_height + eps,
            "bbox_inside_source_static":
                row["bbox_left"] >= x - eps
                and row["bbox_top"] >= y - eps
                and row["bbox_right"] <= x + w + eps
                and row["bbox_bottom"] <= y + height + eps,
            "tip_inside_source_static":
                x - eps <= row["tip_x"] <= x + w + eps
                and y - eps <= row["tip_y"] <= y + height + eps,
        }
        if any(type(row.get(key)) is not bool
               or row[key] is not predicted
               for key, predicted in reference.items()):
            raise ValueError("inconsistent_private_qt_boolean_witness")
        flags[(edge, scale, phase)] = reference
    if observed != expected:
        raise ValueError("missing_reviewed_qt_pose")
    # Previous real static-QML geometry found the neutral centered boxes.
    # If this disappears, record INCONCLUSIVE rather than interpret stretch.
    neutral_ok = all(
        flags[(edge, scale, "neutral")]["bbox_inside_source_static"]
        and flags[(edge, scale, "neutral")]["bbox_inside_host"]
        for edge in EDGES for scale in SCALES)
    by_scale = {}
    for scale in SCALES:
        key = str(scale)
        by_scale[key] = {
            "stretched_tip_outside_source_static_edges": [
                edge for edge in EDGES
                if not flags[(edge, scale, "stretch_target")][
                    "tip_inside_source_static"]],
            "stretched_bbox_outside_source_static_edges": [
                edge for edge in EDGES
                if not flags[(edge, scale, "stretch_target")][
                    "bbox_inside_source_static"]],
            "stretched_tip_outside_host_edges": [
                edge for edge in EDGES
                if not flags[(edge, scale, "stretch_target")][
                    "tip_inside_host"]],
            "stretched_bbox_outside_host_edges": [
                edge for edge in EDGES
                if not flags[(edge, scale, "stretch_target")][
                    "bbox_inside_host"]],
        }
    return {
        "status": "pass" if neutral_ok else "inconclusive",
        "reason": None if neutral_ok else "neutral_actual_qt_geometry_changed",
        "qt_24_poses_observed": True,
        "qt_parent_scale_mapping_consistent": True,
        "all_neutral_static_bbox_inside_host": neutral_ok,
        "per_scale_stretch_geometry": by_scale,
        # A frozen stretch=1 frame does not validate animation envelope.
        "real_backend_animation": "not_run",
        "wayland_region_pointer_hover": "not_run",
    }


def run_fixture(folder):
    qs = shutil.which("qs") or shutil.which("quickshell")
    dbus = shutil.which("dbus-run-session")
    if not qs or not dbus:
        stop("offscreen_qml_runtime_dependencies_missing")
    private = folder / "qml"
    private.mkdir(mode=0o700)
    shell = private / "shell"
    shell.mkdir()
    for item in ("modules", "services", "GlobalStates.qml", "qmldir",
                 "assets", "scripts", "defaults", "translations"):
        source = ROOT / item
        if not source.exists():
            stop("reviewed_shell_fixture_dependency_missing")
        (shell / item).symlink_to(source)
    shutil.copyfile(ROOT / FIXTURE, shell / "shell.qml")
    xdg = private / "xdg"
    for item in ("config", "data", "cache", "state"):
        (xdg / item).mkdir(parents=True)
    config = xdg / "config" / "illogical-impulse"
    config.mkdir()
    shutil.copyfile(ROOT / "defaults/config.json", config / "config.json")
    env = dict(os.environ)
    for variable in ("QS_CONFIG_PATH", "QS_CONFIG_NAME", "QS_MANIFEST",
                     "INIR_COMPANIOND", "WAYLAND_DISPLAY", "NIRI_SOCKET",
                     "DISPLAY"):
        env.pop(variable, None)
    env.update({
        "QT_QPA_PLATFORM": "offscreen",
        "XDG_CONFIG_HOME": str(xdg / "config"),
        "XDG_DATA_HOME": str(xdg / "data"),
        "XDG_CACHE_HOME": str(xdg / "cache"),
        "XDG_STATE_HOME": str(xdg / "state"),
        "QS_NO_RELOAD_POPUP": "1",
    })
    log = private / "offscreen.private.log"
    with log.open("wb") as output:
        proc = subprocess.Popen(
            [dbus, "--", qs, "--path", str(shell / "shell.qml")],
            env=env, cwd=ROOT, stdout=output, stderr=subprocess.STDOUT,
            stdin=subprocess.DEVNULL, start_new_session=True)
        try:
            code = proc.wait(timeout=22)
        except subprocess.TimeoutExpired:
            try:
                os.killpg(proc.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
            try:
                proc.wait(timeout=3)
            except subprocess.TimeoutExpired:
                if proc.poll() is None:
                    try:
                        os.killpg(proc.pid, signal.SIGKILL)
                    except ProcessLookupError:
                        pass
                proc.wait(timeout=3)
            stop("offscreen_qml_bounded_timeout")
    if not 0 < log.stat().st_size <= MAX_LOG:
        stop("offscreen_private_log_missing_or_oversized")
    text = log.read_text(encoding="utf-8", errors="replace")
    lines = [line.split(MARKER, 1)[1] for line in text.splitlines()
             if MARKER in line]
    if (code != 0 or "WULL_OFFSCREEN_MOTION_INVALID" in text
            or "WULL_OFFSCREEN_MOTION_TIMEOUT" in text
            or len(lines) != 1):
        stop("offscreen_qml_marker_or_load_inconclusive")
    try:
        return model_summary(json.loads(lines[0]))
    except (ValueError, TypeError, json.JSONDecodeError):
        stop("offscreen_qt_geometry_evidence_inconclusive")


def version_of(executable, *args):
    found = shutil.which(executable)
    if not found:
        return "not_recorded"
    try:
        proc = subprocess.run([found, *args], capture_output=True,
                              text=True, timeout=3)
        combined = proc.stdout + proc.stderr
        match = re.search(r"(?<!\d)(\d{1,2}\.\d{1,2}(?:\.\d{1,2})?)(?!\d)", combined)
        if proc.returncode == 0 and match:
            return match.group(1)
    except (OSError, subprocess.TimeoutExpired):
        pass
    return "not_recorded"


def public_report(proof, source, parent, qs_version, qt_version):
    if (type(proof) is not dict
            or proof.get("status") not in ("pass", "inconclusive")
            or proof.get("qt_24_poses_observed") is not True
            or proof.get("qt_parent_scale_mapping_consistent") is not True
            or proof.get("real_backend_animation") != "not_run"
            or proof.get("wayland_region_pointer_hover") != "not_run"
            or proof.get("all_neutral_static_bbox_inside_host")
                is not (proof.get("status") == "pass")
            or proof.get("reason") != (
                None if proof.get("status") == "pass"
                else "neutral_actual_qt_geometry_changed")
            or type(source) is not str
            or not re.fullmatch(r"[0-9a-f]{40}", source)
            or type(parent) is not str
            or not re.fullmatch(r"[0-9a-f]{40}", parent)):
        raise ValueError("unreviewed_offscreen_report_input")
    per = proof.get("per_scale_stretch_geometry")
    if (not isinstance(per, dict) or set(per) != {str(s) for s in SCALES}
            or any(type(record) is not dict
                   or set(record) != {
                       "stretched_tip_outside_source_static_edges",
                       "stretched_bbox_outside_source_static_edges",
                       "stretched_tip_outside_host_edges",
                       "stretched_bbox_outside_host_edges"}
                   or any(type(v) is not list or len(v) > len(EDGES)
                          or len(v) != len(set(v))
                          or any(edge not in EDGES for edge in v)
                          or v != [edge for edge in EDGES if edge in v]
                          for v in record.values())
                   for record in per.values())):
        raise ValueError("unreviewed_offscreen_qt_geometry_categories")
    if (type(qs_version) is not str or type(qt_version) is not str
            or any(not re.fullmatch(
                r"\d{1,2}\.\d{1,2}(?:\.\d{1,2})?|not_recorded", v)
                for v in (qs_version, qt_version))):
        raise ValueError("unsafe_version_metadata")
    return {
        "kind": "wull_actual_offscreen_qt_stretch_geometry",
        "source_sha": source,
        "status": proof["status"],
        "reason": proof.get("reason"),
        "scope": "unmodified_actual_qml_private_offscreen_four_edges_three_scales_two_frozen_poses",
        "observed_pose_count": 24,
        "qt_parent_scale_mapping_consistent": True,
        "all_neutral_static_bbox_inside_host": proof[
            "all_neutral_static_bbox_inside_host"],
        "stretch_target_observations": per,
        "local_quickshell_version": qs_version,
        "local_qt_version": qt_version,
        "source_arithmetic_not_frame_replayed": True,
        "real_backend_animation": "not_run",
        "wayland_region_pointer_hover": "not_run",
        "virtual_pointer_backend": "not_run",
        "canonical_validation": "not_run",
        "production_mask_changed": False,
        "host_user_config_changed": False,
        "raw_local_qt_coordinates_logs": "private_local_only",
        "publication_parent_sha": parent,
    }


def publish(data, path):
    for attempt in range(4):
        if (not clean()
                or git("diff-tree", "--no-commit-id", "--name-only",
                       "-r", "HEAD") != str(path)):
            stop("not_single_offscreen_receipt_commit")
        pushed = subprocess.run(
            ["git", "push", "origin", "HEAD:refs/heads/dev"], cwd=ROOT,
            capture_output=True, timeout=60)
        if pushed.returncode == 0:
            print("WULL_QT_OFFSCREEN_GEOMETRY_RESULT:", data["status"], flush=True)
            print("REPORT_PUBLISHED:", str(path), flush=True)
            return
        if attempt == 3:
            stop("private_offscreen_receipt_push_refused")
        previous = git("rev-parse", "HEAD^")
        remote = fetch()
        audit(remote)
        if subprocess.run(
                ["git", "merge-base", "--is-ancestor", previous, remote],
                cwd=ROOT, capture_output=True, timeout=10).returncode:
            stop("remote_diverged_offscreen_private_receipt_kept")
        git("rebase", "--onto", remote, previous)
        if (not clean()
                or git("diff-tree", "--no-commit-id", "--name-only",
                       "-r", "HEAD") != str(path)):
            stop("offscreen_receipt_replay_contaminated")
        data["publication_parent_sha"] = git("rev-parse", "HEAD^")
        path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
        git("add", "--", str(path))
        if git("diff", "--cached", "--name-only") != str(path):
            stop("offscreen_receipt_replay_unreviewed_staging")
        git("commit", "--amend", "--no-edit")


def main():
    if sys.argv[1:] != ["--acknowledge-private-offscreen-qt-motion"]:
        stop("explicit_offscreen_qt_opt_in_required")
    os.umask(0o077)
    state = Path(os.environ.get(
        "XDG_STATE_HOME", str(Path.home() / ".local/state"))).expanduser().resolve()
    guard(state)
    source = fetch()
    audit(source)
    git("merge", "--ff-only", source)
    if not clean():
        stop("private_clone_dirty_before_qt_probe")
    proof = run_fixture(ROOT.parent)
    if not clean() or git("rev-parse", "HEAD") != source:
        stop("source_changed_while_running_offscreen")
    remote = fetch()
    audit(remote)
    if subprocess.run(
            ["git", "merge-base", "--is-ancestor", source, remote],
            cwd=ROOT, capture_output=True, timeout=10).returncode:
        stop("remote_diverged_after_offscreen_probe")
    git("merge", "--ff-only", remote)
    parent = git("rev-parse", "HEAD")
    data = public_report(
        proof, source, parent,
        version_of("qs" if shutil.which("qs") else "quickshell", "--version"),
        version_of("qtpaths6", "--qt-version"))
    name = ("wull-qt-motion-"
            + dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
            + "-" + secrets.token_hex(4) + "-" + source[:12] + ".json")
    path = Path("docs") / name
    if path.exists() or path.is_symlink():
        stop("offscreen_receipt_name_collision")
    path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    git("add", "--", str(path))
    if (git("diff", "--cached", "--name-only") != str(path)
            or git("diff", "--name-only")
            or git("ls-files", "--others", "--exclude-standard")):
        stop("offscreen_receipt_exclusivity_unproven")
    git("commit", "-m",
        "test(wull): publish exact-source private offscreen Qt motion geometry",
        "--", str(path))
    publish(data, path)


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, ValueError, subprocess.TimeoutExpired) as ex:
        print("STOP:", str(ex).split(":")[0], file=sys.stderr)
        print("No live compositor, pointer input or production edit.",
              file=sys.stderr)
        raise SystemExit(1)
