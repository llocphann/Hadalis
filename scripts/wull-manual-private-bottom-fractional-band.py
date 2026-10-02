#!/usr/bin/env python3
"""Private source-pinned original FULL BOTTOM x1.5 fractional-band pilot.

Owner-only, one original frozen Qt component, five sequential original full
images. Only cradle bottomMargin privately varies; no production/mask changes.
Optional publication is a strict categorized JSON-only non-force dev push.
"""
import json
import os
from pathlib import Path
import resource
import runpy
import shutil
import signal
import stat
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
BASE = "scripts/wull-manual-private-bottom-inset.py"
BASE_BLOB = "75f923b104c8409b3532a809c3ba62cfd5998e03"
FIXTURE = "scripts/wull-fixtures/paint-bottom-fractional-band/shell.qml"
FIXTURE_BLOB = "9203e9bf935c0a0ab995380dadf6a6ff27cc004d"
MODEL = "scripts/wull-private-bottom-fractional-band-model.py"
MODEL_BLOB = "f1c91fc2742b21a1cee9cb2911be7c614e8aeee5"
ALPHA = "scripts/wull-private-painted-alpha-model.py"
ALPHA_BLOB = "fa9e7c2af87ee830336988fa7060e2720e816ed0"
KEYS = ("m000", "m025", "m050", "m075", "m100")
FAILURES = frozenset((
    "ORIGINAL_MARGIN_RESTORE_FAILED", "ORIGINAL_SOURCE_OR_POSE_DRIFT",
    "INSET_GEOMETRY_OR_SOURCE_INVALID", "PRIVATE_CAPTURE_PATH_INVALID",
    "MARGIN_GRAB_OR_SAVE_FAILED", "MARGIN_GRAB_UNAVAILABLE",
    "ORIGINAL_SOURCE_TOPOLOGY_INVALID", "ORIGINAL_FROZEN_RENDERER_INVALID",
    "ORIGINAL_ZERO_MARGIN_POSE_INVALID", "BOTTOM_INSET_TIMEOUT",
))
TIMEOUT = 40
MAX_LOG = 256 * 1024


class Stop(Exception):
    pass


def require(ok, reason):
    if not ok:
        raise Stop(reason)


def checked_clone_layout(root=ROOT, current=None):
    """Mirror the immutable inherited audited-clone layout BEFORE Qt."""
    scratch = root.parent
    current = Path.cwd() if current is None else current
    require(root.name == "repo" and
            scratch.name.startswith("wull-paint-canary.") and
            current.resolve() == root.resolve() and
            not root.is_symlink() and not scratch.is_symlink(),
            "FRACTIONAL_CLONE_LAYOUT_INVALID")
    for path in (scratch, root):
        info = path.lstat()
        require(stat.S_ISDIR(info.st_mode) and
                info.st_uid == os.getuid() and
                not stat.S_IMODE(info.st_mode) & 0o077,
                "FRACTIONAL_CLONE_LAYOUT_INVALID")


def checked_sources():
    checked_clone_layout()
    previous = runpy.run_path(str(ROOT / BASE),
                              run_name="fractional_borrow_original_guard")
    try:
        core, source = previous["checked_sources"]()
    except previous["Stop"]:
        raise Stop("FRACTIONAL_INHERITED_SOURCE_AUDIT_REJECTED")
    git = core["git"]
    for path, sha in ((BASE, BASE_BLOB), (FIXTURE, FIXTURE_BLOB),
                      (MODEL, MODEL_BLOB), (ALPHA, ALPHA_BLOB)):
        require(git("rev-parse", "HEAD:" + path) == sha,
                "FRACTIONAL_SOURCE_PIN_INVALID")
    model = runpy.run_path(str(ROOT / MODEL), run_name="fractional_model_pin")
    require(model["MARGINS"] == KEYS, "FRACTIONAL_SOURCE_PIN_INVALID")
    return previous, core, source


def stages():
    items = ["BOOT", "PREPARED"]
    for key in KEYS:
        items.extend((key.upper() + "_REQUESTED", key.upper() + "_SAVED"))
    return items + ["DONE"]


