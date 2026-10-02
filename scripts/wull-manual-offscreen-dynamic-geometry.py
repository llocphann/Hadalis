#!/usr/bin/env python3
"""Explicit, bounded PRIVATE offscreen actual-QML sampled animation geometry.

Qualifies only OBSERVED Qt frames during authored neutral/stretch/release
transitions. Not a mathematically complete animation envelope, native Rust
trace, Wayland pointer test or production input-mask acceptance.
"""
import datetime as dt
import json
import resource
import os
from pathlib import Path
import re
import runpy
import secrets
import shutil
import signal
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
FROZEN_RUNNER = "scripts/wull-manual-offscreen-motion-geometry.py"
DYNAMIC_FIXTURE = "scripts/wull-fixtures/motion-envelope/shell.qml"
FROZEN_RECEIPT = (
    "docs/wull-qt-motion-20261001T185752Z-53e5c5cc-72ac0580b12e.json")
DYNAMIC_PINS = {
    DYNAMIC_FIXTURE: "6e3b5402d32d263868c1ec688925adba0fd7250b",
    FROZEN_RUNNER: "0dd833ed05d54e9d1045553a1da8be8f66b6511a",
    FROZEN_RECEIPT: "dc2f36b525ef7e412869f155153dc4e48720f898",
}
EDGES = ("top", "right", "bottom", "left")
SCALES = (0.65, 1.0, 1.5)
FLAGS = ("bbox_outside_static", "bbox_outside_host",
         "tip_outside_static", "tip_outside_host")
PHASE_FLAGS = ("samples", "active", "stretch_witness",
               "transition_witness", "target_reached_witness",
               "mapped_frame_change_witness", "bob_witness",
               "sway_witness", *FLAGS, "bbox_beyond_frozen")
MARKER = "WULL_OFFSCREEN_DYNAMIC_GEOMETRY "
STAGE_MARKER = "WULL_OFFSCREEN_DYNAMIC_STAGE="
EXPECTED_STAGES = (
    "BOOT", "SETUP_START", "FROZEN_VERIFIED", "NEUTRAL_VERIFIED",
    "STRETCH_SAMPLE", "RELEASE_START", "RELEASE_SAMPLE", "SAMPLING_DONE",
)
MAX_LOG = 524288  # Dedicated stdout/stderr evidence bound, NOT an inherited QS file cap.
QS_CHILD_FILE_LIMIT = 8 * 1024 * 1024  # Exact isolated SIGXFSZ control succeeded at this cap.
frozen = runpy.run_path(str(ROOT / FROZEN_RUNNER),
                        run_name="wull_dynamic_borrow_reviewed_safety")
git = frozen["git"]
clean = frozen["clean"]
fetch = frozen["fetch"]
stop = frozen["stop"]


def audit(commit):
    # The earlier 24-pose baseline's original QML source pins remain mandatory.
    frozen["audit"](commit)
    for path, blob in DYNAMIC_PINS.items():
        if git("rev-parse", commit + ":" + path) != blob:
            stop("offscreen_dynamic_source_changed_after_review")


def known_frozen():
    raw = (ROOT / FROZEN_RECEIPT).read_text(encoding="utf-8")
    data = json.loads(raw)
    if (data.get("source_sha") !=
            "72ac0580b12e08c88e74f69ac919e30a93f481f4"
            or data.get("status") != "pass"
            or data.get("observed_pose_count") != 24
            or data.get("local_quickshell_version") != "0.3.1"
            or data.get("production_mask_changed") is not False):
        raise ValueError("unqualified_frozen_reference")
    expected = data["stretch_target_observations"]
    if set(expected) != {str(s) for s in SCALES}:
        raise ValueError("incomplete_frozen_scale_reference")
    return expected


def is_canonical_edges(values):
    return (type(values) is list
            and values == [edge for edge in EDGES if edge in values])


