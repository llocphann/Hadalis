#!/usr/bin/env python3
"""Opt-in, bounded isolated production Abyss PanelWindow observation on real Niri.

This cannot prove pointer pass-through or visual quality; those require separate
live interaction. It never changes the user's running shell configuration.
"""
import datetime as dt
import json
import os
from pathlib import Path
import secrets
import shutil
import signal
import subprocess
import sys
import time

BASE = "a9d1cb0668bd5f685c8a6d773f5ef4880567ed71"
SELF = "scripts/wull-manual-production-layer.py"
FIXTURE = "scripts/wull-fixtures/production-layer/shell.qml"
FIXTURE_BLOB = "e16b6dcada26a27fd71cc670e30c55135401bcef"
NAMESPACE = "hadalis:abyss-perimeter"
SAFE_REMOTE = {
    "https://github.com/llocphann/Hadalis",
    "https://github.com/llocphann/Hadalis.git",
    "git@github.com:llocphann/Hadalis",
    "git@github.com:llocphann/Hadalis.git",
    "ssh://git@github.com/llocphann/Hadalis",
    "ssh://git@github.com/llocphann/Hadalis.git",
}
MAX_LOG = 1048576


def git(*args):
    result = subprocess.run(["git", *args], capture_output=True, text=True,
                            timeout=45)
    if result.returncode:
        raise RuntimeError("Git operation failed: " + " ".join(args))
    return result.stdout.strip()


def clean():
    return git("status", "--porcelain=v1", "--untracked-files=all") == ""


def fetch():
    git("fetch", "--quiet", "origin",
        "refs/heads/dev:refs/remotes/origin/dev")
    return git("rev-parse", "refs/remotes/origin/dev")


def audit(target):
    if subprocess.run(["git", "merge-base", "--is-ancestor", BASE, target],
                      capture_output=True).returncode:
        raise RuntimeError("Remote dev diverged from the reviewed baseline")
    if git("rev-parse", target + ":" + FIXTURE) != FIXTURE_BLOB:
        raise RuntimeError("Reviewed production-layer fixture changed")
    modified = set(git("diff", "--name-only", BASE, target).splitlines())
    protected = (
        "modules/", "services/", "native/", "assets/", "defaults/",
        "scripts/native-", "GlobalStates.qml", "shell.qml", "qmldir",
        "scripts/wull-fixtures/"
    )
    changed = [name for name in modified
               if name != FIXTURE and name != SELF
               and (name.startswith(protected) or name == "AGENTS.md")]
    if changed:
        raise RuntimeError("Reviewed production dependencies changed: "
                           + sorted(changed)[0])
    if SELF in modified:
        # Exactly one reviewed follow-up after the initial runner commit.
        revisions = git("log", "--format=%H",
                        BASE + ".." + target, "--", SELF).splitlines()
        if len(revisions) != 2 or (
            git("rev-parse", revisions[0] + ":" + SELF)
            != git("rev-parse", target + ":" + SELF)
        ):
            raise RuntimeError("Unreviewed production-layer runner revision")


def niri_json(niri, command):
    result = subprocess.run([niri, "msg", "-j", command],
                            capture_output=True, text=True, timeout=4)
    if result.returncode:
        raise RuntimeError("niri_" + command + "_unavailable")
    data = json.loads(result.stdout)
    if command == "layers":
        if isinstance(data, dict):
            data = data.get("layers")
        if not isinstance(data, list):
            raise RuntimeError("niri_layers_unexpected_schema")
    elif not isinstance(data, dict):
        raise RuntimeError("niri_outputs_unexpected_schema")
    return data


def our_layers(niri):
    return [item for item in niri_json(niri, "layers")
            if isinstance(item, dict) and item.get("namespace") == NAMESPACE]


def private_pids(binary):
    target = str(binary.resolve())
    found = []
    for path in Path("/proc").iterdir():
        if not path.name.isdigit():
            continue
        try:
            if os.readlink(path / "exe") == target:
                found.append(int(path.name))
        except (OSError, PermissionError):
            continue
    return found


