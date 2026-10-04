#!/usr/bin/env python3
"""Owner-opt-in REAL nested Niri original Wull m025 attachment comparison.

Both cases have the same ORIGINAL BOTTOM×1.5 Wull and PRIVATE cradle .25.
Only PRIVATE perimeter host anchor changes from fixed physical thickness
to locally evaluated real Abyss shader-field inner surface boundary.
Images and raw logs stay local in one private owner-only state directory.
No screenshot, injection or fallback may target the inherited host display.
The output is source/safety classifications, NEVER automatic visual PASS.
"""
import json
import os
from pathlib import Path
import re
import resource
import runpy
import secrets
import shutil
import signal
import stat
import struct
import subprocess
import sys
import time
import zlib

ROOT = Path(__file__).resolve().parents[1]
BORROW = "scripts/wull-manual-nested-niri.py"
BORROW_BLOB = "fdee83774d671e8da3023798e9fb2cdb6312203a"
SHADOW = "scripts/wull-private-field-rim-attachment.py"
SHADOW_BLOB = "b7c2ac861ab11073540d113df86a1339c7f43e6e"
PRIOR_VISUAL = "scripts/wull-manual-private-nested-quarter-visual.py"
PRIOR_VISUAL_BLOB = "24e1a3d354d88a6187d3b08ed786c405ee1c2e6e"
LAYOUT = "modules/abyss/looks/AbyssLayout.js"
LAYOUT_BLOB = "f65d9c1922696d236fc0d3bfee735ad8df16924b"
FIELD = "modules/abyss/looks/AbyssField.frag"
FIELD_BLOB = "75af27a7220d364b2eb1700bb7b29cc19c8ae2bd"
STYLE = "modules/abyss/looks/AbyssStyle.qml"
STYLE_BLOB = "4cc05dbaf547a3eff366647cb388abe8c31af5d5"
FIELD_QML = "modules/abyss/looks/AbyssField.qml"
FIELD_QML_BLOB = "6b9588b1233748991f1dfeaa886879d51c7c0530"
FIELD_QSB = "modules/abyss/looks/AbyssField.frag.qsb"
FIELD_QSB_BLOB = "fe36c75ceb1bab6d4676e87512ee549b8d100f45"
BAR = "modules/abyss/bar/AbyssBar.qml"
BAR_BLOB = "b9d91627734d0cfdf3057d598f7ec600649be45c"
SURFACE = "modules/abyss/AbyssSurfaceController.qml"
SURFACE_BLOB = "1fbbe81d2c9f62827c2e6835600caec01e24227f"
PREFLIGHT = "scripts/wull-private-nested-visual-prerequisites.py"
PREFLIGHT_BLOB = "83367598877fa61804cdb84ef500fce744fbbb99"
FIXTURE = "scripts/wull-fixtures/production-layer/shell.qml"
FIXTURE_BLOB = "e16b6dcada26a27fd71cc670e30c55135401bcef"
PERIMETER = "modules/abyss/AbyssPerimeter.qml"
PERIMETER_BLOB = "a3cd2a7bfbdf32dac2c7e42057a1dfaaeea214ac"
COMPANION = "modules/abyss/companion/AbyssCompanion.qml"
COMPANION_BLOB = "b5b01835a282458eba0d0268396ae2c350d919d2"
DEFAULTS = "defaults/config.json"
DEFAULTS_BLOB = "e10d98c0f26d3e47c51cb8452bcd0d2cea735501"
RELAY = "scripts/wull-fixtures/pointer-underlay/companion-relay.py"
RELAY_BLOB = "7e450db1db23e3c250859b0271a655d6325f0bc8"
ORIGIN = "https://github.com/llocphann/Hadalis.git"
REQUIRED = (
    (BORROW, BORROW_BLOB), (SHADOW, SHADOW_BLOB),
    (PRIOR_VISUAL, PRIOR_VISUAL_BLOB), (LAYOUT, LAYOUT_BLOB),
    (FIELD, FIELD_BLOB), (STYLE, STYLE_BLOB),
    (FIELD_QML, FIELD_QML_BLOB), (FIELD_QSB, FIELD_QSB_BLOB),
    (BAR, BAR_BLOB), (SURFACE, SURFACE_BLOB),
    (PREFLIGHT, PREFLIGHT_BLOB), (FIXTURE, FIXTURE_BLOB),
    (PERIMETER, PERIMETER_BLOB), (COMPANION, COMPANION_BLOB),
    (DEFAULTS, DEFAULTS_BLOB), (RELAY, RELAY_BLOB),
)
MAX_LOG = 1024 * 1024
MAX_IMAGE = 24 * 1024 * 1024
TIMEOUT_READY = 24
TIMEOUT_SCREENSHOT = 16


