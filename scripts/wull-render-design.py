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
    parser.add_argument("--motion", action="store_true", help="walking and emergence study using the actual host")
    parser.add_argument("--presence", action="store_true", help="four-edge visits, flight, drag and water-hide study")
    parser.add_argument("--abyss", action="store_true", help="actual shared water field, body registry and Wull")
    parser.add_argument("--water-proof", action="store_true", help="three frozen field-only GPU snapshots: rest, contact, restored")
    parser.add_argument("--surface", choices=["edge","dock","settings","leftPanel","rightPanel","styledPopup0","osd","utility"], default="dock")
    parser.add_argument("--peek", action="store_true", help="capture the initial peek in the presence scene")
    args = parser.parse_args()
    if sum([args.motion,args.presence,args.abyss])>1:
        parser.error("choose one motion/presence scene")
    if args.peek and (not (args.presence or args.abyss) or not args.output):
        parser.error("peek requires presence/abyss and a single image")
    if args.abyss and (args.frames or args.software):
        parser.error("the shared water study requires a single GPU image")
    if args.water_proof and not (args.abyss and args.output):
        parser.error("water proof requires abyss and an output image")
    output = (args.output or args.frames).resolve()
    if args.output and (output.exists() or not output.parent.is_dir()):
        parser.error("output must be a new file in an existing directory")
    if args.water_proof and any(Path(str(output)+suffix).exists() for suffix in [".rest.png",".restored.png"]):
        parser.error("water proof companion files must also be new")
    if args.frames and (not output.is_dir() or any(output.iterdir())):
        parser.error("frames require an existing empty directory")
    if args.frames and args.software and not args.presence:
        parser.error("software animation export currently requires the presence scene")
    if not os.environ.get("WAYLAND_DISPLAY") or not os.environ.get("XDG_RUNTIME_DIR"):
        parser.error("a Wayland session is required for this standalone preview")
    core = runpy.run_path(str(ROOT / "scripts/wull-manual-visual-matrix.py"))
    with tempfile.TemporaryDirectory(prefix="wull-design-") as temporary:
        private = Path(temporary)
        shell, xdg = core["staged"](private)
        scene = "wullAbyss.qml" if args.abyss else "wullPresence.qml" if args.presence else "wullMotion.qml" if args.motion else "wullDesign.qml"
        (shell / "shell.qml").write_text((ROOT / scene).read_text())
        env = core["private_env"](xdg, output)
        env.pop("WULL_VISUAL_MATRIX_PRIVATE_FILE", None)
        env.update({
            "WULL_DESIGN_CAPTURE": str(output) if args.output else "",
            "WULL_DESIGN_FRAMES": str(output) if args.frames else "",
            "WULL_PRESENCE_CAPTURE_PEEK": "1" if args.peek or args.water_proof else "",
            "WULL_ABYSS_WATER_PROOF": "1" if args.water_proof else "",
            "WULL_ABYSS_SURFACE": args.surface,
            "WULL_DESIGN_REFERENCE": str(ROOT / "docs/wull-visual/design-20261003/reference-closeup.png"),
            "QT_QPA_PLATFORM": "offscreen" if args.software and args.frames else "wayland",
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
            except subprocess.TimeoutExpired:
                code=-1
            finally:
                if proc.poll() is None:
                    os.killpg(proc.pid, signal.SIGTERM)
                    try:
                        proc.wait(timeout=3)
                    except subprocess.TimeoutExpired:
                        os.killpg(proc.pid, signal.SIGKILL)
                        proc.wait(timeout=3)
        log = logfile.read_text()
        bad = ("ReferenceError:", "TypeError:", "SyntaxError:", "Unable to assign", "Binding loop", "non-root animation nodes", "Failed to load configuration", "Quickshell has crashed", "Quickshell has been restarted", "WULL_PRESENCE_CHECK=FAIL", "WULL_ABYSS_CHECK=FAIL")
        frame_count=180
        marker = f"WULL_DESIGN_FRAMES={frame_count}_SAVED" if args.frames else "WULL_DESIGN_CAPTURE=SAVED"
        if code or any(message in log for message in bad) or marker not in log:
            for line in log.splitlines():
                if "scene:" in line or "WULL_DESIGN_" in line or "WULL_MOTION_" in line or "WULL_PRESENCE_" in line or "WULL_ABYSS_" in line:
                    print(line)
            raise SystemExit("Wull QML capture timed out" if code==-1 else "Wull QML capture failed")
        if args.output and not output.is_file():
            raise SystemExit("Wull QML capture did not create the image")
        if args.water_proof and not all(Path(str(output)+suffix).is_file() for suffix in [".rest.png",".restored.png"]):
            raise SystemExit("Wull water proof did not create both controls")
        if args.frames and len(list(output.glob("frame-*.png"))) != frame_count:
            raise SystemExit("Wull animation capture did not create all frames")
        print("WULL_DESIGN_REAL_QML_CAPTURE_PASS")
        for line in log.splitlines():
            if "WULL_MOTION_BEHAVIOR=" in line: print(line.split("WULL_MOTION_BEHAVIOR=",1)[1])
            if "WULL_PRESENCE_BEHAVIOR=" in line: print(line.split("WULL_PRESENCE_BEHAVIOR=",1)[1])
            if "WULL_PRESENCE_PEEK=" in line: print(line.split("WULL_PRESENCE_PEEK=",1)[1])
            if "WULL_ABYSS_BEHAVIOR=" in line: print(line.split("WULL_ABYSS_BEHAVIOR=",1)[1])
        print(output)


if __name__ == "__main__":
    main()
