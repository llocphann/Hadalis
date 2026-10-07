#!/usr/bin/env python3
"""Real Wull emergence after collapsed Bar records, with isolated Qt state."""
import os
from pathlib import Path
import runpy
import signal
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
core = runpy.run_path(str(ROOT / "scripts/wull-manual-visual-matrix.py"))
qml = '''
//@ pragma UseQApplication
import QtQuick
import QtTest
import Quickshell
import qs.modules.abyss.companion
import "modules/abyss/companion/WullScene.js" as Scene
ShellRoot {
    Window {
        id: window
        color: "#111820"
        width: 1920; height: 1200; visible: true
        property bool allowed: true
        // Two collapsed tray entries observed on the affected live output.
        property var modules: [{edge:"top",along:1020.37,span:182.48},
            {edge:"top",along:1679.06,span:0},{edge:"top",along:1697.77,span:0}]
        readonly property var scene: Scene.fromParticipants({width:width,height:height,
            hostWidth:112,hostHeight:98,scale:1,
            insets:{top:48,right:10,bottom:10,left:10}}, {}, modules)
        WullPresence {
            id: presence
            scene: window.scene; actor: companion; permitted: window.allowed
            requestedReveal: 1; motionEnabled: false
            onStopRequested: companion.stopTravel()
            onResetRequested: (px,py,edge)=>companion.resetTo(px,py,edge)
        }
        AbyssCompanion {
            id: companion
            managedPlacement: true; upright: true; connectedWater: true
            motionEnabled: false; effectsEnabled: false
            edge: presence.emergenceEdge; emergenceEdge: presence.emergenceEdge
            targetX: presence.targetX; targetY: presence.targetY
            reveal: presence.renderedReveal
        }
        TestCase {
            id: input
            name: "WullCollapsedBar"; when: false
            function runChecks() {
                tryCompare(companion,"inputReady",true,3000)
                verify(Scene.valid(window.scene));verify(presence.qualified)
                verify(companion.visible && presence.visitActive)
                compare(window.scene.blockers.length,1)
                const before=JSON.stringify(window.scene.records)
                verify(Scene.clearAt(window.scene,presence.position()))
                compare(JSON.stringify(window.scene.records),before)
                // Invalid geometry must still hide; repairing it re-emerges
                // automatically without manually calling show/appear.
                window.modules=[{edge:"top",along:20,span:-1}]
                tryCompare(companion,"visible",false,2000)
                verify(!Scene.valid(window.scene));verify(!presence.visitActive)
                window.modules=[{edge:"left",along:340,span:0}]
                tryCompare(companion,"inputReady",true,3000)
                verify(presence.visitActive && presence.qualified)
                compare(window.scene.blockers.length,0)
                window.allowed=false
                tryCompare(companion,"visible",false,2000)
                verify(!presence.visitActive)
                console.log("WULL_COLLAPSED_BAR=PASS")
                shutdown.start()
            }
        }
        Timer { interval:100; running:true; onTriggered:input.runChecks() }
        Timer { id:shutdown; interval:150; onTriggered:Qt.quit() }
    }
}
'''
with tempfile.TemporaryDirectory(prefix="wull-collapsed-bar-") as temporary:
    private = Path(temporary)
    shell, xdg = core["staged"](private)
    (shell / "shell.qml").write_text(qml)
    env = core["private_env"](xdg, private / "result.json")
    env.update({"QT_QUICK_BACKEND": "software", "QT_QUICK_CONTROLS_STYLE": "Basic",
                "QT_QPA_PLATFORMTHEME": "generic"})
    with (private / "test.log").open("w") as output:
        process = subprocess.Popen(["dbus-run-session", "--", "qs", "--path", str(shell / "shell.qml")],
            cwd=ROOT, env=env, stdin=subprocess.DEVNULL, stdout=output,
            stderr=subprocess.STDOUT, start_new_session=True)
        try:
            code = process.wait(timeout=20)
        finally:
            if process.poll() is None:
                os.killpg(process.pid, signal.SIGTERM)
                process.wait(timeout=3)
    log = (private / "test.log").read_text()
    bad = ("FAIL!", "ReferenceError:", "TypeError:", "SyntaxError:", "Binding loop",
           "Unable to assign", "Failed to load configuration", "Quickshell has crashed",
           "Quickshell has been restarted")
    if code or "WULL_COLLAPSED_BAR=PASS" not in log or any(m in log for m in bad):
        print("\n".join(line for line in log.splitlines()
                        if any(m in line for m in (*bad, "ERROR", "WULL_COLLAPSED_BAR"))))
        raise SystemExit("Collapsed Bar Wull emergence/recovery failed")
print("WULL_COLLAPSED_BAR_QML_EMERGENCE_RECOVERY_AND_POLICY_PASS")
