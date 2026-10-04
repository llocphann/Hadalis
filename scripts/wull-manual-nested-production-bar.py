#!/usr/bin/env python3
"""Capture an owned synthetic QML item using REAL AbyssField in owned nested Niri.

This is not a host desktop capture, live production bar/popup or visual PASS.
A different owned Niri/Wayland socket is checked before Qt is allowed to start.
Full host Niri outputs are compared byte-for-byte before and after cleanup.
Original 512x512 PNG and raw nested/Qt logs remain owner-private; Git receives
fixed gate categories plus source and PNG digest only.
"""
import hashlib
import json
import os
from pathlib import Path
import runpy
import shutil
import signal
import stat
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
ISOLATION = ROOT / "scripts/wull-nested-isolation-smoke.py"
STAGER = ROOT / "scripts/wull-manual-visual-matrix.py"
FIELD = ROOT / "scripts/wull-manual-real-field-canary.py"
FIXTURE = ROOT / "scripts/wull-fixtures/production-bar-field/shell.qml"
SHADER = ROOT / "modules/abyss/looks/AbyssField.frag.qsb"
MODES = {"--capture-gl": ("opengl", "rhi")}
ALLOWED = frozenset({
    "EXPLICIT_MODE_REQUIRED", "SOURCE_UNAVAILABLE",
    "NESTED_PREREQUISITES_UNAVAILABLE", "HOST_INVENTORY_UNAVAILABLE",
    "NESTED_PROCESS_UNAVAILABLE", "NESTED_SOCKET_UNQUALIFIED",
    "NESTED_OUTPUT_UNQUALIFIED", "NESTED_LAYERS_UNQUALIFIED",
    "QT_CHILD_UNQUALIFIED", "PRIVATE_QT_LOG_UNQUALIFIED",
    "QT_STAGE_UNQUALIFIED", "PRIVATE_PNG_UNQUALIFIED",
    "REAL_FIELD_PAINT_UNQUALIFIED", "HOST_INVENTORY_CHANGED",
    "NESTED_CLEANUP_UNQUALIFIED", "SOURCE_CHANGED_DURING_TEST",
    "PRIVATE_STATE_UNQUALIFIED", "ISOLATED_CAPTURE_INCONCLUSIVE",
    # These codes originate from previously reviewed real-field fixture.
    "WINDOW_NOT_BACKING", "SHEET_DIMENSIONS_INVALID",
    "FOUR_CELLS_UNAVAILABLE", "FIELD_FRAME_NOT_PRESENTED",
    "FIELD_GRAPHICS_API_UNSUPPORTED", "FIELD_EFFECT_UNQUALIFIED",
    "PRODUCTION_HOST_INVALID", "PRODUCTION_BODY_UNVERIFIED",
    "PRODUCTION_BODY_HIDDEN", "PRIVATE_OUTPUT_MISSING",
    "PRIVATE_GRAB_OR_SAVE_FAILED", "PRIVATE_GRAB_UNAVAILABLE",
    "PRIVATE_FIELD_TIMEOUT",
    "PANEL_SIDE_INVALID", "PANEL_WINDOW_UNQUALIFIED",
    "PANEL_SHADER_UNQUALIFIED", "PANEL_BAR_MODULE_UNQUALIFIED",
    "PANEL_SLOT_UNQUALIFIED", "PANEL_WULL_HOST_UNQUALIFIED",
    "PANEL_WULL_BODY_UNQUALIFIED", "PANEL_PRIVATE_PATH_MISSING",
    "PANEL_GRAB_FAILED", "PANEL_GRAB_UNAVAILABLE",
    "PANEL_FIXTURE_TIMEOUT", "PANEL_ALPHA_UNQUALIFIED",
})
EXPECTED_STAGES = ("BOOT", "BAR_LAYOUT_FIELD_AND_WULL_READY", "PNG_SAVED")


class Gate(Exception):
    pass


def need(ok, code):
    if not ok:
        raise Gate(code)


