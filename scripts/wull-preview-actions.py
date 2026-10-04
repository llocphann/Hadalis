#!/usr/bin/env python3
"""Capture only the owned GPU motion board; never the user's desktop."""
import argparse
import os
from pathlib import Path
import runpy
import signal
import subprocess
import tempfile

ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument("--output",type=Path,required=True)
parser.add_argument("--board",choices=("actions","rich"),default="actions")
args=parser.parse_args()
destination=args.output.resolve()
if destination.exists() or not destination.parent.is_dir():parser.error("output must be a new directory")
if not os.environ.get("WAYLAND_DISPLAY"):parser.error("an owned Wayland GPU window is required")
destination.mkdir(mode=0o700)
core=runpy.run_path(str(ROOT/"scripts/wull-manual-visual-matrix.py"))
with tempfile.TemporaryDirectory(prefix="wull-actions-board-") as temporary:
    private=Path(temporary);shell,xdg=core["staged"](private)
    board="WullRichBoard" if args.board=="rich" else "WullActionsBoard"
    (shell/"shell.qml").write_text('import Quickshell\nimport "scripts/wull-fixtures/lively"\nShellRoot {'+board+' {}}\n')
    env=core["private_env"](xdg,destination/"result.json")
    env.update({"QT_QPA_PLATFORM":"wayland","QSG_RHI_BACKEND":"opengl","QT_QUICK_BACKEND":"rhi",
        "QT_QUICK_CONTROLS_STYLE":"Basic","XDG_RUNTIME_DIR":os.environ["XDG_RUNTIME_DIR"],
        "WAYLAND_DISPLAY":os.environ["WAYLAND_DISPLAY"],"WULL_ACTIONS_DIRECTORY":str(destination)})
    with (destination/"capture.log").open("w") as output:
        process=subprocess.Popen(["dbus-run-session","--","qs","--path",str(shell/"shell.qml")],cwd=ROOT,
            env=env,stdin=subprocess.DEVNULL,stdout=output,stderr=subprocess.STDOUT,start_new_session=True)
        try:code=process.wait(timeout=25)
        except subprocess.TimeoutExpired:code=-1
        finally:
            if process.poll() is None:os.killpg(process.pid,signal.SIGTERM);process.wait(timeout=3)
    log=(destination/"capture.log").read_text()
    bad=("ReferenceError:","TypeError:","Binding loop","Unable to assign","Failed to load configuration","WULL_ACTIONS_CAPTURE=FAIL")
    if code or "WULL_ACTIONS_CAPTURE=PASS" not in log or any(m in log for m in bad):
        print(log[-10000:]);raise SystemExit("Wull GPU motion board failed")
from PIL import Image
frames=[Image.open(path).convert("RGB") for path in sorted(destination.glob("frame-*.png"))]
assert len(frames)==(45 if args.board=="rich" else 26)
frames[0].save(destination/"wull-actions.gif",save_all=True,append_images=frames[1:],duration=70,loop=0)
print("WULL_OWNED_GPU_ACTION_BOARD_PASS",destination/"wull-actions.gif")
