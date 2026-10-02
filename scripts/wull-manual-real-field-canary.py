#!/usr/bin/env python3
"""Four-edge current production AbyssField.frag.qsb + Wull shader canary.

Owned, private Qt offscreen stage: authentic field QML, compiled shader,
body and cradle, but FIXED synthetic insets, EMPTY real-module records,
NO live compositor/bar, NO host screenshot, NO wallpaper.
This run qualifies only isolated renderer viability and painted field.
"""
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

ROOT = Path(__file__).resolve().parents[1]
BORROW = ROOT / "scripts/wull-manual-visual-matrix.py"
FIXTURE = ROOT / "scripts/wull-fixtures/real-field-canary/shell.qml"
SHADER = ROOT / "modules/abyss/looks/AbyssField.frag.qsb"
PNG_MODEL = ROOT / "scripts/wull-private-painted-alpha-model.py"
CELLS = ((8, 8), (280, 8), (8, 280), (280, 280))
STAGES = ("BOOT", "REAL_FIELD_FOUR_HOSTS_READY", "PNG_SAVED")
FAILS = {
    "PRIVATE_CANVAS_INVALID", "REAL_SHADER_NOT_READY",
    "PRODUCTION_HOST_INVALID", "PRODUCTION_BODY_UNVERIFIED",
    "PRODUCTION_BODY_HIDDEN", "PRIVATE_OUTPUT_MISSING",
    "PRIVATE_GRAB_OR_SAVE_FAILED", "PRIVATE_GRAB_UNAVAILABLE",
    "PRIVATE_FIELD_TIMEOUT", "WINDOW_NOT_BACKING",
    "SHEET_DIMENSIONS_INVALID", "FOUR_CELLS_UNAVAILABLE",
}


class Unqualified(Exception):
    pass


def need(value, label):
    if not value:
        raise Unqualified(label)


def painted_cells(alpha, width=512, height=512):
    """Bounded core + ACTUAL-FIELD-ONLY corner alpha in each synthetic cell."""
    need(len(alpha) == width * height and width == height == 512,
         "PRIVATE_IMAGE_UNQUALIFIED")
    for start_x, start_y in CELLS:
        all_pixels = sum(
            alpha[y * width + x] >= 24
            for y in range(start_y, start_y + 224)
            for x in range(start_x, start_x + 224)
        )
        # Corner lies FAR outside the Wull in these fixed source-known poses,
        # and contains ONLY the actual AbyssField shader.
        corner = sum(
            alpha[y * width + x] >= 24
            for y in range(start_y + 3, start_y + 19)
            for x in range(start_x + 3, start_x + 19)
        )
        need(all_pixels >= 1300 and corner >= 65,
             "REAL_FIELD_PAINT_UNQUALIFIED")
    return True