class Stop(Exception):
    """Fixed diagnostics only: never propagate raw logs or private paths."""


def need(value, category):
    if not value:
        raise Stop(category)


def git(*args):
    x = subprocess.run(["git", *args], cwd=ROOT, stdin=subprocess.DEVNULL,
                       stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                       timeout=30, check=False, text=True,
                       env=dict(os.environ, GIT_TERMINAL_PROMPT="0",
                                GCM_INTERACTIVE="never",
                                GIT_ASKPASS="/bin/false"))
    need(x.returncode == 0, "SOURCE_AUDIT_GIT_FAILED")
    return x.stdout.strip()


def owner700(path):
    x = path.lstat()
    need(stat.S_ISDIR(x.st_mode) and not path.is_symlink()
         and x.st_uid == os.getuid() and stat.S_IMODE(x.st_mode) == 0o700,
         "UNTRUSTED_DISPOSABLE_OWNER_LAYOUT")


def audit_source():
    need(Path.cwd().resolve() == ROOT and ROOT.name == "repo"
         and ROOT.parent.name.startswith("wull-paint-canary."),
         "UNTRUSTED_DISPOSABLE_CLONE_LAYOUT")
    owner700(ROOT.parent)
    owner700(ROOT)
    need(git("symbolic-ref", "--short", "HEAD") == "dev"
         and git("remote", "get-url", "origin") == ORIGIN
         and git("remote", "get-url", "--push", "origin") == ORIGIN
         and not git("status", "--porcelain=v1", "--untracked-files=all"),
         "SOURCE_CLONE_UNVERIFIED")
    for path, sha in REQUIRED:
        need(git("rev-parse", "HEAD:" + path) == sha,
             "SOURCE_DEPENDENCY_MISMATCH")
    need(git("rev-parse", "HEAD:" + COMPANION) == COMPANION_BLOB,
         "PRODUCTION_WULL_CHANGED")
    return git("rev-parse", "HEAD")


def helpers():
    return runpy.run_path(str(ROOT / BORROW),
                          run_name="wull_nested_visual_reused_owner_only")


def check_host(env, lookup, is_socket):
    cap = runpy.run_path(str(ROOT / PREFLIGHT),
                         run_name="wull_nested_visual_inert_preflight")
    info = cap["prerequisites"](lookup, env, is_socket)
    need(info["capture_phase_ready"], "VISUAL_PREREQUISITES_UNAVAILABLE")
    runtime = Path(env["XDG_RUNTIME_DIR"]).resolve(strict=True)
    host_display = env["WAYLAND_DISPLAY"]
    host_ipc = Path(env["NIRI_SOCKET"]).resolve(strict=True)
    need(host_ipc.is_socket() and (runtime / host_display).is_socket()
         and host_ipc.parent == runtime, "HOST_SESSION_UNVERIFIED")
    return runtime, host_display, host_ipc


def parse_api(raw, kind):
    obj = json.loads(raw)
    if isinstance(obj, dict):
        obj = obj.get("Ok", obj)
    if isinstance(obj, dict):
        obj = obj.get("Outputs" if kind == "outputs" else "Layers",
                      obj.get(kind, obj))
    need((isinstance(obj, dict) if kind == "outputs" else
          isinstance(obj, list)), "NESTED_NIRI_API_SCHEMA_UNVERIFIED")
    return obj


def niri_json(binary, ipc, command):
    env = dict(os.environ, NIRI_SOCKET=str(ipc))
    p = subprocess.run([binary, "msg", "-j", command], env=env,
                       stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                       stderr=subprocess.DEVNULL, timeout=5)
    need(p.returncode == 0 and len(p.stdout) < MAX_LOG,
         "NESTED_NIRI_API_UNAVAILABLE")
    try:
        return parse_api(p.stdout, command)
    except (ValueError, TypeError, UnicodeDecodeError):
        raise Stop("NESTED_NIRI_API_SCHEMA_UNVERIFIED")