def scoped_host(env, iso, niri):
    display = env.get("WAYLAND_DISPLAY", "")
    host_ipc = env.get("NIRI_SOCKET", "")
    runtime_text = env.get("XDG_RUNTIME_DIR", "")
    need(runtime_text.startswith("/"), "NESTED_PREREQUISITES_UNAVAILABLE")
    runtime = Path(runtime_text)
    try:
        st = runtime.lstat()
    except OSError:
        raise Gate("NESTED_PREREQUISITES_UNAVAILABLE")
    need(stat.S_ISDIR(st.st_mode) and st.st_uid == os.getuid()
         and not stat.S_IMODE(st.st_mode) & 0o077,
         "NESTED_PREREQUISITES_UNAVAILABLE")
    cap = iso["CAPABILITY"]
    need(cap.assess(shutil.which, env, True,
                    lambda p: iso["socket_owned"](p, runtime))
         == "NESTED_PREREQUISITES_PRESENT_NOT_ISOLATION_PASS",
         "NESTED_PREREQUISITES_UNAVAILABLE")
    before = iso["command"]([niri, "msg", "-j", "outputs"],
                            dict(env, NIRI_SOCKET=host_ipc))
    need(before is not None and iso["outputs"](before) is not None,
         "HOST_INVENTORY_UNAVAILABLE")
    return runtime, display, host_ipc, before


def fixed_qt_result(log, exit_code, timed_out):
    if timed_out or exit_code != 0:
        # An allowlisted QML failure outranks the generic exit1 label.
        fallback = "QT_CHILD_UNQUALIFIED"
    else:
        fallback = "QT_STAGE_UNQUALIFIED"
    lines = log.splitlines()
    codes = [l.split("WULL_PANEL_REAL_FAIL=", 1)[1].strip()
             for l in lines if "WULL_PANEL_REAL_FAIL=" in l]
    if len(codes) == 1 and codes[0] in ALLOWED:
        return codes[0]
    stages = [l.split("WULL_PANEL_REAL_STAGE=", 1)[1].strip()
              for l in lines if "WULL_PANEL_REAL_STAGE=" in l]
    return "QUALIFIED" if not timed_out and exit_code == 0 \
        and not codes and stages == list(EXPECTED_STAGES) else fallback


def panel_alpha(alpha, width, height, side):
    # Independently witness actual painted Wull in a region far from the
    # single vertical clock module (seeded at ~0.26 of the owned output).
    need(width == 512 and height == 512 and len(alpha) == width*height,
         "PANEL_ALPHA_UNQUALIFIED")
    xa, xb = (36, 150) if side == "left" else (362, 476)
    core = sum(alpha[y*width+x] >= 24
               for y in range(270, 454)
               for x in range(xa, xb))
    ra, rb = (0, 24) if side == "left" else (488, 512)
    rim = sum(alpha[y*width+x] >= 24
              for y in range(245, 467)
              for x in range(ra, rb))
    need(core >= 300 and rim >= 20, "PANEL_ALPHA_UNQUALIFIED")
    return True