def run_owned(force_opengl=True):
    borrowed = runpy.run_path(str(BORROW), run_name="wull_field_borrow_safety")
    sha = borrowed["source_sha"]()
    binaries = borrowed["preflight"]()
    need(FIXTURE.is_file() and SHADER.is_file()
         and 0 < SHADER.stat().st_size <= 300 * 1024,
         "COMPILED_SHADER_UNAVAILABLE")
    state = Path(os.environ.get(
        "XDG_STATE_HOME", str(Path.home() / ".local/state"))).expanduser().resolve()
    root = state / "hadalis-wull-field-private"
    root.mkdir(parents=True, mode=0o700, exist_ok=True)
    st = root.stat()
    need(st.st_uid == os.getuid()
         and not stat.S_IMODE(st.st_mode) & 0o077,
         "PRIVATE_STATE_UNQUALIFIED")
    owned = Path(tempfile.mkdtemp(prefix="field-" + sha[:12] + "-", dir=root))
    try:
        shell, xdg = borrowed["staged"](owned)
        shutil.copyfile(FIXTURE, shell / "shell.qml")
        options = json.loads((ROOT / "defaults/config.json").read_text())
        options["abyss"]["quality"] = "performance"
        (xdg / "config" / "illogical-impulse" / "config.json").write_text(
            json.dumps(options), encoding="utf-8")
        output, log = owned / "real-field.private.png", owned / "qt.private.log"
        env = borrowed["private_env"](xdg, output)
        env.pop("WULL_VISUAL_MATRIX_PRIVATE_FILE", None)
        env.update({
            "QT_QPA_PLATFORM": "offscreen",
            "QSG_RHI_BACKEND": "opengl",
            "QT_QUICK_BACKEND": "rhi",
            "WULL_FIELD_CANARY_PRIVATE_PNG": str(output),
        })
        # The independent no-artwork matrix qualified Qt-default backing
        # but not forced OpenGL backing. Probe actual shader without forcing
        # either inherited backend or QT Quick backend on the new mode.
        if not force_opengl:
            env.pop("QSG_RHI_BACKEND", None)
            env.pop("QT_QUICK_BACKEND", None)
        timed_out = False
        with log.open("xb") as stream:
            proc = subprocess.Popen(
                [binaries[1], "--", binaries[0],
                 "--path", str(shell / "shell.qml")],
                cwd=ROOT, env=env, stdin=subprocess.DEVNULL,
                stdout=stream, stderr=subprocess.STDOUT,
                start_new_session=True)
            try:
                try:
                    code = proc.wait(timeout=16)
                except subprocess.TimeoutExpired:
                    timed_out, code = True, None
            finally:
                if proc.poll() is None:
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
        info = log.lstat()
        need(stat.S_ISREG(info.st_mode) and info.st_uid == os.getuid()
             and not stat.S_IMODE(info.st_mode) & 0o077
             and info.st_size <= 128 * 1024,
             "PRIVATE_LOG_UNQUALIFIED")
        # Categorized QML markers are the ONLY information extracted.
        lines = log.read_text(encoding="utf-8", errors="replace").splitlines()
        observed = [line.split("WULL_FIELD_CANARY_STAGE=", 1)[1].strip()
                    for line in lines if "WULL_FIELD_CANARY_STAGE=" in line]
        failures = [line.split("WULL_FIELD_CANARY_FAILURE=", 1)[1].strip()
                    for line in lines if "WULL_FIELD_CANARY_FAILURE=" in line]
        if len(failures) == 1 and failures[0] in FAILS:
            raise Unqualified(failures[0])
        need(code == 0 and not timed_out and not failures,
             "QT_FIELD_RUN_UNQUALIFIED")
        need(observed == list(STAGES), "PRIVATE_QT_STAGE_UNQUALIFIED")
        info = output.lstat()
        need(stat.S_ISREG(info.st_mode) and info.st_uid == os.getuid()
             and not stat.S_IMODE(info.st_mode) & 0o077
             and 0 < info.st_size <= 1024 * 1024,
             "PRIVATE_IMAGE_UNQUALIFIED")
        decode = runpy.run_path(str(PNG_MODEL),
                                run_name="real_field_alpha_safe")
        width, height, alpha = decode["png_alpha"](output.read_bytes())
        painted_cells(alpha, width, height)
        need(borrowed["source_sha"]() == sha,
             "SOURCE_CHANGED_DURING_QT")
        print("SOURCE_SHA=" + sha)
        print("REAL_ABYSS_SHADER_FOUR_CELLS=READY_AND_PAINTED")
        print("FIXED_SYNTHETIC_INSETS=YES")
        print("LIVE_PANEL_OR_MODULES=NOT_TESTED")
        print("ORIGINAL_PRIVATE_IMAGE=NOT_PUBLISHED")
        print("GATE=REAL_FIELD_OFFSCREEN_PRIVATE_QUALIFIED")
    except Exception:
        shutil.rmtree(owned, ignore_errors=True)
        raise


def main():
    # This runner imports, but does not execute, the older capture main().
    # Set a strict owner-only umask BEFORE creating private Qt logs and PNG.
    os.umask(0o077)
    need(sys.argv[1:] in (["--static-preflight"], ["--capture"],
                             ["--capture-default-backend"]),
         "EXPLICIT_MODE_REQUIRED")
    borrowed = runpy.run_path(str(BORROW), run_name="wull_field_source_audit")
    borrowed["preflight"]()
    need(FIXTURE.is_file() and SHADER.is_file(),
         "COMPILED_SHADER_UNAVAILABLE")
    if sys.argv[1:] == ["--static-preflight"]:
        print("GATE=REAL_FIELD_CANARY_STATIC_PREFLIGHT_PASS")
        return
    run_owned(force_opengl=sys.argv[1:] == ["--capture"])


if __name__ == "__main__":
    try:
        main()
    except (Unqualified, OSError, ValueError,
            subprocess.TimeoutExpired, KeyError) as exc:
        codes = FAILS | {
            "EXPLICIT_MODE_REQUIRED", "COMPILED_SHADER_UNAVAILABLE",
            "PRIVATE_STATE_UNQUALIFIED", "PRIVATE_LOG_UNQUALIFIED",
            "QT_FIELD_RUN_UNQUALIFIED", "PRIVATE_QT_STAGE_UNQUALIFIED",
            "PRIVATE_IMAGE_UNQUALIFIED", "REAL_FIELD_PAINT_UNQUALIFIED",
            "SOURCE_CHANGED_DURING_QT",
        }
        token = str(exc)
        print("GATE=" + (token if token in codes
                         else "FIELD_CANARY_INCONCLUSIVE"))
        raise SystemExit(1)