def active_outputs(obj):
    return {name: rec for name, rec in obj.items()
            if isinstance(rec, dict)
            and isinstance(rec.get("logical"), dict)}


def host_signature(obj):
    # Compare physical topology/geometry, never volatile compositor focus.
    result = []
    for name, rec in active_outputs(obj).items():
        logical = rec["logical"]
        result.append((name,) + tuple(logical.get(key) for key in
                                    ("x", "y", "width", "height",
                                     "scale", "transform")))
    return tuple(sorted(result))


def one_output(binary, ipc):
    outputs = active_outputs(niri_json(binary, ipc, "outputs"))
    need(len(outputs) == 1, "NESTED_ONE_OUTPUT_NOT_VERIFIED")
    name, data = next(iter(outputs.items()))
    logical = data["logical"]
    width = logical.get("width")
    height = logical.get("height")
    scale = logical.get("scale", data.get("scale"))
    need(type(name) is str and bool(name) and
         type(width) is int and type(height) is int
         and 800 <= width <= 8192 and 540 <= height <= 4320
         and type(scale) in (int, float) and float(scale) == 1.0,
         "NESTED_OUTPUT_GEOMETRY_OR_SCALE_UNVERIFIED")
    return name, width, height, 1.0


def native_layer(binary, ipc, name, *, count):
    items = niri_json(binary, ipc, "layers")
    selected = [x for x in items if isinstance(x, dict)
                and x.get("namespace") == "hadalis:abyss-perimeter"]
    if count == 0:
        need(not selected, "NESTED_PRODUCTION_LAYER_PREEXISTING")
        return
    need(len(selected) == 1 and selected[0].get("output") == name,
         "NESTED_ACTUAL_PERIMETER_LAYER_NOT_VERIFIED")
    need(str(selected[0].get("keyboard_interactivity", "")).lower()
         in ("none", "wlrkeyboardfocus.none"),
         "NESTED_UNEXPECTED_KEYBOARD_FOCUS")


def private_binaries(binary):
    root = str(binary.resolve())
    pids = []
    for item in Path("/proc").iterdir():
        if not item.name.isdigit():
            continue
        try:
            if item.stat().st_uid == os.getuid() and os.readlink(item / "exe") == root:
                pids.append(int(item.name))
        except (OSError, PermissionError):
            continue
    return pids


def private_children(private):
    needle = str(private.resolve()).encode()
    pids = []
    for entry in Path("/proc").iterdir():
        if not entry.name.isdigit():
            continue
        try:
            if entry.stat().st_uid != os.getuid():
                continue
            tokens = (entry / "cmdline").read_bytes().split(b"\0")
            if any(needle in token for token in tokens):
                pids.append(int(entry.name))
        except (OSError, PermissionError):
            continue
    return [pid for pid in pids if pid != os.getpid()]


def stop_owned(proc):
    if proc is None:
        return
    if proc.poll() is None:
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