def model_summary(rows, frozen_flags):
    """Parse only allowlisted categorical evidence from 12 real-QML hosts."""
    if type(rows) is not list or len(rows) != 12:
        raise ValueError("invalid_dynamic_host_count")
    if type(frozen_flags) is not dict:
        raise ValueError("unreviewed_frozen_reference")
    expected = {(edge, scale) for edge in EDGES for scale in SCALES}
    seen = set()
    categories = {str(s): {
        "stretch_bbox_outside_host_edges": [],
        "stretch_tip_outside_host_edges": [],
        "stretch_bbox_beyond_frozen_edges": [],
        "release_bbox_outside_host_edges": [],
        "release_tip_outside_host_edges": [],
        "release_bbox_beyond_frozen_edges": [],
    } for s in SCALES}
    missing = {str(s): [] for s in SCALES}
    samples_min = 1000
    samples_max = 0
    for row in rows:
        if (type(row) is not dict or set(row) != {
                "edge", "requested_scale", "neutral_verified",
                "frozen", "stretch", "release"}):
            raise ValueError("unreviewed_dynamic_host_fields")
        edge, scale = row["edge"], row["requested_scale"]
        if (edge not in EDGES or type(scale) not in (int, float)
                or scale not in SCALES or (edge, scale) in seen):
            raise ValueError("duplicate_or_unreviewed_dynamic_host")
        seen.add((edge, scale))
        if type(row["neutral_verified"]) is not bool:
            raise ValueError("fabricated_neutral_witness")
        f = row["frozen"]
        if (type(f) is not dict or set(f) != set(FLAGS)
                or any(type(f[k]) is not bool for k in FLAGS)):
            raise ValueError("unreviewed_frozen_flags")
        # JS JSON.stringify(1.0) emits 1; use the validated canonical scale
        # for frozen-reference and summary keys, never the JSON number spelling.
        scale_key = str(next(s for s in SCALES if s == scale))
        reference = frozen_flags.get(scale_key)
        if type(reference) is not dict:
            raise ValueError("missing_scale_frozen_reference")
        expected_frozen = {
            "bbox_outside_static":
                edge in reference["stretched_bbox_outside_source_static_edges"],
            "bbox_outside_host":
                edge in reference["stretched_bbox_outside_host_edges"],
            "tip_outside_static":
                edge in reference["stretched_tip_outside_source_static_edges"],
            "tip_outside_host":
                edge in reference["stretched_tip_outside_host_edges"],
        }
        if not is_canonical_edges(
                reference["stretched_bbox_outside_source_static_edges"]):
            raise ValueError("invalid_frozen_edge_reference")
        if not is_canonical_edges(
                reference["stretched_bbox_outside_host_edges"]):
            raise ValueError("invalid_frozen_edge_reference")
        if not is_canonical_edges(
                reference["stretched_tip_outside_source_static_edges"]):
            raise ValueError("invalid_frozen_edge_reference")
        if not is_canonical_edges(
                reference["stretched_tip_outside_host_edges"]):
            raise ValueError("invalid_frozen_edge_reference")

        if row["neutral_verified"] is False:
            missing[scale_key].append(edge)
        if f != expected_frozen:
            missing[scale_key].append(edge)

        for phase in ("stretch", "release"):
            value = row[phase]
            if type(value) is not dict or set(value) != set(PHASE_FLAGS):
                raise ValueError("unreviewed_dynamic_phase_fields")
            count = value["samples"]
            if type(count) is not int or not 0 <= count <= 250:
                raise ValueError("invalid_dynamic_frame_count")
            samples_min = min(samples_min, count)
            samples_max = max(samples_max, count)
            if any(type(value[key]) is not bool
                   for key in PHASE_FLAGS if key != "samples"):
                raise ValueError("fabricated_dynamic_boolean_witness")
            if (count < 10 or not value["active"]
                    or not value["stretch_witness"]
                    or not value["transition_witness"]
                    or not value["target_reached_witness"]
                    or not value["mapped_frame_change_witness"]
                    or not value["bob_witness"]
                    or not value["sway_witness"]):
                missing[scale_key].append(edge)
            prefix = phase + "_"
            for flag, label in (
                    ("bbox_outside_host", "bbox_outside_host_edges"),
                    ("tip_outside_host", "tip_outside_host_edges"),
                    ("bbox_beyond_frozen", "bbox_beyond_frozen_edges")):
                if value[flag]:
                    categories[scale_key][prefix + label].append(edge)
    if seen != expected:
        raise ValueError("missing_dynamic_edge_scale")
    for key in missing:
        missing[key] = [edge for edge in EDGES if edge in missing[key]]
    # Lack of observed spring/autonomous witnesses is INCONCLUSIVE, not PASS.
    all_witnesses = not any(missing.values())
    return {
        "status": "pass" if all_witnesses else "inconclusive",
        "reason": None if all_witnesses else "dynamic_frame_or_frozen_witness_missing",
        "observed_host_cases": 12,
        "all_dynamic_state_witnesses": all_witnesses,
        "sample_count_range_per_case_phase": [samples_min, samples_max],
        "unqualified_edges_by_scale": missing,
        "sampled_categories": categories,
        "global_spring_extrema_proven": False,
        "native_backend_traces": "not_run",
        "wayland_pointer_hover": "not_run",
    }


