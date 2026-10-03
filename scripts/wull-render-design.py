#!/usr/bin/env python3
"""Render the development gallery's own QML item into an explicit PNG.

Uses isolated Hadalis config/data/cache and a short-lived standalone window.
Never screenshots the desktop, changes shell settings, or starts companiond.
"""
import argparse
import os
from pathlib import Path
import runpy
import signal
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    destination = parser.add_mutually_exclusive_group(required=True)
    destination.add_argument("--output", type=Path)
    destination.add_argument("--frames", type=Path, help="existing empty directory for 180 real QML frames")
    parser.add_argument("--software", action="store_true")
    args = parser.parse_args()
    output = (args.output or args.frames).resolve()
    if args.output and (output.exists() or not output.parent.is_dir()):
        parser.error("output must be a new file in an existing directory")
    if args.frames and (not output.is_dir() or any(output.iterdir()) or args.software):
        parser.error("frames require an empty directory and the GPU renderer")
    if not os.environ.get("WAYLAND_DISPLAY") or not os.environ.get("XDG_RUNTIME_DIR"):
        parser.error("a Wayland session is required for this standalone preview")
    core = runpy.run_path(str(ROOT / "scripts/wull-manual-visual-matrix.py"))
    with tempfile.TemporaryDirectory(prefix="wull-design-") as temporary:
        private = Path(temporary)
        shell, xdg = core["staged"](private)
        (shell / "shell.qml").write_text((ROOT / "wullDesign.qml").read_text())
        env = core["private_env"](xdg, output)
        env.pop("WULL_VISUAL_MATRIX_PRIVATE_FILE", None)
        env.update({
            "WULL_DESIGN_CAPTURE": str(output) if args.output else "",
            "WULL_DESIGN_FRAMES": str(output) if args.frames else "",
            "WULL_DESIGN_REFERENCE": str(ROOT / "docs/wull-visual/design-20261003/reference-closeup.png"),
            "QT_QPA_PLATFORM": "wayland",
            "QSG_RHI_BACKEND": "opengl",
            "QT_QUICK_BACKEND": "software" if args.software else "rhi",
            "QT_QUICK_CONTROLS_STYLE": "Basic",
            "XDG_RUNTIME_DIR": os.environ["XDG_RUNTIME_DIR"],
            "WAYLAND_DISPLAY": os.environ["WAYLAND_DISPLAY"],
        })
        logfile = private / "render.log"
        with logfile.open("w") as stream:
            proc = subprocess.Popen(
                ["dbus-run-session", "--", "qs", "--path", str(shell / "shell.qml")],
                env=env, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT,
                stdin=subprocess.DEVNULL, start_new_session=True)
            try:
                code = proc.wait(timeout=40 if args.frames else 15)
            finally:
                if proc.poll() is None:
                    os.killpg(proc.pid, signal.SIGTERM)
                    try:
                        proc.wait(timeout=3)
                    except subprocess.TimeoutExpired:
                        os.killpg(proc.pid, signal.SIGKILL)
                        proc.wait(timeout=3)
        log = logfile.read_text()
        bad = ("ReferenceError:", "TypeError:", "SyntaxError:", "Unable to assign", "Failed to load configuration")
        marker = "WULL_DESIGN_FRAMES=180_SAVED" if args.frames else "WULL_DESIGN_CAPTURE=SAVED"
        if code or any(message in log for message in bad) or marker not in log:
            for line in log.splitlines():
                if "scene:" in line or "WULL_DESIGN_" in line:
                    print(line)
            raise SystemExit("Wull QML capture failed")
        if args.output and not output.is_file():
            raise SystemExit("Wull QML capture did not create the image")
        if args.frames and len(list(output.glob("frame-*.png"))) != 180:
            raise SystemExit("Wull animation capture did not create all frames")
        print("WULL_DESIGN_REAL_QML_CAPTURE_PASS")
        print(output)


if __name__ == "__main__":
    main()