def checked_stage_log(log):
    observed, failures = [], []
    expected = stages()
    for line in log.splitlines():
        if "WULL_FRACTIONAL_BAND_STAGE=" in line:
            token = line.split("WULL_FRACTIONAL_BAND_STAGE=", 1)[1].strip()
            require(not failures and len(observed) < len(expected) and
                    token == expected[len(observed)],
                    "FRACTIONAL_STAGE_INVALID")
            observed.append(token)
        if "WULL_FRACTIONAL_BAND_FAILURE=" in line:
            token = line.split("WULL_FRACTIONAL_BAND_FAILURE=", 1)[1].strip()
            require(token in FAILURES and not failures,
                    "FRACTIONAL_FAILURE_INVALID")
            failures.append(token)
    return observed, failures


def private_classify(directory, previous):
    names = {key + ".private.png" for key in KEYS}
    require({p.name for p in directory.glob("*.private.png")} == names,
            "FRACTIONAL_CAPTURE_SET_INVALID")
    images = {
        key: previous["secure_png"](directory / (key + ".private.png"))
        for key in KEYS
    }
    parser = runpy.run_path(str(ROOT / ALPHA),
                            run_name="fractional_bounded_original_alpha")
    model = runpy.run_path(str(ROOT / MODEL),
                           run_name="fractional_original_full_classifier")
    try:
        return model["classify"](images, parser)
    except (ValueError, KeyError, TypeError):
        raise Stop("FRACTIONAL_ALPHA_UNQUALIFIED")


def private_run(previous, core):
    qs = shutil.which("qs") or shutil.which("quickshell")
    dbus = shutil.which("dbus-run-session")
    require(bool(qs and dbus), "PRIVATE_QT_PREREQUISITE_MISSING")
    version = runpy.run_path(
        str(ROOT / "scripts/wull-manual-offscreen-motion-geometry.py"),
        run_name="fractional_original_qs_version_only")
    name = "qs" if shutil.which("qs") else "quickshell"
    require(version["version_of"](name, "--version") == "0.3.1",
            "PRIVATE_QS_VERSION_INVALID")
    directory = ROOT.parent / "fractional-band"
    directory.mkdir(mode=0o700)
    require(stat.S_ISDIR(directory.lstat().st_mode) and
            directory.lstat().st_uid == os.getuid() and
            stat.S_IMODE(directory.lstat().st_mode) == 0o700,
            "FRACTIONAL_DIRECTORY_UNSAFE")
    try:
        shell, xdg = core["stage_files"](directory)
    except core["Stop"]:
        raise Stop("PRIVATE_FIXTURE_DEPENDENCIES_MISSING")
    shutil.copyfile(ROOT / FIXTURE, shell / "shell.qml")
    env = core["private_env"](xdg, directory / "unused.not-a-capture")
    for key in tuple(env):
        if key.startswith("WULL_"):
            env.pop(key, None)
    env["WULL_FRACTIONAL_BAND_DIR"] = str(directory)
    logpath = directory / "fractional-band.private.log"
    code, expired = None, False
    with logpath.open("xb") as out:
        proc = subprocess.Popen(
            [dbus, "--", qs, "--path", str(shell / "shell.qml")],
            cwd=ROOT, env=env, stdin=subprocess.DEVNULL,
            stdout=out, stderr=subprocess.STDOUT,
            start_new_session=True, preexec_fn=previous["child_limits"])
        try:
            try:
                code = proc.wait(timeout=TIMEOUT)
            except subprocess.TimeoutExpired:
                expired = True
        finally:
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
            time.sleep(.15)
            try:
                os.killpg(proc.pid, 0)
            except ProcessLookupError:
                pass
            else:
                raise Stop("PRIVATE_QT_GROUP_NOT_REAPED")
    require(not expired and code == 0, "FRACTIONAL_QT_UNQUALIFIED")
    st = logpath.lstat()
    require(stat.S_ISREG(st.st_mode) and st.st_uid == os.getuid()
            and not stat.S_IMODE(st.st_mode) & 0o077
            and 0 < st.st_size <= MAX_LOG,
            "FRACTIONAL_PRIVATE_LOG_UNSAFE")
    observed, failures = checked_stage_log(
        logpath.read_text(encoding="utf-8", errors="replace"))
    require(not failures and observed == stages(),
            "FRACTIONAL_QT_STAGES_UNQUALIFIED")
    return private_classify(directory, previous)


