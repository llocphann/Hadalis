#!/usr/bin/env python3
"""Actual QML hover/click/drag, supported walk, flight and water-hide behavior.

Qt sends events only to this owned offscreen window. Isolated config and D-Bus;
no compositor pointer injection, live settings, companiond or desktop capture.
"""
import os
from pathlib import Path
import runpy
import signal
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
subprocess.run(["node", "scripts/test-wull-scene.cjs"], cwd=ROOT, check=True, timeout=30)
core = runpy.run_path(str(ROOT / "scripts/wull-manual-visual-matrix.py"))
with tempfile.TemporaryDirectory(prefix="wull-presence-test-") as temporary:
    private = Path(temporary)
    shell, xdg = core["staged"](private)
    (shell / "shell.qml").write_text((ROOT / "wullPresence.qml").read_text())
    env = core["private_env"](xdg, private / "result.json")
    env.update({"WULL_PRESENCE_TEST": "1", "QT_QUICK_BACKEND": "software", "QT_QUICK_CONTROLS_STYLE": "Basic", "QT_QPA_PLATFORMTHEME": "generic"})
    logfile = private / "test.log"
    with logfile.open("w") as output:
        process = subprocess.Popen(["dbus-run-session", "--", "qs", "--path", str(shell / "shell.qml")],
            env=env, cwd=ROOT, stdin=subprocess.DEVNULL, stdout=output, stderr=subprocess.STDOUT, start_new_session=True)
        try:
            code = process.wait(timeout=40)
        finally:
            if process.poll() is None:
                os.killpg(process.pid, signal.SIGTERM)
                try:
                    process.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    os.killpg(process.pid, signal.SIGKILL)
                    process.wait(timeout=3)
    log = logfile.read_text()
    bad = ("WULL_PRESENCE_CHECK=FAIL", "ReferenceError:", "TypeError:", "SyntaxError:", "Unable to assign", "Binding loop", "non-root animation nodes", "Failed to load configuration")
    if code or "WULL_PRESENCE_CHECK=PASS" not in log or any(message in log for message in bad):
        for line in log.splitlines():
            if any(message in line for message in (*bad, "ERROR", "WULL_PRESENCE_")):
                print(line)
        raise SystemExit("Actual Wull QML interaction proof failed")
    for line in log.splitlines():
        if "WULL_PRESENCE_CHECK=PASS" in line:
            print(line.split("WULL_PRESENCE_CHECK=", 1)[1])
print("WULL_OWNED_QML_INPUT_AND_PRESENCE_PASS")
