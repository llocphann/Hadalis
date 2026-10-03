#!/usr/bin/env python3
"""Own-window real Abyss body registry, Wull contact and finite wave coupling.

Software checks actual QML state, geometry and solver events. GPU pixels and
native compositor input remain separate. No live config, daemon or automation.
"""
import os
from pathlib import Path
import runpy
import signal
import subprocess
import tempfile

ROOT=Path(__file__).resolve().parents[1]
subprocess.run(["node","scripts/test-wull-water.cjs"],cwd=ROOT,check=True,timeout=35)
core=runpy.run_path(str(ROOT/"scripts/wull-manual-visual-matrix.py"))
with tempfile.TemporaryDirectory(prefix="wull-abyss-test-") as temporary:
    private=Path(temporary)
    shell,xdg=core["staged"](private)
    (shell/"shell.qml").write_text((ROOT/"wullAbyss.qml").read_text())
    env=core["private_env"](xdg,private/"result.json")
    env.update({"WULL_ABYSS_TEST":"1","QT_QUICK_BACKEND":"software","QT_QUICK_CONTROLS_STYLE":"Basic","QT_QPA_PLATFORMTHEME":"generic"})
    with (private/"test.log").open("w") as output:
        process=subprocess.Popen(["dbus-run-session","--","qs","--path",str(shell/"shell.qml")],cwd=ROOT,
            env=env,stdin=subprocess.DEVNULL,stdout=output,stderr=subprocess.STDOUT,start_new_session=True)
        try:
            code=process.wait(timeout=90)
        except subprocess.TimeoutExpired:
            code=-1
        finally:
            if process.poll() is None:
                os.killpg(process.pid,signal.SIGTERM)
                try:process.wait(timeout=3)
                except subprocess.TimeoutExpired:os.killpg(process.pid,signal.SIGKILL);process.wait(timeout=3)
    log=(private/"test.log").read_text()
    bad=("WULL_ABYSS_CHECK=FAIL","ReferenceError:","TypeError:","SyntaxError:","Unable to assign","Binding loop","non-root animation nodes","Failed to load configuration","Quickshell has crashed","Quickshell has been restarted")
    if code or "WULL_ABYSS_CHECK=PASS" not in log or any(message in log for message in bad):
        for line in log.splitlines():
            if any(message in line for message in (*bad,"ERROR","WULL_ABYSS_")):print(line)
        raise SystemExit("Actual Wull/Abyss coupling check failed")
    for line in log.splitlines():
        if "WULL_ABYSS_CHECK=PASS" in line:print(line.split("WULL_ABYSS_CHECK=",1)[1])
print("WULL_OWNED_ABYSS_WATER_COUPLING_PASS")
