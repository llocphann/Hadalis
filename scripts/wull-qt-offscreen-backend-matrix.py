#!/usr/bin/env python3
"""Pure environmental diagnostic: three 128x96 owned Qt offscreen windows.

No Wull, shader, wallpaper, desktop screenshot or Git mutation. The only
public output is a fixed D/G/S (default/opengl/software) backing matrix.
Raw Qt logs stay private until discarded; no paths, GPU IDs, config or
journal content enter the worker's stdout/Git receipt.
"""
import os
from pathlib import Path
import runpy
import shutil
import signal
import stat
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / "scripts/wull-fixtures/qt-backend-probe/shell.qml"
BORROW = ROOT / "scripts/wull-manual-visual-matrix.py"
MODES = ("default", "opengl", "software")


def parse_private_stage(text, exit_code, timed_out):
    """The parser can never return raw diagnostic content."""
    if timed_out or exit_code != 0 or type(text) is not str:
        return "X"
    markers = [part.split("WULL_BACKEND_PROBE=", 1)[1].strip()
               for part in text.splitlines() if "WULL_BACKEND_PROBE=" in part]
    return ("1" if markers == ["BACKING"] else
            "0" if markers == ["NO_BACKING"] else "X")


def probe(mode, binaries, borrowed, workspace):
    shell, xdg = borrowed["staged"](workspace)
    shutil.copyfile(FIXTURE, shell / "shell.qml")
    env = borrowed["private_env"](xdg, workspace / "never-created.png")
    for name in ("QSG_RHI_BACKEND", "QT_QUICK_BACKEND",
                 "WULL_VISUAL_MATRIX_PRIVATE_FILE", "WULL_CAPTURE_OUTPUT"):
        env.pop(name, None)
    if mode == "opengl":
        env.update(QSG_RHI_BACKEND="opengl", QT_QUICK_BACKEND="rhi")
    elif mode == "software":
        env["QT_QUICK_BACKEND"] = "software"
    stream_path = workspace / "private-qt.log"
    with stream_path.open("xb") as stream:
        proc = subprocess.Popen(
            [binaries[1], "--", binaries[0],
             "--path", str(shell / "shell.qml")],
            cwd=ROOT, env=env, stdin=subprocess.DEVNULL,
            stdout=stream, stderr=subprocess.STDOUT, start_new_session=True)
        timed_out, code = False, None
        try:
            try:
                code = proc.wait(timeout=7)
            except subprocess.TimeoutExpired:
                timed_out = True
        finally:
            if proc.poll() is None:
                try:
                    os.killpg(proc.pid, signal.SIGTERM)
                except ProcessLookupError:
                    pass
            try:
                proc.wait(timeout=2)
            except subprocess.TimeoutExpired:
                if proc.poll() is None:
                    try:
                        os.killpg(proc.pid, signal.SIGKILL)
                    except ProcessLookupError:
                        pass
                proc.wait(timeout=2)
    st = stream_path.lstat()
    if (not stat.S_ISREG(st.st_mode) or st.st_uid != os.getuid()
            or stat.S_IMODE(st.st_mode) & 0o077 or st.st_size > 32 * 1024):
        return "X"
    return parse_private_stage(stream_path.read_text(
        encoding="utf-8", errors="replace"), code, timed_out)


def main():
    if sys.argv[1:] != ["--private-offscreen-probe"]:
        print("GATE=EXPLICIT_MODE_REQUIRED")
        return 1
    os.umask(0o077)
    borrowed = runpy.run_path(str(BORROW),
                              run_name="wull_inert_qt_environment_probe")
    binaries = borrowed["preflight"]()
    if not FIXTURE.is_file():
        print("GATE=PROBE_SOURCE_UNAVAILABLE")
        return 1
    base = Path(os.environ.get(
        "XDG_STATE_HOME", str(Path.home() / ".local/state"))).expanduser().resolve()
    state = base / "hadalis-wull-qt-backend-private"
    state.mkdir(mode=0o700, parents=True, exist_ok=True)
    stat_info = state.stat()
    if (stat_info.st_uid != os.getuid()
            or stat.S_IMODE(stat_info.st_mode) & 0o077):
        print("GATE=PROBE_STATE_UNQUALIFIED")
        return 1
    bits = []
    for mode in MODES:
        workspace = Path(tempfile.mkdtemp(prefix=mode + "-", dir=state))
        try:
            bits.append(probe(mode, binaries, borrowed, workspace))
        except (OSError, subprocess.TimeoutExpired, ValueError):
            bits.append("X")
        finally:
            # These are fully owned disposable NO-SCREEN diagnostic logs,
            # not any past Wull capture or unreviewed artifact.
            shutil.rmtree(workspace, ignore_errors=True)
    print("GATE=BACKEND_MATRIX_D" + bits[0] +
          "G" + bits[1] + "S" + bits[2])
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, subprocess.TimeoutExpired):
        print("GATE=PROBE_UNQUALIFIED")
        raise SystemExit(1)
