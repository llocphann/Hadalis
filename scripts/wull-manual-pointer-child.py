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


def output_geometry_signature(outputs, name):
    """Strict single-output logical geometry/scale identity, never publish raw."""
    if not isinstance(outputs, dict) or len(outputs) != 1 or name not in outputs:
        stop("nested_output_topology_changed_before_injection")
    current = outputs[name]
    if not isinstance(current, dict) or not isinstance(current.get("logical"), dict):
        stop("nested_output_geometry_unavailable_before_injection")
    logical = current["logical"]
    fields = ("x", "y", "width", "height")
    if any(type(logical.get(field)) is not int for field in fields):
        stop("nested_output_geometry_unavailable_before_injection")
    if not (logical["x"] == logical["y"] == 0
            and logical["width"] >= 480 and logical["height"] >= 240):
        stop("nested_output_geometry_invalid_before_injection")
    return (tuple(logical[field] for field in fields),
            current.get("scale"), current.get("current_mode"))


def namespaced(layers, name):
    return [x for x in layers if isinstance(x, dict)
            and x.get("namespace") == name]


def no_keyboard_focus(items):
    return bool(items) and all(
        str(item.get("keyboard_interactivity", "")).lower()
        in ("none", "wlrkeyboardfocus.none") for item in items)


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
                             or not isinstance(outputs[0][1].get("height"), int)
                             or outputs[0][1].get("x") != 0
                             or outputs[0][1].get("y") != 0):
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
    deadline = time.monotonic() + 4
    while time.monotonic() < deadline:
        if not private_pids(exact_binary) and not relay_pids(private_relay):
            break
        time.sleep(.20)
    # If an owned private helper ignored TERM, escalate only after rechecking
    # its unique private executable/relay path; never target a group by stale ID.
    for pid in private_pids(exact_binary) + relay_pids(private_relay):
        try:
            os.kill(pid, signal.SIGKILL)
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


def underlay_target_status(path, before, requested, *, tolerance=6):
    """Compare ONE real underlay hit with the requested nested-output point.

    Full-output underlay event COUNT alone cannot prove cursor positioning.
    Return classifications only; private x/y stay in the private QML log.
    This parser never injects input or changes production components.
    """
    if (not isinstance(before, int) or isinstance(before, bool)
            or before < 0 or not isinstance(requested, (tuple, list))
            or len(requested) != 2
            or not all(isinstance(x, int) and not isinstance(x, bool)
                       for x in requested)
            or not isinstance(tolerance, int) or not 0 <= tolerance <= 10):
        stop("invalid_pointer_witness_arguments")
    observed = markers(path, "WULL_POINTER_UNDERLAY_PRESS ")
    delta = observed[before:]
    if not delta:
        return "no_click"
    if len(delta) != 1:
        return "ambiguous_multiple_clicks"
    try:
        entry, _ = json.JSONDecoder().raw_decode(delta[0].strip())
    except (ValueError, TypeError):
        return "witness_record_unparseable"
    if (not isinstance(entry, dict) or
            not all(isinstance(entry.get(key), int)
                    and not isinstance(entry[key], bool)
                    for key in ("x", "y", "button")) or
            entry["button"] != 1):
        return "witness_record_unparseable"
    return ("matched" if abs(entry["x"] - requested[0]) <= tolerance
            and abs(entry["y"] - requested[1]) <= tolerance
            else "off_target")


def left_pre_body_margin_decision(alignment, unexpected_activation):
    """Fail closed: a real aligned underlay event is mandatory before body."""
    if alignment not in (
            "matched", "no_click", "off_target",
            "ambiguous_multiple_clicks", "witness_record_unparseable"
    ) or type(unexpected_activation) is not bool:
        stop("invalid_left_pre_body_witness")
    if alignment != "matched":
        return ("inconclusive", "left_pre_body_margin_pointer_unverified")
    if unexpected_activation:
        return ("failed", "left_pre_body_margin_false_body_activation")
    return ("pass", None)


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