def stop_private_strays(private, binary):
    # Never touch anything without the exact owned private folder or
    # the EXACT private Cargo executable identity, both already audited.
    for pid in private_children(private) + private_binaries(binary):
        try:
            os.kill(pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
    deadline = time.monotonic() + 4
    while time.monotonic() < deadline:
        pending = private_children(private) + private_binaries(binary)
        if not pending:
            return True
        time.sleep(.20)
    for pid in private_children(private) + private_binaries(binary):
        try:
            os.kill(pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
    time.sleep(.30)
    return not private_children(private) and not private_binaries(binary)


def secure_png(path, logical_size):
    st = path.lstat()
    need(stat.S_ISREG(st.st_mode) and st.st_uid == os.getuid()
         and stat.S_IMODE(st.st_mode) == 0o600
         and 64 <= st.st_size <= MAX_IMAGE, "NESTED_SCREENSHOT_UNSAFE")
    raw = path.read_bytes()
    need(raw[:8] == b"\x89PNG\r\n\x1a\n",
         "NESTED_SCREENSHOT_PNG_INVALID")
    pos = 8
    chunks = []
    width = height = depth = color = None
    finished = False
    while pos + 12 <= len(raw):
        length = struct.unpack_from(">I", raw, pos)[0]
        kind = raw[pos + 4:pos + 8]
        end = pos + 12 + length
        need(length <= MAX_IMAGE and end <= len(raw),
             "NESTED_SCREENSHOT_PNG_INVALID")
        payload = raw[pos + 8:pos + 8 + length]
        crc = struct.unpack_from(">I", raw, pos + 8 + length)[0]
        need(zlib.crc32(kind + payload) & 0xffffffff == crc,
             "NESTED_SCREENSHOT_PNG_INVALID")
        if not chunks:
            need(kind == b"IHDR" and length == 13,
                 "NESTED_SCREENSHOT_PNG_INVALID")
            width, height, depth, color, comp, filt, interlace = (
                struct.unpack(">IIBBBBB", payload))
            need((depth, color, comp, filt, interlace) in
                 ((8, 2, 0, 0, 0), (8, 6, 0, 0, 0)) and
                 (width, height) == logical_size and
                 1 <= width <= 8192 and 1 <= height <= 8192,
                 "NESTED_SCREENSHOT_DIMENSIONS_UNVERIFIED")
        else:
            need(kind != b"IHDR", "NESTED_SCREENSHOT_PNG_INVALID")
        chunks.append(kind)
        pos = end
        if kind == b"IEND":
            need(length == 0 and pos == len(raw) and
                 b"IDAT" in chunks and chunks[0] == b"IHDR",
                 "NESTED_SCREENSHOT_PNG_INVALID")
            finished = True
            break
    need(finished, "NESTED_SCREENSHOT_PNG_INVALID")


def fixed_config(output):
    cfg = json.loads((ROOT / DEFAULTS).read_text(encoding="utf-8"))
    need(isinstance(cfg, dict) and
         isinstance(cfg.get("abyss", {}).get("companion"), dict)
         and isinstance(cfg.get("bar"), dict),
         "DEFAULT_VISUAL_CONFIG_SCHEMA_CHANGED")
    cfg["panelFamily"] = "abyss"
    cfg["enabledPanels"] = ["abyssPerimeter", "abyssBar"]
    cfg["bar"]["bottom"] = True
    cfg["bar"]["vertical"] = False
    cfg["bar"]["autoHide"]["enable"] = False
    cfg["bar"]["screenList"] = [output]
    cfg["abyss"]["companion"].update(
        {"enabled": True, "output": output, "edge": "bottom",
         "along": 0.72, "size": 1.5, "interactive": False,
         "soundEnabled": False})
    # The same generated configuration is used in both sessions.
    return cfg


def stage_shell(private, mode, cfg, shadow):
    shell = private / mode / "shell"
    shell.mkdir(mode=0o700, parents=True)
    shadow["stage"](ROOT, shell, mode)
    for name in shadow["LINK_NAMES"]:
        (shell / name).symlink_to(ROOT / name)
    shutil.copyfile(ROOT / FIXTURE, shell / "shell.qml")
    xdg = private / mode / "xdg"
    for item in ("config", "cache", "data", "state"):
        (xdg / item).mkdir(parents=True, mode=0o700)
    path = xdg / "config" / "illogical-impulse"
    path.mkdir(mode=0o700)
    (path / "config.json").write_text(json.dumps(cfg) + "\n", encoding="utf-8")
    (path / "config.json").chmod(0o600)
    return shell, xdg


def private_qt_env(xdg, ipc, display, binary):
    env = dict(os.environ)
    for key in ("QS_CONFIG_PATH", "QS_CONFIG_NAME", "QS_MANIFEST",
                "INIR_COMPANIOND", "WAYLAND_SOCKET"):
        env.pop(key, None)
    env.update({
        "WAYLAND_DISPLAY": display, "NIRI_SOCKET": str(ipc),
        "INIR_COMPANIOND": str(binary),
        "XDG_CONFIG_HOME": str(xdg / "config"),
        "XDG_CACHE_HOME": str(xdg / "cache"),
        "XDG_DATA_HOME": str(xdg / "data"),
        "XDG_STATE_HOME": str(xdg / "state"),
        "QT_QPA_PLATFORM": "wayland", "QS_NO_RELOAD_POPUP": "1",
        "GIT_TERMINAL_PROMPT": "0",
    })
    return env


def bounded_log(path):
    if path.is_file() and path.stat().st_size > MAX_LOG:
        with path.open("rb") as f:
            head = f.read(MAX_LOG // 2)
            f.seek(-MAX_LOG // 2, os.SEEK_END)
            tail = f.read()
        path.write_bytes(head + b"\n[PRIVATE LOG MIDDLE OMITTED]\n" + tail)
        path.chmod(0o600)


def capture_once(niri, ipc, display, runtime, output, dims, qs, dbus,
                 grim, binary, private, mode, cfg, shadow, host):
    need(ipc != host[1] and display != host[0] and
         (runtime / display).is_socket() and ipc.is_socket(),
         "NESTED_IDENTITY_LOST_BEFORE_QT")
    native_layer(niri, ipc, output, count=0)
    shell, xdg = stage_shell(private, mode, cfg, shadow)
    env = private_qt_env(xdg, ipc, display, binary)
    proc = None
    log = private / mode / "qt.private.log"
    image = private / (mode + ".nested.private.png")
    try:
        with log.open("xb") as f:
            proc = subprocess.Popen(
                [dbus, "--", qs, "-n", "-p", str(shell), "--no-color"],
                env=env, stdin=subprocess.DEVNULL, stdout=f,
                stderr=subprocess.STDOUT, start_new_session=True)
        deadline = time.monotonic() + TIMEOUT_READY
        qualified = False
        while time.monotonic() < deadline:
            need(proc.poll() is None, "NESTED_VISUAL_QT_EARLY_EXIT")
            current = one_output(niri, ipc)
            need(current == (output, *dims, 1.0),
                 "NESTED_OUTPUT_CHANGED_DURING_QT")
            layers = niri_json(niri, ipc, "layers")
            present = [x for x in layers if isinstance(x, dict)
                       and x.get("namespace") == "hadalis:abyss-perimeter"]
            need(len(present) <= 1, "NESTED_DUPLICATE_PERIMETER_LAYER")
            if present:
                native_layer(niri, ipc, output, count=1)
            ready = ("WULL_PRODUCTION_FIXTURE_READY" in
                     log.read_text(encoding="utf-8", errors="replace")[-MAX_LOG:])
            if ready and present and len(private_binaries(binary)) == 1:
                qualified = True
                break
            time.sleep(.30)
        need(qualified, "NESTED_BAR_WULL_RUST_READINESS_UNPROVEN")
        # Allow actual compositor to draw, then verify all boundaries AGAIN.
        time.sleep(2.0)
        need(proc.poll() is None and
             len(private_binaries(binary)) == 1,
             "NESTED_QT_OR_PRIVATE_DAEMON_LOST")
        need(one_output(niri, ipc) == (output, *dims, 1.0),
             "NESTED_OUTPUT_CHANGED_BEFORE_SCREENSHOT")
        native_layer(niri, ipc, output, count=1)
        need(ipc != host[1] and display != host[0] and
             (runtime / display).is_socket() and ipc.is_socket(),
             "NESTED_ISOLATION_LOST_BEFORE_SCREENSHOT")
        capture_env = dict(os.environ, WAYLAND_DISPLAY=display,
                           NIRI_SOCKET=str(ipc),
                           XDG_RUNTIME_DIR=str(runtime))
        capture_env.pop("WAYLAND_SOCKET", None)
        # grim receives ONLY explicit reviewed nested output identifier.
        need(not image.exists() and
             capture_env["WAYLAND_DISPLAY"] != host[0] and
             capture_env["NIRI_SOCKET"] != str(host[1]),
             "NESTED_SCREENSHOT_TARGET_NOT_PRIVATE")
        result = subprocess.run(
            [grim, "-o", output, "-t", "png", str(image)],
            env=capture_env, stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            timeout=TIMEOUT_SCREENSHOT)
        need(result.returncode == 0 and image.exists(),
             "NESTED_GRIM_SCREENSHOT_UNAVAILABLE")
        image.chmod(0o600)
        secure_png(image, dims)
        return True
    finally:
        stop_owned(proc)
        bounded_log(log)
        need(stop_private_strays(private / mode, binary),
             "NESTED_QT_PRIVATE_CLEANUP_UNPROVEN")
        deadline = time.monotonic() + 5
        unmapped = False
        while time.monotonic() < deadline:
            try:
                native_layer(niri, ipc, output, count=0)
                unmapped = True
                break
            except Stop as exc:
                if str(exc) != "NESTED_PRODUCTION_LAYER_PREEXISTING":
                    raise
            time.sleep(.20)
        need(unmapped, "NESTED_PRODUCTION_LAYER_NOT_UNMAPPED")


def signal_stop(_sig, _frame):
    raise Stop("PRIVATE_VISUAL_INTERRUPTED")


def main():
    need(sys.argv[1:] == ["--acknowledge-owned-nested-field-rim-visual"],
         "EXPLICIT_NESTED_VISUAL_OPT_IN_REQUIRED")
    os.umask(0o077)
    signal.signal(signal.SIGTERM, signal_stop)
    signal.signal(signal.SIGINT, signal_stop)
    source = audit_source()
    niri = shutil.which("niri")
    qs = shutil.which("qs") or shutil.which("quickshell")
    cargo = shutil.which("cargo")
    dbus = shutil.which("dbus-run-session")
    grim = shutil.which("grim")
    runtime, host_display, host_ipc = check_host(
        os.environ, shutil.which, lambda path: Path(path).is_socket())
    need(all((niri, qs, cargo, dbus, grim)),
         "VISUAL_PREREQUISITES_UNAVAILABLE")
    host_outputs = host_signature(niri_json(niri, host_ipc, "outputs"))
    need(bool(host_outputs), "HOST_OUTPUT_INVENTORY_UNAVAILABLE")
    state = Path(os.environ.get(
        "XDG_STATE_HOME", str(Path.home() / ".local/state"))).expanduser()
    need(state.is_absolute() and not state.is_symlink(),
         "PRIVATE_STATE_ROOT_UNVERIFIED")
    state = state.resolve()
    need(ROOT != state and ROOT not in state.parents and
         state != ROOT.parent and ROOT.parent not in state.parents,
         "PRIVATE_STATE_OVERLAPS_CHECKOUT")
    private = state / "hadalis" / (
        "wull-nested-visual-" + secrets.token_hex(8))
    private.mkdir(parents=True, mode=0o700, exist_ok=False)
    private.chmod(0o700)
    nested = None
    nested_ipc = None
    binary = private / "cargo-target" / "release" / "inir-companiond"
    nested_log = private / "nested.private.log"
    phases = 0
    stop_clean = False
    try:
        # Import only exact reviewed helper's parsing functions.
        borrowed = helpers()
        shadow = runpy.run_path(
            str(ROOT / SHADOW), run_name="wull_owner_nested_private_shadow")
        check = runpy.run_path(
            str(ROOT / PREFLIGHT), run_name="wull_owner_nested_private_probe")
        need(check["prerequisites"](
            shutil.which, os.environ,
            lambda p: Path(p).is_socket())["capture_phase_ready"],
            "VISUAL_PREREQUISITES_UNAVAILABLE")
        build_log = private / "cargo-build.private.log"
        build_env = dict(os.environ, CARGO_TARGET_DIR=str(private / "cargo-target"),
                         GIT_TERMINAL_PROMPT="0", GCM_INTERACTIVE="never",
                         GIT_ASKPASS="/bin/false")
        try:
            with build_log.open("xb") as stream:
                try:
                    built = subprocess.run(
                        [cargo, "build", "--locked", "--release",
                         "--manifest-path", str(ROOT / "native/Cargo.toml"),
                         "-p", "inir-companiond"],
                        cwd=ROOT, env=build_env, stdin=subprocess.DEVNULL,
                        stdout=stream, stderr=subprocess.STDOUT, timeout=900)
                except subprocess.TimeoutExpired:
                    raise Stop("PRIVATE_RUST_BUILD_TIMEOUT")
        finally:
            bounded_log(build_log)
        need(built.returncode == 0 and binary.is_file() and
             not private_binaries(binary),
             "PRIVATE_RUST_BUILD_OR_BINARY_UNVERIFIED")
        nested_home = private / "nested"
        nested_home.mkdir(mode=0o700)
        cfg = nested_home / "nested.kdl"
        cfg.write_text(
            'layout {\n    background-color "#000000"\n}\n'
            'overview {\n    backdrop-color "#000000"\n}\n',
            encoding="utf-8")
        env = dict(os.environ)
        env.pop("NIRI_SOCKET", None)
        for key in ("config", "cache", "data", "state"):
            (nested_home / key).mkdir(mode=0o700)
        env.update({
            "NIRI_CONFIG": str(cfg),
            "XDG_CONFIG_HOME": str(nested_home / "config"),
            "XDG_CACHE_HOME": str(nested_home / "cache"),
            "XDG_DATA_HOME": str(nested_home / "data"),
            "XDG_STATE_HOME": str(nested_home / "state"),
            "WAYLAND_DISPLAY": host_display,
        })
        with nested_log.open("xb") as log:
            nested = subprocess.Popen([niri], env=env,
                stdin=subprocess.DEVNULL, stdout=log,
                stderr=subprocess.STDOUT, start_new_session=True)
        deadline = time.monotonic() + 24
        display = None
        while time.monotonic() < deadline:
            need(nested.poll() is None, "NESTED_NIRI_EARLY_EXIT")
            raw = nested_log.read_text(
                encoding="utf-8", errors="replace")[:MAX_LOG]
            candidate_display, candidate_ipc = borrowed["startup_identity"](raw)
            if candidate_display and candidate_ipc:
                dest = Path(candidate_ipc)
                if (candidate_display != host_display
                        and dest.is_absolute()
                        and dest.resolve().parent == runtime
                        and dest.is_socket()
                        and (runtime / candidate_display).is_socket()
                        and dest.resolve() != host_ipc):
                    nested_ipc = dest.resolve()
                    display = candidate_display
                    break
            time.sleep(.30)
        need(nested_ipc is not None and display is not None,
             "OWNED_NESTED_ENDPOINTS_NOT_VERIFIED")
        output, width, height, _ = one_output(niri, nested_ipc)
        native_layer(niri, nested_ipc, output, count=0)
        fixed = fixed_config(output)
        host = (host_display, host_ipc)
        # Two SEQUENTIAL fully independent real AbyssBar / original Wull
        # scenes; never interpret differences as same-instant pixels.
        for mode in ("screen_boundary_m025", "inner_field_rim_m025"):
            need(nested.poll() is None,
                 "OWNED_NESTED_COMPOSITOR_EXITED_BETWEEN_CASES")
            need(host_signature(niri_json(niri, host_ipc, "outputs"))
                 == host_outputs, "HOST_OUTPUT_TOPOLOGY_CHANGED")
            capture_once(niri, nested_ipc, display, runtime, output,
                         (width, height), qs, dbus, grim, binary, private,
                         mode, fixed, shadow, host)
            phases += 1
            print(mode.upper() + "_NESTED_FULL_IMAGE=CAPTURED",
                  flush=True)
        need(phases == 2, "NESTED_VISUAL_MATRIX_INCOMPLETE")
    finally:
        # Never leave the guest/owned Rust running after either result.
        stop_owned(nested)
        bounded_log(nested_log)
        stop_clean = stop_private_strays(private, binary)
        if nested_ipc is not None:
            deadline = time.monotonic() + 5
            while time.monotonic() < deadline and borrowed["alive_ipc"](nested_ipc):
                time.sleep(.20)
            stop_clean = stop_clean and not borrowed["alive_ipc"](nested_ipc)
        need(stop_clean, "OWNED_NESTED_CLEANUP_UNVERIFIED")
        need(host_signature(niri_json(niri, host_ipc, "outputs"))
             == host_outputs, "HOST_OUTPUT_INVENTORY_CHANGED")
        # Keep only local screenshots/bounded diagnostics; no large Cargo
        # release build cache from this one-use, owner-only trial.
        target_dir = private / "cargo-target"
        if target_dir.is_dir() and not target_dir.is_symlink():
            shutil.rmtree(target_dir)
    need(git("rev-parse", "HEAD") == source and
         not git("status", "--porcelain=v1", "--untracked-files=all"),
         "POSTRUN_SOURCE_CHANGED")
    print("SOURCE_SHA=" + source)
    print("NESTED_ONE_OUTPUT=YES")
    print("NESTED_DISTINCT_IPC_AND_WAYLAND=YES")
    print("ORIGINAL_REAL_ABYSSBAR_AND_WULL=SOURCE_PINNED")
    print("BOTH_CASES_ORIGINAL_CRADLE_M025=YES")
    print("ANCHOR_COMPARISON=SCREEN_FIXED_VS_LOCAL_ABYSS_FIELD")
    print("TWO_SEQUENTIAL_NESTED_CAPTURES=YES")
    print("SAME_INSTANT_PIXEL_COMPARISON=NOT_TESTED")
    print("DYNAMIC_WAVE_ATTACHMENT=NOT_TESTED")
    print("FOUR_EDGE_ATTACHMENT=NOT_TESTED")
    print("REAL_PANEL_VISUAL_CONNECTION=OWNER_REVIEW_REQUIRED")
    print("COMPOSITOR_POINTER_AND_POPUP=NOT_TESTED")
    print("PRODUCTION_MASK_CHANGED=NO")
    print("PRIVATE_CAPTURES_LOCAL_DIR=" + str(private))
    print("GATE=NESTED_PRIVATE_FIELD_RIM_CAPTURES_READY")


if __name__ == "__main__":
    try:
        main()
    except (Stop, OSError, ValueError, KeyError, TypeError,
            subprocess.TimeoutExpired) as exc:
        # Opaque owner-local paths and raw exceptions are never emitted.
        known = {
            "EXPLICIT_NESTED_VISUAL_OPT_IN_REQUIRED",
            "UNTRUSTED_DISPOSABLE_CLONE_LAYOUT",
            "UNTRUSTED_DISPOSABLE_OWNER_LAYOUT",
            "SOURCE_AUDIT_GIT_FAILED", "SOURCE_CLONE_UNVERIFIED",
            "SOURCE_DEPENDENCY_MISMATCH", "PRODUCTION_WULL_CHANGED",
            "VISUAL_PREREQUISITES_UNAVAILABLE", "HOST_SESSION_UNVERIFIED",
            "NESTED_NIRI_API_SCHEMA_UNVERIFIED", "NESTED_NIRI_API_UNAVAILABLE",
            "NESTED_ONE_OUTPUT_NOT_VERIFIED",
            "NESTED_OUTPUT_GEOMETRY_OR_SCALE_UNVERIFIED",
            "NESTED_PRODUCTION_LAYER_PREEXISTING",
            "NESTED_ACTUAL_PERIMETER_LAYER_NOT_VERIFIED",
            "NESTED_UNEXPECTED_KEYBOARD_FOCUS",
            "NESTED_SCREENSHOT_UNSAFE", "NESTED_SCREENSHOT_PNG_INVALID",
            "NESTED_SCREENSHOT_DIMENSIONS_UNVERIFIED",
            "DEFAULT_VISUAL_CONFIG_SCHEMA_CHANGED",
            "NESTED_IDENTITY_LOST_BEFORE_QT", "NESTED_VISUAL_QT_EARLY_EXIT",
            "NESTED_OUTPUT_CHANGED_DURING_QT",
            "NESTED_BAR_WULL_RUST_READINESS_UNPROVEN",
            "NESTED_QT_OR_PRIVATE_DAEMON_LOST",
            "NESTED_OUTPUT_CHANGED_BEFORE_SCREENSHOT",
            "NESTED_ISOLATION_LOST_BEFORE_SCREENSHOT",
            "NESTED_GRIM_SCREENSHOT_UNAVAILABLE",
            "NESTED_SCREENSHOT_TARGET_NOT_PRIVATE",
            "NESTED_DUPLICATE_PERIMETER_LAYER",
            "NESTED_PRODUCTION_LAYER_NOT_UNMAPPED",
            "NESTED_QT_PRIVATE_CLEANUP_UNPROVEN", "PRIVATE_VISUAL_INTERRUPTED",
            "PRIVATE_STATE_ROOT_UNVERIFIED", "PRIVATE_STATE_OVERLAPS_CHECKOUT",
            "PRIVATE_RUST_BUILD_OR_BINARY_UNVERIFIED",
            "PRIVATE_RUST_BUILD_TIMEOUT",
            "NESTED_NIRI_EARLY_EXIT", "OWNED_NESTED_ENDPOINTS_NOT_VERIFIED",
            "OWNED_NESTED_COMPOSITOR_EXITED_BETWEEN_CASES",
            "HOST_OUTPUT_TOPOLOGY_CHANGED", "NESTED_VISUAL_MATRIX_INCOMPLETE",
            "OWNED_NESTED_CLEANUP_UNVERIFIED",
            "HOST_OUTPUT_INVENTORY_CHANGED", "POSTRUN_SOURCE_CHANGED",
        }
        print("GATE=" + (str(exc) if str(exc) in known
                         else "NESTED_PRIVATE_VISUAL_UNQUALIFIED"))
        raise SystemExit(1)