def launch_qt(private, runtime, display, ipc, core, side):
    assert side in ("left", "right")
    owned = private / side
    owned.mkdir(mode=0o700)
    qtprivate = owned / "qt"
    qtprivate.mkdir(mode=0o700)
    shell, xdg = core["staged"](qtprivate)
    shutil.copyfile(FIXTURE, shell / "shell.qml")
    config = json.loads((ROOT / "defaults/config.json").read_text())
    config["abyss"]["quality"] = "performance"
    config["bar"]["vertical"] = True
    config["bar"]["bottom"] = side == "right"
    config["abyss"]["modules"].update({
        "configured": True,
        "placements": [{"id": "clock", "kind": "clock",
                        "edge": side, "position": .26,
                        "enabled": True, "depth": 1}],
        "singleModuleExpansion": {side: "local"},
    })
    # The real AbyssBar instantiates its source clock module. No host module,
    # daemon or wallpaper is consulted; only this private config is changed.
    config["abyss"]["companion"]["enabled"] = False
    (xdg / "config" / "illogical-impulse" / "config.json").write_text(
        json.dumps(config), encoding="utf-8")
    png, logfile = owned / "bar.private.png", owned / "qt.private.log"
    child_env = core["private_env"](xdg, png)
    for key in ("WULL_VISUAL_MATRIX_PRIVATE_FILE", "DISPLAY",
                "WAYLAND_SOCKET"):
        child_env.pop(key, None)
    child_env.update({
        "QT_QPA_PLATFORM": "wayland",
        "QSG_RHI_BACKEND": "opengl",
        "QT_QUICK_BACKEND": "rhi",
        "XDG_RUNTIME_DIR": str(runtime),
        "WAYLAND_DISPLAY": display,
        "NIRI_SOCKET": ipc,
        "WULL_PANEL_SIDE": side,
        "WULL_PANEL_REAL_PRIVATE_PNG": str(png),
    })
    with logfile.open("xb") as stream:
        binary, dbus = core["preflight"]()
        child = subprocess.Popen(
            [dbus, "--", binary, "--path", str(shell / "shell.qml")],
            cwd=ROOT, env=child_env, stdin=subprocess.DEVNULL,
            stdout=stream, stderr=subprocess.STDOUT, start_new_session=True)
        code = None
        timed_out = False
        try:
            try:
                code = child.wait(timeout=19)
            except subprocess.TimeoutExpired:
                timed_out = True
        finally:
            if child.poll() is None:
                try:
                    os.killpg(child.pid, signal.SIGTERM)
                except ProcessLookupError:
                    pass
            try:
                child.wait(timeout=3)
            except subprocess.TimeoutExpired:
                if child.poll() is None:
                    try:
                        os.killpg(child.pid, signal.SIGKILL)
                    except ProcessLookupError:
                        pass
                child.wait(timeout=3)
    st = logfile.lstat()
    need(stat.S_ISREG(st.st_mode) and st.st_uid == os.getuid()
         and not stat.S_IMODE(st.st_mode) & 0o077
         and 0 < st.st_size <= 128*1024,
         "PRIVATE_QT_LOG_UNQUALIFIED")
    gate = fixed_qt_result(logfile.read_text(
        encoding="utf-8", errors="replace"), code, timed_out)
    need(gate == "QUALIFIED", gate)
    st = png.lstat()
    need(stat.S_ISREG(st.st_mode) and st.st_uid == os.getuid()
         and not stat.S_IMODE(st.st_mode) & 0o077
         and 0 < st.st_size <= 1024*1024,
         "PRIVATE_PNG_UNQUALIFIED")
    decoder = runpy.run_path(
        str(ROOT / "scripts/wull-private-painted-alpha-model.py"),
        run_name="nested_actual_bar_png_safe_decoder")
    try:
        raw = png.read_bytes()
        w, h, alpha = decoder["png_alpha"](raw)
        panel_alpha(alpha, w, h, side)
    except ValueError:
        raise Gate("PRIVATE_PNG_UNQUALIFIED")
    return hashlib.sha256(raw).hexdigest()


