#!/usr/bin/env python3
"""Bounded REAL nested-Niri pointer evidence; private child, never run alone.

Parent supplies a separately validated nested Wayland + Niri IPC identity.
Only a forced wlr-protocols wdotool backend may inject pointer events.
Production QML and native Rust source remain unmodified.
"""
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
UNDERLAY = "scripts/wull-fixtures/pointer-underlay/shell.qml"
PRODUCTION = "scripts/wull-fixtures/production-layer/shell.qml"
RELAY = "scripts/wull-fixtures/pointer-underlay/companion-relay.py"
MAX_LOG = 1048576


def stop(reason):
    raise RuntimeError(reason)


def run(argv, env=None, timeout=6):
    return subprocess.run(argv, env=env, capture_output=True, timeout=timeout)


def niri_json(niri, command):
    value = run([niri, "msg", "-j", command])
    if value.returncode:
        stop("nested_niri_inventory_unavailable")
    body = json.loads(value.stdout)
    if isinstance(body, dict) and "Ok" in body:
        body = body["Ok"]
    if isinstance(body, dict):
        body = body.get({"outputs": "Outputs", "layers": "Layers"}[command],
                        body.get(command, body))
    if command == "layers" and not isinstance(body, list):
        stop("nested_layers_schema_invalid")
    if command == "outputs" and not isinstance(body, dict):
        stop("nested_outputs_schema_invalid")
    return body


def namespaced(layers, name):
    return [x for x in layers if isinstance(x, dict)
            and x.get("namespace") == name]


def verify_isolation(niri):
    env = os.environ
    runtime = Path(env.get("XDG_RUNTIME_DIR", "")).resolve()
    nested = env.get("NIRI_SOCKET", "")
    host = env.get("WULL_PARENT_NIRI_SOCKET", "")
    display = env.get("WAYLAND_DISPLAY", "")
    host_display = env.get("WULL_PARENT_WAYLAND_DISPLAY", "")
    if (env.get("WULL_PRIVATE_POINTER_CHILD") != "owned-nested"
            or not nested or nested != env.get("WULL_PRIVATE_POINTER_NESTED_SOCKET")
            or not host or host == nested or not display
            or not host_display or display == host_display):
        stop("nested_identity_unverified")
    nested_path = Path(nested).resolve()
    display_path = runtime / display
    if (nested_path.parent != runtime or not nested_path.is_socket()
            or not display.startswith("wayland-") or not display_path.is_socket()):
        stop("nested_endpoints_not_owned_runtime_sockets")
    active = niri_json(niri, "outputs")
    outputs = [(name, value["logical"]) for name, value in active.items()
               if isinstance(value, dict) and isinstance(value.get("logical"), dict)]
    if len(outputs) != 1 or (not isinstance(outputs[0][1].get("width"), int)
                             or not isinstance(outputs[0][1].get("height"), int)):
        stop("nested_single_output_geometry_unavailable")
    if namespaced(niri_json(niri, "layers"), "hadalis:abyss-perimeter"):
        stop("preexisting_nested_abyss_layer")
    if namespaced(niri_json(niri, "layers"), "hadalis:wull-pointer-underlay"):
        stop("preexisting_nested_pointer_underlay")
    return outputs[0][0], outputs[0][1]["width"], outputs[0][1]["height"]


def private_pids(path):
    found = []
    expected = str(path.resolve())
    for item in Path("/proc").iterdir():
        if not item.name.isdigit():
            continue
        try:
            if os.readlink(item / "exe") == expected:
                found.append(int(item.name))
        except (OSError, PermissionError):
            pass
    return found


def relay_pids(path):
    result = []
    needle = str(path.resolve()).encode()
    for item in Path("/proc").iterdir():
        if not item.name.isdigit():
            continue
        try:
            if item.stat().st_uid == os.getuid() and needle in (
                    item / "cmdline").read_bytes().split(b"\0"):
                result.append(int(item.name))
        except (OSError, PermissionError):
            pass
    return result