def public_report(proof, source, parent, qs_version, qt_version):
    if (type(proof) is not dict or set(proof) != {
            "status", "reason", "observed_host_cases",
            "all_dynamic_state_witnesses",
            "sample_count_range_per_case_phase",
            "unqualified_edges_by_scale", "sampled_categories",
            "global_spring_extrema_proven",
            "native_backend_traces", "wayland_pointer_hover"}
            or proof["status"] not in ("pass", "inconclusive")
            or proof["reason"] != (
                None if proof["status"] == "pass"
                else "dynamic_frame_or_frozen_witness_missing")
            or proof["all_dynamic_state_witnesses"] is not (
                proof["status"] == "pass")
            or proof["observed_host_cases"] != 12
            or proof["global_spring_extrema_proven"] is not False
            or proof["native_backend_traces"] != "not_run"
            or proof["wayland_pointer_hover"] != "not_run"
            or type(source) is not str
            or not re.fullmatch(r"[0-9a-f]{40}", source)
            or type(parent) is not str
            or not re.fullmatch(r"[0-9a-f]{40}", parent)):
        raise ValueError("unsafe_dynamic_public_proof")
    low_high = proof["sample_count_range_per_case_phase"]
    if (type(low_high) is not list or len(low_high) != 2
            or any(type(n) is not int or not 0 <= n <= 250 for n in low_high)
            or low_high[0] > low_high[1]):
        raise ValueError("invalid_dynamic_public_sample_count")
    categories = proof["sampled_categories"]
    missing = proof["unqualified_edges_by_scale"]
    if (type(categories) is not dict or type(missing) is not dict
            or set(categories) != {str(s) for s in SCALES}
            or set(missing) != set(categories)):
        raise ValueError("invalid_dynamic_public_categories")
    keys = {phase + "_" + suffix for phase in ("stretch", "release")
            for suffix in ("bbox_outside_host_edges",
                           "tip_outside_host_edges",
                           "bbox_beyond_frozen_edges")}
    for scale in categories:
        if (type(categories[scale]) is not dict
                or set(categories[scale]) != keys
                or any(not is_canonical_edges(v)
                       for v in categories[scale].values())
                or not is_canonical_edges(missing[scale])):
            raise ValueError("unreviewed_dynamic_category_values")
    if (proof["status"] == "pass" and (
            any(missing.values()) or low_high[0] < 10)):
        raise ValueError("dynamic_pass_without_complete_witness")
    if (type(qs_version) is not str or type(qt_version) is not str
            or any(not re.fullmatch(
                r"\d{1,2}\.\d{1,2}(?:\.\d{1,2})?|not_recorded", v)
                for v in (qs_version, qt_version))):
        raise ValueError("unsafe_dynamic_runtime_metadata")
    return {
        "kind": "wull_private_sampled_actual_qml_dynamic_geometry",
        "source_sha": source,
        "status": proof["status"],
        "reason": proof["reason"],
        "scope": "original_qml_private_offscreen_12_hosts_controlled_stretch_release_sampled_frames",
        "previous_frozen_reference_source_sha":
            "72ac0580b12e08c88e74f69ac919e30a93f481f4",
        "all_12_edge_scale_state_witnesses":
            proof["all_dynamic_state_witnesses"],
        "sample_count_range_per_case_phase": low_high,
        "unqualified_edges_by_scale": missing,
        "sampled_categories": categories,
        "local_quickshell_version": qs_version,
        "local_qt_version": qt_version,
        "global_spring_extrema_proven": False,
        "native_backend_traces": "not_run",
        "wayland_pointer_hover": "not_run",
        "production_mask_changed": False,
        "host_user_config_changed": False,
        "canonical_validation": "not_run",
        "private_coordinates_animation_values_and_logs": "local_only",
        "publication_parent_sha": parent,
    }