def phase_config(folder, fixture, name, config=None, env_add=None,
                 *, candidate_mask=False):
    shell = folder / "shell"
    shell.mkdir(parents=True)
    if candidate_mask and fixture != PRODUCTION:
        stop("candidate_shadow_requires_real_production_fixture")
    if fixture == PRODUCTION:
        for item in ("modules", "services", "GlobalStates.qml", "qmldir",
                     "assets", "scripts", "defaults", "translations"):
            if item == "modules" and candidate_mask:
                candidate = __import__("runpy").run_path(
                    str(ROOT / "scripts/wull-private-mask-candidate.py"),
                    run_name="private_nested_mask_shadow_import_only")
                candidate["stage_candidate_modules"](ROOT, shell)
            else:
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


def pointer_commands(actor, kind, point):
    """Pure command planner; the caller verifies the nested socket EACH step.

    wlrctl has relative motion only. A bounded far-negative movement is a
    candidate origin reset for a ONE-output private nested compositor,
    not geometry proof; real underlay and Rust controls decide acceptance.
    """
    x, y = point
    if (not isinstance(x, int) or not isinstance(y, int)
            or x < 0 or y < 0 or x >= 8192 or y >= 8192):
        stop("unsafe_pointer_target")
    if kind == "wdotool":
        return [
            [actor, "--backend", "wlr-protocols", "mousemove",
             str(x), str(y)],
            [actor, "--backend", "wlr-protocols", "click", "1"]
        ]
    if kind == "wlrctl":
        return [
            [actor, "pointer", "move", "-8192", "-8192"],
            [actor, "pointer", "move", str(x), str(y)],
            [actor, "pointer", "click", "left"]
        ]
    stop("unreviewed_pointer_backend")


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
    # Prefer deterministic absolute wdotool. If it is unavailable,
    # wlrctl is a strictly native-protocol, *relative-only* candidate.
    # Its actual target MUST be independently corroborated by controls.
    wdotool = shutil.which("wdotool")
    wlrctl = shutil.which("wlrctl")
    actor = wdotool or wlrctl
    actor_kind = "wdotool" if wdotool else "wlrctl" if wlrctl else None
    if not all((niri, qs, dbus, cargo)):
        stop("required_nested_test_dependency_unavailable")
    output, width, height = verify_isolation(niri)
    original_geometry = output_geometry_signature(
        niri_json(niri, "outputs"), output)
    selected_mode = os.environ.get("WULL_PRIVATE_POINTER_MODE", "")
    if selected_mode not in (
            "", "candidate-mask", "candidate-mask-bottom",
            "candidate-mask-right", "candidate-mask-left"):
        stop("unreviewed_pointer_probe_mode")
    candidate_mode = selected_mode != ""
    selected_edge = (
        "bottom" if selected_mode == "candidate-mask-bottom" else
        "right" if selected_mode == "candidate-mask-right" else
        "left" if selected_mode == "candidate-mask-left" else "top")
    helper = __import__("runpy").run_path(
        str(ROOT / "scripts/wull-pointer-targets.py"),
        run_name="wull_pointer_child_only")
    points = helper["all_edge_targets"](width, height, selected_edge)
    report = {"status": "inconclusive", "reason": None, "checks": [],
              "nested_verified": True, "underlay_unmapped": False,
              "production_unmapped": False, "private_daemon_stopped": False,
              "real_rust_binary_built": False,
              "injection_backend": (
                  "forced_wlr_protocols_wdotool" if actor_kind == "wdotool"
                  else "native_relative_wlrctl_unverified" if actor_kind == "wlrctl"
                  else "not_available"),
              "whole_host_mask_changed": False,
              "private_candidate_mask_tested": False}
    final = folder / "pointer-child.private-summary.json"
    underlay_proc = disabled_proc = enabled_proc = None
    binary = folder / "cargo-target" / "release" / "inir-companiond"
    private_relay = folder / "owned-relay.py"
    underlay_log = None
    trace = folder / "real-relay.private.jsonl"
    try:
        if not actor:
            report["reason"] = "native_pointer_cli_missing"
            return
        # An A/B mask comparison requires native absolute coordinates.
        if candidate_mode and actor_kind != "wdotool":
            report["reason"] = "candidate_comparison_requires_absolute_native_pointer"
            return
        check = run([actor, "--help"], timeout=3)
        help_text = (check.stdout + check.stderr).lower()
        if check.returncode or (
                actor_kind == "wdotool" and b"backend" not in help_text) or (
                actor_kind == "wlrctl" and b"pointer" not in help_text):
            report["reason"] = "native_pointer_cli_contract_unverified"
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
                                       "hadalis:wull-pointer-underlay")) == 1
                    and no_keyboard_focus(namespaced(
                        niri_json(niri, "layers"),
                        "hadalis:wull-pointer-underlay")))
        if not wait_for(underlay_ready, 15):
            report["reason"] = "underlay_layer_or_qml_unavailable"
            return

        # NEVER inject on the inherited real host compositor. The child
        # observes the reviewed private compositor again before EACH action.
        def inject(point):
            env = dict(root_env)
            env["XDG_CURRENT_DESKTOP"] = "niri"
            commands = pointer_commands(actor, actor_kind, point)
            for index, command in enumerate(commands):
                verify_live = niri_json(niri, "outputs")
                if (os.environ.get("WAYLAND_DISPLAY")
                        == os.environ.get("WULL_PARENT_WAYLAND_DISPLAY")
                        or os.environ.get("NIRI_SOCKET")
                        == os.environ.get("WULL_PARENT_NIRI_SOCKET")
                        or not Path(os.environ["NIRI_SOCKET"]).is_socket()
                        or not (Path(os.environ["XDG_RUNTIME_DIR"])
                                / os.environ["WAYLAND_DISPLAY"]).is_socket()
                        or output not in verify_live):
                    stop("nested_identity_lost_before_injection")
                if output_geometry_signature(verify_live, output) != original_geometry:
                    stop("nested_output_geometry_changed_before_injection")
                result = run(command, env, 6)
                if result.returncode:
                    stop("native_virtual_pointer_command_unavailable")
                time.sleep(.25 if index < len(commands) - 1 else .65)

        def underlay_count():
            return len(markers(underlay_log, "WULL_POINTER_UNDERLAY_PRESS "))
        config = json.loads((ROOT / "defaults/config.json").read_text())
        config["panelFamily"] = "abyss"
        config["enabledPanels"] = []
        config["abyss"]["companion"].update(
            {"enabled": False, "interactive": True, "output": output,
             "edge": selected_edge, "along": 0.72, "size": 1,
             "soundEnabled": False})
        def start_production(label, enabled, *, candidate=False,
                             trace_path=None):
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
                           "WULL_PRIVATE_POINTER_TRACE":
                               str(trace_path if trace_path is not None else trace),
                           "WULL_PRIVATE_POINTER_CHECKOUT": str(ROOT)}
            shell, env = phase_config(
                state, PRODUCTION, label, configured, overlay,
                candidate_mask=candidate)
            proc, log = launch(state, qs, dbus, shell, env)
            def ready():
                return (proc.poll() is None
                        and bool(markers(log, "WULL_PRODUCTION_FIXTURE_READY"))
                        and len(namespaced(niri_json(niri, "layers"),
                                           "hadalis:abyss-perimeter")) == 1
                        and no_keyboard_focus(namespaced(
                            niri_json(niri, "layers"),
                            "hadalis:abyss-perimeter"))
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
        disabled_hit = underlay_target_status(
            underlay_log, before, points["body_center"])
        disabled_pass = disabled_hit == "matched" and not private_pids(binary)
        report["checks"].append({
            "case": "disabled_center_underlay_control",
            "status": "pass" if disabled_pass else "inconclusive",
            "target_alignment": disabled_hit})
        if not disabled_pass:
            report["status"] = "inconclusive"
            report["reason"] = "disabled_pointer_target_unverified"
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
        exterior_hit = underlay_target_status(
            underlay_log, before, points["outside_host_control"])
        exterior_pass = exterior_hit == "matched"
        report["checks"].append({
            "case": "enabled_exterior_underlay_control",
            "status": "pass" if exterior_pass else "inconclusive",
            "target_alignment": exterior_hit})
        if not exterior_pass:
            report["status"] = "inconclusive"
            report["reason"] = "exterior_pointer_target_unverified"
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
        body_underlay_hit = underlay_target_status(
            underlay_log, before, points["body_center"])
        not_underlay = body_underlay_hit == "no_click"
        body_pass = clicked and acked and not_underlay
        ambiguous_target = body_underlay_hit not in ("no_click", "matched")
        report["checks"].append({
            "case": "enabled_body_actual_bridge_and_rust",
            "status": ("pass" if body_pass else
                       "inconclusive" if ambiguous_target else "failed"),
            "underlay_target_alignment": body_underlay_hit,
            "underlay_not_clicked": not_underlay,
            "real_bridge_clicked": clicked,
            "real_rust_reacted": acked})
        if not body_pass:
            report["status"] = "inconclusive" if ambiguous_target else "failed"
            report["reason"] = ("body_pointer_target_unverified"
                                if ambiguous_target else
                                "actual_wull_body_click_unproven")
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
        report["status"] = (
            "inconclusive" if margin_clicked_body and actor_kind == "wlrctl"
            else "failed" if margin_clicked_body else "pass"
        )
        report["reason"] = (
            "relative_empty_margin_pointer_target_unverified"
            if margin_clicked_body and actor_kind == "wlrctl"
            else "body_triggered_from_empty_host_margin"
            if margin_clicked_body else None
        )
        if candidate_mode:
            # Compare baseline and PRIVATE source-shadow mask on the SAME
            # verified nested Niri output, never mutate the checkout.
            if report["status"] != "pass":
                report["reason"] = "baseline_pointer_control_not_qualified"
                return
            if margin_reached_underlay:
                report["status"] = "inconclusive"
                report["reason"] = "baseline_margin_already_passed_through"
                return
            owned_cleanup(enabled_proc, binary, private_relay)
            enabled_proc = None
            if not wait_for(
                    lambda: not namespaced(niri_json(niri, "layers"),
                                           "hadalis:abyss-perimeter")
                    and not private_pids(binary)
                    and not relay_pids(private_relay), 6):
                report["status"] = "failed"
                report["reason"] = "baseline_to_candidate_cleanup_unproven"
                return
            # The additional post-unmap witness shares the SAME requested
            # exterior point with the baseline and upcoming candidate.
            # Its observed event discriminates pointer drift that started
            # before the private candidate's new layer was mapped.
            before = underlay_count()
            try:
                inject(points["outside_host_control"])
            except RuntimeError as e:
                report["status"] = "inconclusive"
                report["reason"] = str(e)
                return
            after_unmap = underlay_target_status(
                underlay_log, before, points["outside_host_control"])
            report["checks"].append({
                "case": "after_baseline_unmap_exterior_underlay_control",
                "status": "pass" if after_unmap == "matched"
                          else "inconclusive",
                "target_alignment": after_unmap})
            if after_unmap != "matched":
                report["status"] = "inconclusive"
                report["reason"] = "post_baseline_unmap_pointer_target_unverified"
                return
            candidate_trace = folder / "candidate-relay.private.jsonl"
            enabled_proc = start_production(
                "candidate", True, candidate=True, trace_path=candidate_trace)
            report["private_candidate_mask_tested"] = True
            if not wait_for(
                    lambda: "rust_present" in trace_kinds(candidate_trace), 7):
                report["status"] = "inconclusive"
                report["reason"] = "candidate_rust_present_unconfirmed"
                return

            before = underlay_count()
            inject(points["outside_host_control"])
            candidate_exterior = underlay_target_status(
                underlay_log, before, points["outside_host_control"])
            report["checks"].append({
                "case": "candidate_exterior_underlay_control",
                "status": "pass" if candidate_exterior == "matched"
                          else "inconclusive",
                "target_alignment": candidate_exterior})
            if candidate_exterior != "matched":
                report["status"] = "inconclusive"
                report["reason"] = "candidate_exterior_pointer_unverified"
                return

            # LEFT-ONLY differential: try the SAME source-pinned empty
            # margin BEFORE the candidate's first body click. The original
            # body -> final-margin transition below is NOT interrupted.
            # A miss here implicates the exterior -> margin phase; if this
            # passes but the original final margin misses after the body,
            # the transient arose at a later phase. Neither proves cause.
            if selected_edge == "left":
                prior_left = trace_kinds(candidate_trace)
                before_left = underlay_count()
                inject(points["inside_host_outside_body"])
                left_pre_body_alignment = underlay_target_status(
                    underlay_log, before_left,
                    points["inside_host_outside_body"])
                after_left = trace_kinds(candidate_trace)
                left_pre_body_activation = (
                    after_left.count("real_bridge_click_received")
                    != prior_left.count("real_bridge_click_received")
                    or after_left.count("rust_happy_pulse_ack")
                    != prior_left.count("rust_happy_pulse_ack"))
                left_status, left_reason = left_pre_body_margin_decision(
                    left_pre_body_alignment, left_pre_body_activation)
                report["checks"].append({
                    "case": "candidate_left_margin_before_body_control",
                    "status": left_status,
                    "target_alignment": left_pre_body_alignment,
                    "unexpected_body_click": left_pre_body_activation})
                if left_status != "pass":
                    report["status"] = left_status
                    report["reason"] = left_reason
                    return

            prior = trace_kinds(candidate_trace)
            before = underlay_count()
            inject(points["body_center"])
            current = trace_kinds(candidate_trace)
            candidate_hit = underlay_target_status(
                underlay_log, before, points["body_center"])
            candidate_bridge = current.count("real_bridge_click_received") == (
                prior.count("real_bridge_click_received") + 1)
            candidate_rust = current.count("rust_happy_pulse_ack") == (
                prior.count("rust_happy_pulse_ack") + 1)
            candidate_body = (candidate_hit == "no_click"
                              and candidate_bridge and candidate_rust)
            report["checks"].append({
                "case": "candidate_body_real_bridge_and_rust",
                "status": "pass" if candidate_body else (
                    "inconclusive" if candidate_hit not in ("no_click", "matched")
                    else "failed"),
                "underlay_target_alignment": candidate_hit,
                "real_bridge_clicked": candidate_bridge,
                "real_rust_reacted": candidate_rust})
            if not candidate_body:
                report["status"] = (
                    "inconclusive" if candidate_hit not in ("no_click", "matched")
                    else "failed")
                report["reason"] = "candidate_body_activation_unproven"
                return

            prior = trace_kinds(candidate_trace)
            before = underlay_count()
            inject(points["inside_host_outside_body"])
            current = trace_kinds(candidate_trace)
            candidate_margin = underlay_target_status(
                underlay_log, before, points["inside_host_outside_body"])
            extra_activation = (
                current.count("real_bridge_click_received")
                != prior.count("real_bridge_click_received"))
            candidate_pass = (
                candidate_margin == "matched" and not extra_activation)
            report["checks"].append({
                "case": "candidate_empty_margin_pass_through",
                "status": "pass" if candidate_pass else (
                    "inconclusive" if candidate_margin not in ("matched", "no_click")
                    else "failed"),
                "target_alignment": candidate_margin,
                "unexpected_body_click": extra_activation})
            report["status"] = (
                "pass" if candidate_pass else
                "inconclusive" if candidate_margin not in ("matched", "no_click")
                else "failed")
            report["reason"] = (
                None if candidate_pass else
                "candidate_margin_target_unverified"
                if candidate_margin not in ("matched", "no_click")
                else "candidate_margin_pass_through_unproven")
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
        for name in ("disabled", "enabled", "candidate"):
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