def publish_safe_report(source, result):
    """Whitelist categories only. No raw images, coordinates, device data."""
    try:
        git = ["git", "-c", "core.hooksPath=/dev/null",
               "-c", "credential.interactive=never"]
        # Never block awaiting an owner GitHub username/PAT. Existing
        # non-interactive credential helpers may still authenticate.
        no_prompt = dict(os.environ)
        no_prompt.update({
            "GIT_TERMINAL_PROMPT": "0",
            "GCM_INTERACTIVE": "never",
            "GIT_ASKPASS": "/bin/false",
            "SSH_ASKPASS": "/bin/false",
        })
        def call(*args):
            return subprocess.run(git + list(args), cwd=ROOT,
                                  stdin=subprocess.DEVNULL,
                                  stdout=subprocess.PIPE,
                                  stderr=subprocess.DEVNULL,
                                  env=no_prompt,
                                  text=True, timeout=15, check=True).stdout.strip()
        require(call("rev-parse", "HEAD") == source and
                call("symbolic-ref", "--short", "HEAD") == "dev" and
                call("config", "--get", "remote.origin.url") ==
                "https://github.com/llocphann/Hadalis.git" and
                not call("status", "--porcelain=v1", "--untracked-files=all"),
                "REPORT_PRECONDITION_FAILED")
        remote = call("ls-remote", "origin", "refs/heads/dev").split()
        require(len(remote) == 2 and remote[0] == source and
                remote[1] == "refs/heads/dev",
                "REPORT_REMOTE_MOVED")
        relative = ("docs/wull-private-reports/"
                    "wull-bottom-fractional-band-" + source + ".json")
        path = ROOT / relative
        require(not path.parent.is_symlink() and
                path.parent.parent.is_dir() and
                not path.exists() and not path.is_symlink(),
                "REPORT_PATH_UNSAFE")
        path.parent.mkdir(mode=0o755, exist_ok=True)
        require(path.parent.is_dir() and not path.parent.is_symlink(),
                "REPORT_PATH_UNSAFE")
        # Deliberately enumerate every public field and only known bool values.
        payload = {
            "schema_version": 1,
            "kind": "owner_local_private_original_bottom150_fractional_band",
            "source_sha": source,
            "source_fixture_blob": FIXTURE_BLOB,
            "capture": "one_original_qt_instance_five_sequential_frozen_full",
            "exterior_by_margin": {k: bool(result["exterior"][k]) for k in KEYS},
            "virtual_band_by_margin": {k: bool(result["contact"][k]) for k in KEYS},
            "joint_fractional_candidates": [
                k for k in KEYS[1:-1]
                if k in result["fractional_joint_candidates"]],
            "real_panel_visual": "untested",
            "spring_motion": "untested_in_this_probe",
            "compositor_pointer_popup": "untested",
            "production_mask_changed": False,
            "evidence_type": "owner_local_self_report_not_independently_replayed",
        }
        path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n",
                        encoding="utf-8")
        path.chmod(0o644)  # This explicitly whitelisted file is PUBLIC.
        call("add", "--", relative)
        require(call("diff", "--cached", "--name-only") == relative,
                "REPORT_STAGED_PATH_INVALID")
        call("-c", "user.name=Wull Private Probe",
             "-c", "user.email=wull-probe@users.noreply.github.com",
             "commit", "-m", "test(wull): owner-local fractional band categories")
        require(call("diff-tree", "--no-commit-id", "--name-only",
                     "-r", "HEAD") == relative,
                "REPORT_COMMIT_PATH_INVALID")
        # No force and no retry: concurrent MegaQML or other dev HEAD wins.
        call("push", "origin", "HEAD:refs/heads/dev")
        return relative
    except (Exception, OSError):
        return None