def categorize_private_qml_failure(raw, code, marker_count):
    """Return ONLY controlled diagnostic labels, never private QML log text."""
    if "WULL_OFFSCREEN_DYNAMIC_INVALID" in raw:
        return "FIXTURE_INVALID"
    if "WULL_OFFSCREEN_DYNAMIC_TIMEOUT" in raw:
        return "FIXTURE_TIMEOUT"
    if re.search(r'(?im)\b(?:module [^\n]* is not installed|module [^\n]* not found)\b', raw):
        return "QML_IMPORT_FAILURE"
    if re.search(r'(?i)\b(?:ReferenceError|TypeError|SyntaxError)\s*:', raw):
        return "QML_SCRIPT_ERROR"
    if re.search(r'(?i)\b(?:Cannot assign|Unable to assign|Failed to load component|is not a type)\b', raw):
        return "QML_COMPONENT_ERROR"
    if "Could not load the Qt platform plugin" in raw:
        return "QT_PLATFORM_FAILURE"
    if code != 0:
        return "PRIVATE_QS_NONZERO_EXIT"
    if marker_count == 0:
        return "MISSING_GEOMETRY_MARKER"
    if marker_count > 1:
        return "DUPLICATE_GEOMETRY_MARKERS"
    return "UNKNOWN_PRIVATE_MARKER_FAILURE"


def private_stage_summary(raw):
    """Never return raw log lines; fail closed on unexpected stage markers."""
    stages = []
    for line in raw.splitlines():
        if STAGE_MARKER not in line:
            continue
        token = line.split(STAGE_MARKER, 1)[1].strip()
        if token not in EXPECTED_STAGES or token in stages or len(stages) >= len(EXPECTED_STAGES):
            return None
        stages.append(token)
    return stages


def private_exit_class(code):
    """Classify a process return code without disclosing private log text."""
    if type(code) is not int:
        return "NOT_RECORDED"
    if code < 0:
        return "SIGNAL"
    if code > 0:
        return "NONZERO"
    return "ZERO"


def limit_private_process_files():
    # RLIMIT_FSIZE is inherited by dbus-run-session AND Quickshell: it
    # limits *all* QS private regular-file writes (including internal
    # qslogs), not just captured stdout. The maintainer observed
    # SIGXFSZ with 512 KiB and an actual minimal QML PASS at 8 MiB.
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    resource.setrlimit(resource.RLIMIT_FSIZE,
                       (QS_CHILD_FILE_LIMIT, QS_CHILD_FILE_LIMIT))