def owned_cleanup(proc, exact_binary, private_relay):
    if proc is not None and proc.poll() is None:
        try:
            os.killpg(proc.pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
        try:
            proc.wait(timeout=4)
        except subprocess.TimeoutExpired:
            if proc.poll() is None:
                try:
                    os.killpg(proc.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                proc.wait(timeout=3)
    # Exact private executable/relay identity, never kill a system daemon.
    for pid in private_pids(exact_binary) + relay_pids(private_relay):
        try:
            os.kill(pid, signal.SIGTERM)
        except ProcessLookupError:
            pass


def bounded(path):
    if path.exists() and path.stat().st_size > MAX_LOG:
        with path.open("rb") as stream:
            first = stream.read(MAX_LOG // 2)
            stream.seek(-MAX_LOG // 2, os.SEEK_END)
            last = stream.read()
        path.write_bytes(first + b"\n[PRIVATE LOG MIDDLE REMOVED]\n" + last)


def markers(path, prefix):
    if not path.exists():
        return []
    return [part.split(prefix, 1)[1] for part in
            path.read_text(encoding="utf-8", errors="replace").splitlines()
            if prefix in part]


def trace_kinds(path):
    if not path.is_file():
        return []
    records = []
    for item in path.read_text(encoding="utf-8", errors="replace").splitlines():
        if len(item) > 512:
            stop("relay_trace_record_over_limit")
        entry = json.loads(item)
        if entry.get("kind") in (
                "real_bridge_click_received", "rust_happy_pulse_ack",
                "rust_present"):
            records.append(entry["kind"])
    return records


def wait_for(predicate, seconds):
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        if predicate():
            return True
        time.sleep(.20)
    return False


def phase_config(folder, fixture, name, config=None, env_add=None):
    shell = folder / "shell"
    shell.mkdir(parents=True)
    if fixture == PRODUCTION:
        for item in ("modules", "services", "GlobalStates.qml", "qmldir",
                     "assets", "scripts", "defaults", "translations"):
            (shell / item).symlink_to(ROOT / item)
    shutil.copyfile(ROOT / fixture, shell / "shell.qml")
    xdg = folder / "xdg"
    for item in ("config", "data", "cache", "state"):
        (xdg / item).mkdir(parents=True)
    if config is not None:
        file = xdg / "config" / "illogical-impulse" / "config.json"
        file.parent.mkdir()
        file.write_text(json.dumps(config) + "\n", encoding="utf-8")
    env = dict(os.environ)
    for key in ("QS_CONFIG_PATH", "QS_CONFIG_NAME", "QS_MANIFEST", "INIR_COMPANIOND"):
        env.pop(key, None)
    env.update({"XDG_CONFIG_HOME": str(xdg / "config"),
                "XDG_DATA_HOME": str(xdg / "data"),
                "XDG_CACHE_HOME": str(xdg / "cache"),
                "XDG_STATE_HOME": str(xdg / "state"),
                "QT_QPA_PLATFORM": "wayland", "QS_NO_RELOAD_POPUP": "1"})
    env.update(env_add or {})
    return shell, env


def launch(folder, qs, dbus, shell, env):
    folder.mkdir(parents=True, exist_ok=True)
    log = folder / "quickshell.private.log"
    with log.open("wb") as output:
        proc = subprocess.Popen(
            [dbus, "--", qs, "-n", "-p", str(shell), "--no-color"],
            env=env, stdin=subprocess.DEVNULL, stdout=output,
            stderr=subprocess.STDOUT, start_new_session=True
        )
    return proc, log


def main():
    if sys.argv[1:] != ["--nested-child"]:
        stop("explicit_parent_coordinator_only")
    os.umask(0o077)
    # A bounded parent termination must enter our owned-process finally path.
    # Never signal process groups whose owned leader has already exited.
    signal.signal(signal.SIGTERM,
                  lambda _signum, _frame: (_ for _ in ()).throw(
                      RuntimeError("owned_child_stop_requested")))
    state_text = os.environ.get("WULL_PRIVATE_POINTER_ROOT", "")
    if not state_text or not Path(state_text).is_absolute():
        stop("private_state_root_missing")
    folder = Path(state_text).resolve()
    if not folder.is_dir() or folder == ROOT or ROOT in folder.parents:
        stop("private_state_invalid_or_inside_checkout")
    niri = shutil.which("niri")
    qs = shutil.which("qs") or shutil.which("quickshell")
    dbus = shutil.which("dbus-run-session")
    cargo = shutil.which("cargo")
    actor = shutil.which("wdotool")
    if not all((niri, qs, dbus, cargo)):
        stop("required_nested_test_dependency_unavailable")
    output, width, height = verify_isolation(niri)
    helper = __import__("runpy").run_path(str(ROOT / "scripts/wull-pointer-targets.py"),
                                          run_name="wull_pointer_child_only")
    points = helper["top_edge_targets"](width, height)
    report = {"status": "inconclusive", "reason": None, "checks": [],
              "nested_verified": True, "underlay_unmapped": False,
              "production_unmapped": False, "private_daemon_stopped": False,
              "real_rust_binary_built": False,
              "injection_backend": "forced_wlr_protocols_if_available",
              "whole_host_mask_changed": False}
    final = folder / "pointer-child.private-summary.json"
    underlay_proc = disabled_proc = enabled_proc = None
    binary = folder / "cargo-target" / "release" / "inir-companiond"
    private_relay = folder / "owned-relay.py"
    underlay_log = None
    trace = folder / "real-relay.private.jsonl"
    try:
        if not actor:
            report["reason"] = "native_wdotool_missing"
            return
        check = run([actor, "--help"], timeout=3)
        if check.returncode or b"backend" not in (check.stdout + check.stderr).lower():
            report["reason"] = "native_wdotool_backend_override_unverified"
            return
        private_relay.write_bytes((ROOT / RELAY).read_bytes())
        private_relay.chmod(0o700)
        build_env = dict(os.environ, CARGO_TARGET_DIR=str(folder / "cargo-target"))
        with (folder / "cargo-build.private.log").open("wb") as log:
            built = subprocess.run(
                [cargo, "build", "--locked", "--release",
                 "--manifest-path", str(ROOT / "native/Cargo.toml"),
                 "-p", "inir-companiond"],
                env=build_env, stdout=log, stderr=subprocess.STDOUT, timeout=900)
        bounded(folder / "cargo-build.private.log")
        if built.returncode != 0 or not binary.is_file():
            report["reason"] = "private_exact_rust_build_failed"
            return
        report["real_rust_binary_built"] = True
        root_env = dict(os.environ)
        underlay_folder = folder / "underlay"
        ushell, uenv = phase_config(underlay_folder, UNDERLAY, "underlay")
        underlay_proc, underlay_log = launch(underlay_folder, qs, dbus, ushell, uenv)
        def underlay_ready():
            return (underlay_proc.poll() is None
                    and bool(markers(underlay_log, "WULL_POINTER_UNDERLAY_QML_READY"))
                    and len(namespaced(niri_json(niri, "layers"),
                                       "hadalis:wull-pointer-underlay")) == 1)
        if not wait_for(underlay_ready, 15):
            report["reason"] = "underlay_layer_or_qml_unavailable"
            return

        # Verify identity again immediately before every native input event.
        def inject(point):
            verify_live = niri_json(niri, "outputs")
            if (os.environ.get("WAYLAND_DISPLAY")
                    == os.environ.get("WULL_PARENT_WAYLAND_DISPLAY")
                    or os.environ.get("NIRI_SOCKET")
                    == os.environ.get("WULL_PARENT_NIRI_SOCKET")
                    or not Path(os.environ["NIRI_SOCKET"]).is_socket()
                    or output not in verify_live):
                stop("nested_identity_lost_before_injection")
            env = dict(root_env)
            env["XDG_CURRENT_DESKTOP"] = "niri"
            move = run([actor, "--backend", "wlr-protocols", "mousemove",
                        str(point[0]), str(point[1])], env, 6)
            if move.returncode:
                stop("native_virtual_pointer_move_unavailable")
            time.sleep(.25)
            click = run([actor, "--backend", "wlr-protocols", "click", "1"],
                        env, 6)
            if click.returncode:
                stop("native_virtual_pointer_click_unavailable")
            time.sleep(.65)

        def underlay_count():
            return len(markers(underlay_log, "WULL_POINTER_UNDERLAY_PRESS "))
        config = json.loads((ROOT / "defaults/config.json").read_text())
        config["panelFamily"] = "abyss"
        config["enabledPanels"] = []
        config["abyss"]["companion"].update(
            {"enabled": False, "interactive": True, "output": output,
             "edge": "top", "along": 0.72, "size": 1,
             "soundEnabled": False})
        def start_production(label, enabled):
            state = folder / label
            configured = json.loads(json.dumps(config))
            configured["abyss"]["companion"]["enabled"] = enabled
            overlay = None
            if enabled:
                overlay = {"INIR_COMPANIOND": str(private_relay),
                           "WULL_PRIVATE_POINTER_SESSION": "isolated-nested-only",
                           "WULL_PARENT_WAYLAND_DISPLAY":
                               os.environ["WULL_PARENT_WAYLAND_DISPLAY"],
                           "WULL_PARENT_NIRI_SOCKET":
                               os.environ["WULL_PARENT_NIRI_SOCKET"],
                           "WULL_PRIVATE_POINTER_BINARY": str(binary),
                           "WULL_PRIVATE_POINTER_TRACE": str(trace),
                           "WULL_PRIVATE_POINTER_CHECKOUT": str(ROOT)}
            shell, env = phase_config(state, PRODUCTION, label, configured, overlay)
            proc, log = launch(state, qs, dbus, shell, env)
            def ready():
                return (proc.poll() is None
                        and bool(markers(log, "WULL_PRODUCTION_FIXTURE_READY"))
                        and len(namespaced(niri_json(niri, "layers"),
                                           "hadalis:abyss-perimeter")) == 1
                        and len(private_pids(binary)) == (1 if enabled else 0))
            if not wait_for(ready, 20):
                stop(label + "_actual_production_not_ready")
            return proc

        disabled_proc = start_production("disabled", False)
        before = underlay_count()
        try:
            inject(points["body_center"])
        except RuntimeError as e:
            report["reason"] = str(e)
            return
        disabled_pass = underlay_count() == before + 1 and not private_pids(binary)
        report["checks"].append({"case": "disabled_center_underlay_control",
                                 "status": "pass" if disabled_pass else "failed"})
        if not disabled_pass:
            report["status"] = "failed"
            report["reason"] = "disabled_underlay_control_failed"
            return
        owned_cleanup(disabled_proc, binary, private_relay)
        disabled_proc = None
        if not wait_for(lambda: not namespaced(niri_json(niri, "layers"),
                           "hadalis:abyss-perimeter"), 5):
            report["status"] = "failed"
            report["reason"] = "disabled_layer_not_cleaned"
            return
        enabled_proc = start_production("enabled", True)
        if not wait_for(lambda: "rust_present" in trace_kinds(trace), 7):
            report["reason"] = "real_companion_present_state_unconfirmed"
            return
        before = underlay_count()
        try:
            inject(points["outside_host_control"])
        except RuntimeError as e:
            report["reason"] = str(e)
            return
        exterior_pass = underlay_count() == before + 1
        report["checks"].append({"case": "enabled_exterior_underlay_control",
                                 "status": "pass" if exterior_pass else "failed"})
        if not exterior_pass:
            report["status"] = "failed"
            report["reason"] = "enabled_exterior_control_failed"
            return
        prior = trace_kinds(trace)
        before = underlay_count()
        try:
            inject(points["body_center"])
        except RuntimeError as e:
            report["reason"] = str(e)
            return
        def count(kind, rows):
            return rows.count(kind)
        after = trace_kinds(trace)
        clicked = count("real_bridge_click_received", after) == (
            count("real_bridge_click_received", prior) + 1)
        acked = count("rust_happy_pulse_ack", after) == (
            count("rust_happy_pulse_ack", prior) + 1)
        not_underlay = underlay_count() == before
        body_pass = clicked and acked and not_underlay
        report["checks"].append({
            "case": "enabled_body_actual_bridge_and_rust",
            "status": "pass" if body_pass else "failed",
            "underlay_not_clicked": not_underlay, "real_bridge_clicked": clicked,
            "real_rust_reacted": acked})
        if not body_pass:
            report["status"] = "failed"
            report["reason"] = "actual_wull_body_click_unproven"
            return
        # A diagnostic, NOT a pass-through gate for the current full-host mask.
        prior = trace_kinds(trace)
        before = underlay_count()
        try:
            inject(points["inside_host_outside_body"])
        except RuntimeError as e:
            report["reason"] = str(e)
            return
        current = trace_kinds(trace)
        margin_reached_underlay = underlay_count() == before + 1
        margin_clicked_body = count("real_bridge_click_received", current) > (
            count("real_bridge_click_received", prior))
        report["checks"].append({
            "case": "whole_host_empty_margin_observation",
            "status": "observed",
            "underlay_received": margin_reached_underlay,
            "unexpected_body_click": margin_clicked_body})
        report["status"] = "failed" if margin_clicked_body else "pass"
        report["reason"] = ("body_triggered_from_empty_host_margin"
                            if margin_clicked_body else None)
    except (OSError, ValueError, json.JSONDecodeError, subprocess.TimeoutExpired,
            RuntimeError) as exc:
        # No exception contents enter the published receipt.
        report["status"] = "inconclusive"
        report["reason"] = ("nested_child_bounded_diagnostic_unavailable"
                            if report["reason"] is None else report["reason"])
    finally:
        for proc in (disabled_proc, enabled_proc, underlay_proc):
            owned_cleanup(proc, binary, private_relay)
        if underlay_log:
            bounded(underlay_log)
        for name in ("disabled", "enabled"):
            logfile = folder / name / "quickshell.private.log"
            bounded(logfile)
        try:
            report["production_unmapped"] = not namespaced(
                niri_json(niri, "layers"), "hadalis:abyss-perimeter")
            report["underlay_unmapped"] = not namespaced(
                niri_json(niri, "layers"), "hadalis:wull-pointer-underlay")
        except (RuntimeError, OSError, ValueError):
            pass
        report["private_daemon_stopped"] = (
            not private_pids(binary) and not relay_pids(private_relay))
        if not all((report["production_unmapped"],
                    report["underlay_unmapped"],
                    report["private_daemon_stopped"])):
            report["status"] = "failed"
            report["reason"] = "owned_pointer_test_cleanup_unproven"
        final.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, OSError, ValueError) as e:
        print("WULL_POINTER_CHILD_STOP:", str(e).split(":")[0], file=sys.stderr)
        sys.exit(1)