def stop_signal(_signum, _frame):
    # Raise into private_run wait so its finally kills/reaps the Qt group.
    raise Stop("FRACTIONAL_INTERRUPTED")


def main():
    signal.signal(signal.SIGTERM, stop_signal)
    signal.signal(signal.SIGINT, stop_signal)
    require(sys.argv[1:] in (
        ["--acknowledge-private-bottom-fractional-band"],
        ["--acknowledge-private-bottom-fractional-band",
         "--publish-sanitized-report"]),
        "FRACTIONAL_EXPLICIT_OPT_IN_REQUIRED")
    os.umask(0o077)
    previous, core, source = checked_sources()
    report = private_run(previous, core)
    require(core["git"]("rev-parse", "HEAD") == source and
            not core["git"]("status", "--porcelain=v1",
                            "--untracked-files=all"),
            "FRACTIONAL_POSTRUN_SOURCE_CHANGED")
    require(set(report["exterior"]) == set(KEYS) and
            set(report["contact"]) == set(KEYS) and
            report["exterior"]["m000"] is True and
            report["exterior"]["m100"] is False and
            report["contact"]["m000"] is True,
            "FRACTIONAL_BASELINE_UNQUALIFIED")
    print("SOURCE_SHA=" + source)
    print("WULL_FRACTIONAL_PRIVATE_RGBA8_FRAMES=5")
    print("BASELINE_M0_EXTERIOR=YES")
    print("BASELINE_M0_BAND=YES")
    print("CONTROL_M1_EXTERIOR=NO")
    for key in KEYS:
        print(key.upper() + "_EXTERIOR=" +
              ("YES" if report["exterior"][key] else "NO"))
        print(key.upper() + "_BAND=" +
              ("YES" if report["contact"][key] else "NO"))
    print("JOINT_FRACTIONAL_CANDIDATE=" +
          ("YES" if report["fractional_joint_candidates"] else "NO"))
    print("REAL_PANEL_VISUAL_CONNECTION=UNTESTED")
    print("MOTION_AND_POINTER=UNTESTED")
    print("PRODUCTION_MASK_CHANGED=NO")
    print("GATE=PRIVATE_FRACTIONAL_BAND_CLASSIFIED")
    if "--publish-sanitized-report" in sys.argv[1:]:
        published = publish_safe_report(source, report)
        print("REPORT_PUBLISHED=" + (published if published else "NO"))


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        safe = {
            "FRACTIONAL_CLONE_LAYOUT_INVALID",
            "FRACTIONAL_INHERITED_SOURCE_AUDIT_REJECTED",
            "FRACTIONAL_INTERRUPTED",
            "FRACTIONAL_EXPLICIT_OPT_IN_REQUIRED",
            "FRACTIONAL_SOURCE_PIN_INVALID",
            "PRIVATE_QT_PREREQUISITE_MISSING",
            "PRIVATE_QS_VERSION_INVALID",
            "FRACTIONAL_DIRECTORY_UNSAFE",
            "PRIVATE_FIXTURE_DEPENDENCIES_MISSING",
            "PRIVATE_QT_GROUP_NOT_REAPED",
            "FRACTIONAL_QT_UNQUALIFIED",
            "FRACTIONAL_PRIVATE_LOG_UNSAFE",
            "FRACTIONAL_STAGE_INVALID",
            "FRACTIONAL_FAILURE_INVALID",
            "FRACTIONAL_QT_STAGES_UNQUALIFIED",
            "FRACTIONAL_CAPTURE_SET_INVALID",
            "FRACTIONAL_ALPHA_UNQUALIFIED",
            "FRACTIONAL_POSTRUN_SOURCE_CHANGED",
            "FRACTIONAL_BASELINE_UNQUALIFIED",
        }
        token = str(exc)
        print("GATE=" + (token if token in safe
                         else "PRIVATE_FRACTIONAL_BAND_UNAVAILABLE"))
        raise SystemExit(1)