def run_fixture(folder):
    qs = shutil.which("qs") or shutil.which("quickshell")
    dbus = shutil.which("dbus-run-session")
    if not qs or not dbus:
        stop("private_offscreen_dynamic_dependencies_missing")
    private = folder / "dynamic-qml"
    private.mkdir(mode=0o700)
    shell = private / "shell"
    shell.mkdir()
    for name in ("modules", "services", "GlobalStates.qml", "qmldir",
                 "assets", "scripts", "defaults", "translations"):
        source = ROOT / name
        if not source.exists():
            stop("reviewed_offscreen_dynamic_dependency_missing")
        (shell / name).symlink_to(source)
    shutil.copyfile(ROOT / DYNAMIC_FIXTURE, shell / "shell.qml")
    xdg = private / "xdg"
    for name in ("config", "data", "cache", "state"):
        (xdg / name).mkdir(parents=True)
    config = xdg / "config" / "illogical-impulse"
    config.mkdir()
    shutil.copyfile(ROOT / "defaults/config.json", config / "config.json")
    env = dict(os.environ)
    for name in ("QS_CONFIG_PATH", "QS_CONFIG_NAME", "QS_MANIFEST",
                 "INIR_COMPANIOND", "WAYLAND_DISPLAY", "NIRI_SOCKET",
                 "DISPLAY", "QML_IMPORT_PATH", "QML2_IMPORT_PATH"):
        env.pop(name, None)
    env.update({
        "QT_QPA_PLATFORM": "offscreen",
        "XDG_CONFIG_HOME": str(xdg / "config"),
        "XDG_DATA_HOME": str(xdg / "data"),
        "XDG_CACHE_HOME": str(xdg / "cache"),
        "XDG_STATE_HOME": str(xdg / "state"),
        "QS_NO_RELOAD_POPUP": "1",
    })
    log = private / "dynamic.private.log"
    code = -1
    with log.open("wb") as output:
        proc = subprocess.Popen(
            [dbus, "--", qs, "--path", str(shell / "shell.qml")],
            env=env, cwd=ROOT, stdout=output, stderr=subprocess.STDOUT,
            stdin=subprocess.DEVNULL, start_new_session=True,
            preexec_fn=limit_private_process_files)
        try:
            code = proc.wait(timeout=23)
        except subprocess.TimeoutExpired:
            stop("bounded_offscreen_dynamic_timeout")
        finally:
            # dbus-run-session can exit while children still live. Always
            # drain ONLY our newly-created private process group.
            try:
                os.killpg(proc.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
            try:
                proc.wait(timeout=3)
            except subprocess.TimeoutExpired:
                try:
                    os.killpg(proc.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                proc.wait(timeout=3)
            time.sleep(0.20)
            try:
                os.killpg(proc.pid, 0)
            except ProcessLookupError:
                pass
            else:
                try:
                    os.killpg(proc.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                time.sleep(0.10)
                try:
                    os.killpg(proc.pid, 0)
                except ProcessLookupError:
                    pass
                else:
                    stop("private_dynamic_child_cleanup_unverified")
    if not 0 < log.stat().st_size <= MAX_LOG:
        stop("private_dynamic_log_missing_or_oversized")
    raw = log.read_text(encoding="utf-8", errors="replace")
    lines = [line.split(MARKER, 1)[1] for line in raw.splitlines()
             if MARKER in line]
    stages = private_stage_summary(raw)
    print("PRIVATE_QS_EXIT_CLASS=" + private_exit_class(code), flush=True)
    print("PRIVATE_QML_STAGES=" + str(0 if stages is None else len(stages)), flush=True)
    print("PRIVATE_QML_LAST_STAGE=" + (
        "INVALID_SEQUENCE" if stages is None else
        stages[-1] if stages else "NO_BOOT"), flush=True)
    if (code != 0 or "WULL_OFFSCREEN_DYNAMIC_INVALID" in raw
            or "WULL_OFFSCREEN_DYNAMIC_TIMEOUT" in raw or len(lines) != 1):
        print("PRIVATE_QML_FAILURE_CATEGORY="
              + categorize_private_qml_failure(raw, code, len(lines)),
              file=sys.stderr)
        stop("private_dynamic_qml_marker_inconclusive")
    if stages != list(EXPECTED_STAGES):
        stop("private_dynamic_qml_stage_sequence_inconclusive")
    try:
        return model_summary(json.loads(lines[0]), known_frozen())
    except (ValueError, TypeError, json.JSONDecodeError):
        stop("private_dynamic_qml_parser_inconclusive")


def publish(data, path):
    for attempt in range(4):
        if (not clean()
                or git("diff-tree", "--no-commit-id", "--name-only",
                       "-r", "HEAD") != str(path)):
            stop("not_single_dynamic_receipt_commit")
        pushed = subprocess.run(
            ["git", "push", "origin", "HEAD:refs/heads/dev"],
            cwd=ROOT, capture_output=True, timeout=60)
        if pushed.returncode == 0:
            print("WULL_QT_DYNAMIC_RESULT:", data["status"], flush=True)
            print("REPORT_PUBLISHED:", str(path), flush=True)
            return
        if attempt == 3:
            stop("private_dynamic_receipt_push_refused")
        previous = git("rev-parse", "HEAD^")
        remote = fetch()
        audit(remote)
        if subprocess.run(
                ["git", "merge-base", "--is-ancestor", previous, remote],
                cwd=ROOT, capture_output=True, timeout=10).returncode:
            stop("remote_diverged_private_dynamic_receipt_kept")
        git("rebase", "--onto", remote, previous)
        if (not clean()
                or git("diff-tree", "--no-commit-id", "--name-only",
                       "-r", "HEAD") != str(path)):
            stop("private_dynamic_receipt_replay_contaminated")
        data["publication_parent_sha"] = git("rev-parse", "HEAD^")
        path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
        git("add", "--", str(path))
        if git("diff", "--cached", "--name-only") != str(path):
            stop("private_dynamic_replay_unreviewed_staging")
        git("commit", "--amend", "--no-edit")


def main():
    if sys.argv[1:] != ["--acknowledge-private-offscreen-dynamic-motion"]:
        stop("explicit_private_dynamic_opt_in_required")
    os.umask(0o077)
    state = Path(os.environ.get(
        "XDG_STATE_HOME", str(Path.home() / ".local/state"))).expanduser().resolve()
    frozen["guard"](state)
    source = fetch()
    audit(source)
    git("merge", "--ff-only", source)
    if not clean():
        stop("private_dynamic_clone_dirty_before_probe")
    local_qs = frozen["version_of"](
        "qs" if shutil.which("qs") else "quickshell", "--version")
    if local_qs != "0.3.1":
        stop("private_dynamic_quickshell_version_differs_from_frozen")
    proof = run_fixture(ROOT.parent)
    if not clean() or git("rev-parse", "HEAD") != source:
        stop("source_changed_while_running_private_dynamic")
    remote = fetch()
    audit(remote)
    if subprocess.run(["git", "merge-base", "--is-ancestor", source, remote],
                      cwd=ROOT, capture_output=True, timeout=10).returncode:
        stop("remote_diverged_after_private_dynamic")
    git("merge", "--ff-only", remote)
    parent = git("rev-parse", "HEAD")
    data = public_report(
        proof, source, parent,
        local_qs, frozen["version_of"]("qtpaths6", "--qt-version"))
    name = ("wull-qt-dynamic-"
            + dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
            + "-" + secrets.token_hex(4) + "-" + source[:12] + ".json")
    path = Path("docs") / name
    if path.exists() or path.is_symlink():
        stop("private_dynamic_receipt_name_collision")
    path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    git("add", "--", str(path))
    if (git("diff", "--cached", "--name-only") != str(path)
            or git("diff", "--name-only")
            or git("ls-files", "--others", "--exclude-standard")):
        stop("private_dynamic_receipt_exclusivity_unproven")
    git("commit", "-m", "test(wull): publish private sampled QML dynamic geometry",
        "--", str(path))
    publish(data, path)


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, ValueError,
            subprocess.TimeoutExpired) as ex:
        print("STOP:", str(ex).split(":")[0], file=sys.stderr)
        print("No compositor, pointer input or production edit.",
              file=sys.stderr)
        raise SystemExit(1)