def bound_log(path):
    if path.exists() and path.stat().st_size > MAX_LOG:
        with path.open("rb") as stream:
            beginning = stream.read(MAX_LOG // 2)
            stream.seek(-MAX_LOG // 2, os.SEEK_END)
            end = stream.read()
        path.write_bytes(beginning + b"\n[PRIVATE LOG OMITTED]\n" + end)


def stop_owned(proc, binary):
    # Only touch the private process group this invocation created and the
    # exact executable in its unique private cargo target directory.
    if proc is not None:
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
    for pid in private_pids(binary):
        try:
            os.kill(pid, signal.SIGTERM)
        except ProcessLookupError:
            continue


def prepare_config(folder, output, enabled):
    shell = folder / "shell"
    shell.mkdir(parents=True)
    root = Path.cwd()
    for name in ("modules", "services", "GlobalStates.qml", "qmldir",
                 "assets", "scripts", "defaults", "translations"):
        (shell / name).symlink_to(root / name)
    shutil.copyfile(FIXTURE, shell / "shell.qml")
    xdg = folder / "xdg"
    for name in ("config", "data", "cache", "state"):
        (xdg / name).mkdir(parents=True)
    config_file = xdg / "config" / "illogical-impulse" / "config.json"
    config_file.parent.mkdir(parents=True)
    conf = json.loads(Path("defaults/config.json").read_text(encoding="utf-8"))
    conf["panelFamily"] = "abyss"
    # Disable all unrelated optional panels in this temporary shell.
    conf["enabledPanels"] = []
    conf["abyss"]["companion"].update(
        {"enabled": enabled, "output": output, "interactive": False,
         "soundEnabled": False}
    )
    config_file.write_text(json.dumps(conf, indent=2) + "\n", encoding="utf-8")
    return shell, xdg


def observe_phase(label, folder, output, outputs, qs, niri, dbus, binary):
    enabled = label == "production_enabled"
    result = {
        "check": label, "status": "failed", "reason": None,
        "isolated_fixture_ready": False,
        "production_layers_per_output": False,
        "no_unrequested_keyboard_focus": False,
        "expected_private_daemon_count": False,
        "owned_daemon_stopped": False,
        "owned_layers_unmapped": False,
        "input_pass_through": "not_run",
    }
    shell, xdg = prepare_config(folder, output, enabled)
    env = dict(os.environ)
    for key in ("QS_CONFIG_PATH", "QS_CONFIG_NAME", "QS_MANIFEST"):
        env.pop(key, None)
    env.update({
        "QT_QPA_PLATFORM": "wayland",
        "QS_NO_RELOAD_POPUP": "1",
        "INIR_COMPANIOND": str(binary),
        "XDG_CONFIG_HOME": str(xdg / "config"),
        "XDG_DATA_HOME": str(xdg / "data"),
        "XDG_CACHE_HOME": str(xdg / "cache"),
        "XDG_STATE_HOME": str(xdg / "state"),
    })
    log = folder / "quickshell.private.log"
    proc = None
    start = time.monotonic()
    observed_count = False
    try:
        with log.open("wb") as stream:
            proc = subprocess.Popen(
                [dbus, "--", qs, "-n", "-p", str(shell), "--no-color"],
                env=env, stdout=stream, stderr=subprocess.STDOUT,
                start_new_session=True
            )
            while time.monotonic() - start < (12 if enabled else 8):
                if proc.poll() is not None:
                    result["reason"] = "isolated_quickshell_early_exit"
                    break
                if not result["isolated_fixture_ready"]:
                    result["isolated_fixture_ready"] = (
                        "WULL_PRODUCTION_FIXTURE_READY" in
                        log.read_text(encoding="utf-8", errors="replace")[-MAX_LOG:]
                    )
                try:
                    layers = our_layers(niri)
                except (RuntimeError, ValueError, subprocess.TimeoutExpired):
                    result["reason"] = "niri_layer_inventory_lost"
                    break
                counts = {name: 0 for name in outputs}
                for item in layers:
                    name = item.get("output")
                    if name in counts:
                        counts[name] += 1
                result["production_layers_per_output"] = (
                    len(layers) == len(outputs) and
                    all(n == 1 for n in counts.values())
                )
                result["no_unrequested_keyboard_focus"] = (
                    bool(layers) and all(
                        str(item.get("keyboard_interactivity", "")).lower()
                        in ("none", "wlrkeyboardfocus.none")
                        for item in layers
                    )
                )
                pids = private_pids(binary)
                expected = 1 if enabled else 0
                if len(pids) > expected:
                    result["reason"] = "duplicate_or_unrequested_daemon"
                    break
                if len(pids) == expected:
                    observed_count = True
                if enabled and len(pids) != 1:
                    observed_count = False
                if (result["isolated_fixture_ready"]
                        and result["production_layers_per_output"]
                        and result["no_unrequested_keyboard_focus"]
                        and observed_count
                        and time.monotonic() - start > (2 if enabled else 4)):
                    result["expected_private_daemon_count"] = True
                    break
                time.sleep(.25)
            if result["reason"] is None and not result["expected_private_daemon_count"]:
                result["reason"] = "production_layer_or_daemon_unproven"
    except OSError:
        result["reason"] = "isolated_quickshell_launch_failed"
    finally:
        stop_owned(proc, binary)
        bound_log(log)

    deadline = time.monotonic() + 5
    while time.monotonic() < deadline:
        result["owned_daemon_stopped"] = len(private_pids(binary)) == 0
        try:
            result["owned_layers_unmapped"] = len(our_layers(niri)) == 0
        except (ValueError, RuntimeError, subprocess.TimeoutExpired):
            result["owned_layers_unmapped"] = False
        if result["owned_daemon_stopped"] and result["owned_layers_unmapped"]:
            break
        time.sleep(.25)
    if all(result[key] for key in (
        "isolated_fixture_ready", "production_layers_per_output",
        "no_unrequested_keyboard_focus", "expected_private_daemon_count",
        "owned_daemon_stopped", "owned_layers_unmapped"
    )):
        result["status"] = "pass"
        result["reason"] = None
    elif not result["owned_daemon_stopped"] or not result["owned_layers_unmapped"]:
        result["reason"] = "owned_process_or_layer_cleanup_unproven"
    return result


def publication(report, path):
    for attempt in range(4):
        push = subprocess.run(
            ["git", "push", "origin", "HEAD:refs/heads/dev"],
            capture_output=True, timeout=45
        )
        if push.returncode == 0:
            return
        if attempt == 3:
            raise RuntimeError("Publication rejected; report remains local")
        if not clean() or git("diff-tree", "--no-commit-id", "--name-only",
                              "-r", "HEAD") != str(path):
            raise RuntimeError("Only a single unpublished report may be rebased")
        parent = git("rev-parse", "HEAD^")
        remote = fetch()
        audit(remote)
        if subprocess.run(
            ["git", "merge-base", "--is-ancestor", parent, remote],
            capture_output=True
        ).returncode:
            raise RuntimeError("Unexpected remote history; no publication")
        git("rebase", "--onto", remote, parent)
        if not clean() or git("diff-tree", "--no-commit-id", "--name-only",
                              "-r", "HEAD") != str(path):
            raise RuntimeError("Rebased report no longer isolated")
        report["publication_parent_sha"] = git("rev-parse", "HEAD^")
        path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        git("add", "--", str(path))
        if git("diff", "--cached", "--name-only") != str(path):
            raise RuntimeError("Unreviewed staged files")
        git("commit", "--amend", "--no-edit")


def main():
    os.umask(0o077)
    if sys.argv[1:] != ["--acknowledge-temporary-layer"]:
        raise RuntimeError(
            "Explicit opt-in required: --acknowledge-temporary-layer")
    if Path.cwd().resolve() != Path(git("rev-parse", "--show-toplevel")).resolve():
        raise RuntimeError("Run from repository root")
    if git("symbolic-ref", "--quiet", "--short", "HEAD") != "dev" or not clean():
        raise RuntimeError("Requires a clean dev checkout")
    fetch_urls = git("remote", "get-url", "origin")
    push_urls = git("remote", "get-url", "--push", "--all", "origin").splitlines()
    if (fetch_urls not in SAFE_REMOTE or len(push_urls) != 1
            or push_urls[0] not in SAFE_REMOTE):
        raise RuntimeError("Unexpected repository origin")
    remote = fetch()
    audit(remote)
    git("merge", "--ff-only", remote)
    if not clean():
        raise RuntimeError("Working tree changed")
    source = git("rev-parse", "HEAD")
    identifier = (dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
                  + "-" + secrets.token_hex(4))
    private = Path(os.environ.get("XDG_STATE_HOME",
                    str(Path.home() / ".local/state"))).resolve()
    private = private / "hadalis" / ("wull-production-layer-" + identifier)
    root = Path(git("rev-parse", "--show-toplevel")).resolve()
    if private == root or root in private.parents:
        raise RuntimeError("Private state directory must be outside the repo")
    private.mkdir(mode=0o700, parents=True, exist_ok=False)
    print("EXACT_SOURCE_SHA:", source, flush=True)
    print("PRIVATE_LOG_DIRECTORY:", private, flush=True)
    results = []
    preflight_reason = None
    qs = shutil.which("qs") or shutil.which("quickshell")
    niri = shutil.which("niri")
    cargo = shutil.which("cargo")
    dbus = shutil.which("dbus-run-session")
    output = None
    names = []
    binary = private / "cargo-target" / "release" / "inir-companiond"
    if not all((qs, niri, cargo, dbus, os.environ.get("WAYLAND_DISPLAY"))):
        preflight_reason = "required_desktop_tool_or_wayland_unavailable"
    else:
        try:
            outputs = niri_json(niri, "outputs")
            names = sorted(name for name, data in outputs.items()
                           if isinstance(data, dict)
                           and data.get("logical") is not None)
            if not names:
                preflight_reason = "no_active_niri_outputs"
            elif our_layers(niri):
                # Never overlay an already running Abyss production session.
                preflight_reason = "abyss_perimeter_already_running"
            else:
                output = names[0]
        except (RuntimeError, ValueError, subprocess.TimeoutExpired):
            preflight_reason = "niri_layers_or_outputs_unavailable"
    if preflight_reason is None:
        build_log = private / "cargo-build.private.log"
        env = dict(os.environ)
        env["CARGO_TARGET_DIR"] = str(private / "cargo-target")
        try:
            with build_log.open("wb") as stream:
                build = subprocess.run(
                    [cargo, "build", "--locked", "--release",
                     "--manifest-path", "native/Cargo.toml",
                     "-p", "inir-companiond"],
                    env=env, stdout=stream, stderr=subprocess.STDOUT,
                    timeout=900
                )
            if build.returncode != 0 or not binary.is_file():
                preflight_reason = "private_rust_release_build_failed"
        except (OSError, subprocess.TimeoutExpired):
            preflight_reason = "private_rust_release_build_unavailable"
        finally:
            bound_log(build_log)
    if preflight_reason is None:
        if private_pids(binary):
            preflight_reason = "private_binary_already_running"
        else:
            first = observe_phase("production_disabled", private / "disabled",
                                  output, names, qs, niri, dbus, binary)
            results.append(first)
            print("production_disabled:", first["status"], flush=True)
            if first["status"] == "pass":
                second = observe_phase("production_enabled",
                                       private / "enabled", output, names,
                                       qs, niri, dbus, binary)
                results.append(second)
                print("production_enabled:", second["status"], flush=True)
    status = ("inconclusive" if preflight_reason else
              "pass" if len(results) == 2 and
                        all(x["status"] == "pass" for x in results)
              else "failed")
    report = {
        "kind": "wull_manual_isolated_real_production_layer",
        "source_sha": source, "status": status,
        "preflight_reason": preflight_reason,
        "scope": "temporary_real_AbyssPerimeter_PanelWindow",
        "observed_active_output_count": len(names),
        "tests": results,
        "native_input_passthrough_acceptance": "not_run",
        "visual_and_multioutput_interaction_acceptance": "not_run",
        "canonical_validation": "not_run",
        "private_logs": "local_only",
    }
    (private / "sanitized-summary.json").write_text(
        json.dumps(report, indent=2) + "\n", encoding="utf-8"
    )
    print("PRODUCTION_LAYER_RESULT:", status, flush=True)
    if git("rev-parse", "HEAD") != source or not clean():
        raise RuntimeError("Source changed; report retained locally")
    latest = fetch()
    audit(latest)
    git("merge", "--ff-only", latest)
    if not clean():
        raise RuntimeError("Unexpected checkout changes before publication")
    report["publication_parent_sha"] = git("rev-parse", "HEAD")
    path = Path("docs") / ("wull-production-layer-" + identifier
                           + "-" + source[:12] + ".json")
    if path.exists():
        raise RuntimeError("Refusing to overwrite a production-layer receipt")
    path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    git("add", "--", str(path))
    if (git("diff", "--cached", "--name-only") != str(path)
            or git("diff", "--name-only")
            or git("ls-files", "--others", "--exclude-standard")):
        raise RuntimeError("Unexpected files before report commit")
    git("commit", "-m", "test(wull): publish isolated real production layer proof",
        "--", str(path))
    publication(report, path)
    print("REPORT_PUBLISHED:", path, flush=True)


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, ValueError, OSError, subprocess.TimeoutExpired,
            subprocess.CalledProcessError) as error:
        print("STOP:", error, file=sys.stderr)
        print("If executed, private diagnostics remain on this machine.",
              file=sys.stderr)
        sys.exit(1)