def capture(mode):
    os.umask(0o077)
    iso = runpy.run_path(str(ISOLATION), run_name="nested_field_isolation")
    core = runpy.run_path(str(STAGER), run_name="nested_field_stager")
    sha = core["source_sha"]()
    niri = shutil.which("niri")
    need(niri and FIXTURE.is_file() and SHADER.is_file()
         and 0 < SHADER.stat().st_size < 300 * 1024,
         "SOURCE_UNAVAILABLE")
    # Validated only at the static preflight. This live path does not prompt,
    # change user config, acquire root or publish Git/desktop screenshots.
    runtime, host_display, host_ipc, before = scoped_host(
        os.environ.copy(), iso, niri)
    state = Path(os.environ.get(
        "XDG_STATE_HOME", str(Path.home() / ".local/state"))).expanduser().resolve()
    base = state / "hadalis-wull-nested-bar-private"
    base.mkdir(mode=0o700, parents=True, exist_ok=True)
    st = base.lstat()
    need(stat.S_ISDIR(st.st_mode) and st.st_uid == os.getuid()
         and not stat.S_IMODE(st.st_mode) & 0o077,
         "PRIVATE_STATE_UNQUALIFIED")
    private = Path(tempfile.mkdtemp(prefix="bar-" + sha[:12] + "-",
                                    dir=base))
    proc = None
    cleaned, host_ok, digest = False, False, None
    reason = "ISOLATED_CAPTURE_INCONCLUSIVE"
    try:
        for folder in ("config", "data", "cache", "state"):
            (private / folder).mkdir(mode=0o700)
        config, log = private / "nested.kdl", private / "nested.private.log"
        config.write_text('layout {\n    background-color "#000000"\n}\n',
                          encoding="utf-8")
        nested_env = os.environ.copy()
        nested_env.pop("NIRI_SOCKET", None)
        nested_env.update({
            "NIRI_CONFIG": str(config), "WAYLAND_DISPLAY": host_display,
            **{"XDG_" + item.upper() + "_HOME": str(private / item)
               for item in ("config", "data", "cache", "state")},
        })
        with log.open("xb") as stream:
            proc = subprocess.Popen(
                [niri], env=nested_env, cwd=ROOT, stdin=subprocess.DEVNULL,
                stdout=stream, stderr=subprocess.STDOUT,
                start_new_session=True)
        deadline = time.monotonic() + 14
        readiness = None
        while time.monotonic() < deadline:
            if proc.poll() is not None:
                raise Gate("NESTED_PROCESS_UNAVAILABLE")
            st = log.lstat()
            need(stat.S_ISREG(st.st_mode) and st.st_uid == os.getuid()
                 and not stat.S_IMODE(st.st_mode) & 0o077
                 and st.st_size <= iso["MAX_CAPTURE"],
                 "NESTED_PROCESS_UNAVAILABLE")
            ids = iso["startup_ids"](log.read_text(
                encoding="utf-8", errors="replace"))
            if ids:
                display, ipc = ids
                need(display != host_display and ipc != host_ipc
                     and iso["socket_owned"](ipc, runtime)
                     and iso["socket_owned"](runtime / display, runtime),
                     "NESTED_SOCKET_UNQUALIFIED")
                only_nested = dict(os.environ, NIRI_SOCKET=ipc,
                                   WAYLAND_DISPLAY=display)
                output = iso["command"](
                    [niri, "msg", "-j", "outputs"], only_nested)
                if output is not None and iso["outputs"](output) == 1:
                    layer_data = iso["command"](
                        [niri, "msg", "-j", "layers"], only_nested)
                    need(layer_data is not None
                         and iso["layers"](layer_data),
                         "NESTED_LAYERS_UNQUALIFIED")
                    readiness = (display, ipc)
                    break
            time.sleep(.35)
        need(readiness is not None, "NESTED_OUTPUT_UNQUALIFIED")
        digests = {}
        for side in ("left", "right"):
            digests[side] = launch_qt(private, runtime, *readiness, core, side)
        reason = "NESTED_REAL_BAR_TWO_SIDES_PRIVATE_CAPTURED"
    except Gate as exc:
        reason = str(exc)
    except (OSError, ValueError, KeyError, subprocess.TimeoutExpired):
        reason = "ISOLATED_CAPTURE_INCONCLUSIVE"
    finally:
        cleaned = iso["stop_owned"](proc)
        after = iso["command"](
            [niri, "msg", "-j", "outputs"],
            dict(os.environ, NIRI_SOCKET=host_ipc))
        host_ok = after is not None and before == after
        # A failing run's disposable private logs contain no certifiable
        # image. Never delete any evidence before verifying compositor stop.
        if reason != "NESTED_REAL_BAR_TWO_SIDES_PRIVATE_CAPTURED" and cleaned:
            shutil.rmtree(private, ignore_errors=True)
    need(host_ok, "HOST_INVENTORY_CHANGED")
    need(cleaned, "NESTED_CLEANUP_UNQUALIFIED")
    need(reason == "NESTED_REAL_BAR_TWO_SIDES_PRIVATE_CAPTURED",
         reason if reason in ALLOWED else "ISOLATED_CAPTURE_INCONCLUSIVE")
    need(core["source_sha"]() == sha, "SOURCE_CHANGED_DURING_TEST")
    # No raw pixels, logs, paths, host names, GPU or socket identities escape.
    print("SOURCE_SHA=" + sha)
    print("LEFT_SHEET_SHA256=" + digests["left"])
    print("RIGHT_SHEET_SHA256=" + digests["right"])
    print("NESTED_ISOLATION=HOST_INVARIANT")
    print("REAL_ABYSS_BAR_CLOCK_AND_FIELD=LEFT_RIGHT_PAINTED")
    print("ORIGINAL_PRIVATE_IMAGE=NOT_PUBLISHED")
    print("REAL_HOST_PANEL_OR_POINTER=NOT_TESTED")
    print("GATE=NESTED_REAL_BAR_TWO_SIDES_PRIVATE_CAPTURED")


def main():
    if sys.argv[1:] not in (["--static-preflight"], ["--capture-gl"]):
        raise Gate("EXPLICIT_MODE_REQUIRED")
    if sys.argv[1:] == ["--static-preflight"]:
        need(all(p.is_file() for p in (ISOLATION, STAGER, FIELD, FIXTURE, SHADER)),
             "SOURCE_UNAVAILABLE")
        print("GATE=NESTED_BAR_STATIC_PREFLIGHT_PASS")
    else:
        capture("opengl")


if __name__ == "__main__":
    try:
        main()
    except (Gate, OSError, ValueError, KeyError,
            subprocess.TimeoutExpired) as exc:
        token = str(exc)
        print("GATE=" + (token if token in ALLOWED
                         else "ISOLATED_CAPTURE_INCONCLUSIVE"))
        raise SystemExit(1)
