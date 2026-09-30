#!/usr/bin/env python3
"""Opt-in native frontend removal and independent Quickshell crash acceptance.

Loads the real Settings component on a private D-Bus with private XDG files.
Only the fixture's process group is killed. Existing shell, profiles, chats and
jobs are untouched; backend PIDs must survive the crash without restarting.
"""
from __future__ import annotations

import copy
import json
import os
from pathlib import Path
import resource
import shutil
import signal
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from automation.manager.model import default_config
from automation.manager.store import default_state, state_dir, _write

UNITS = ("hadalis-chat-bridge.service", "hadalis-worker.service", "hadalis-privilege.service")
QML = '''//@ pragma ShellId hadalis-automation-acceptance
import QtQuick
import Quickshell
import qs.modules.settings
ShellRoot {
    id: test
    property int step: 0
    property bool done: false
    function buttons(item, label) {
        let found = item?.buttonText === label ? [item] : []
        for (const child of Array.from(item?.children ?? []))
            found = found.concat(buttons(child, label))
        return found
    }
    function check(ok, detail) {
        if (ok) return true
        console.error("AUTOMATION_UI_FAIL", detail)
        done = true
        return false
    }
    FloatingWindow {
        visible: false; implicitWidth: 800; implicitHeight: 900
        AutomationConfig { id: page; anchors.fill: parent; activeSection: "profiles" }
    }
    Timer {
        interval: 250; repeat: true; running: !test.done
        onTriggered: {
            if (!page.loaded) return
            if (test.step === 0) {
                if (!test.check(page.snapshot.runtime.engine_version === 2, "v2 state readable")) return
                const remove = test.buttons(page, "Remove").filter(b => b.visible)
                if (!test.check(remove.length === 3, "Remove available for both profiles")) return
                page.selectedProfileId = "fixture-keep"
                remove[0].clicked()
                if (!test.check(page.pendingRemoveId === "strict-lossless-research" && page.pendingRemoveUnresolved,
                    "row removal targets running profile independently")) return
                page.cancelConfirmation()
                if (!test.check(!page.pendingRemoveId, "Cancel retains pending profile")) return
                page.confirmRemoval("strict-lossless-research")
                const confirm = test.buttons(page, "Confirm remove").filter(b => b.visible)
                if (!test.check(confirm.length === 1, "one inline confirmation")) return
                confirm[0].clicked()
            }
            if (test.step > 3 && page.profiles.length === 1) {
                if (!test.check(page.profiles[0].id === "fixture-keep" && !page.snapshot.runtime.owner_id,
                    "only confirmed profile removed; other profile remains")) return
                console.info("AUTOMATION_UI_PASS")
                test.done = true
            }
            if (test.step++ > 80) test.check(false, "removal timeout: " + page.errorText)
        }
    }
}
'''


def services() -> dict:
    output = {}
    for unit in UNITS:
        result = subprocess.run(["systemctl", "--user", "show", unit,
                                 "-p", "MainPID", "-p", "ActiveState", "-p", "PartOf", "-p", "Requires"],
                                capture_output=True, text=True, timeout=5, check=True)
        fields = dict(line.split("=", 1) for line in result.stdout.splitlines())
        assert fields["ActiveState"] == "active" and int(fields["MainPID"]) > 0, (unit, fields)
        assert not fields["PartOf"] and "quickshell" not in fields["Requires"].lower(), (unit, fields)
        output[unit] = fields
    return output


def main() -> int:
    if os.environ.get("HADALIS_TEST_SHELL_LIVE") != "1":
        print("SKIP: native shell acceptance requires HADALIS_TEST_SHELL_LIVE=1")
        return 0
    assert os.environ.get("WAYLAND_DISPLAY"), "requires a live Wayland session"
    assert shutil.which("qs") and shutil.which("dbus-run-session")
    before = services()
    acceptance = state_dir() / "acceptance"
    acceptance.mkdir(parents=True, exist_ok=True, mode=0o700)
    base = Path(tempfile.mkdtemp(prefix="shell-live-", dir=acceptance))
    fixture = base / "shell"
    fixture.mkdir()
    qml_root = Path(os.environ.get("HADALIS_TEST_QML_ROOT", str(ROOT))).resolve()
    for name in ("GlobalStates.qml", "assets", "defaults", "modules", "qmldir", "scripts", "services", "translations"):
        (fixture / name).symlink_to(qml_root / name, target_is_directory=(qml_root / name).is_dir())
    (fixture / "shell.qml").write_text(QML)
    env = os.environ.copy()
    for field, folder in (("XDG_CONFIG_HOME", "config"), ("XDG_STATE_HOME", "state"),
                          ("XDG_DATA_HOME", "data"), ("XDG_CACHE_HOME", "cache")):
        env[field] = str(base / folder)
        Path(env[field]).mkdir(mode=0o700)
    data = Path(env["XDG_DATA_HOME"]) / "hadalis-automation"
    data.mkdir()
    launcher = data / "control.py"
    launcher.write_text("import runpy\nrunpy.run_path(" + repr(str(ROOT / "scripts/hadalis-automation-control.py")) + ",run_name='__main__')\n")
    config = default_config()
    first = config["profiles"][0]
    first["enabled"] = True
    keep = copy.deepcopy(first)
    keep.update(id="fixture-keep", name="Keep this profile", enabled=False)
    config["profiles"] = [first, keep]
    state = default_state(config)
    state["engine_version"] = 2
    state["profiles"][first["id"]].update(desired="run", status="thinking",
        pending={"prepared_at_unix":100, "response_action_count":3, "counted":True})
    _write(Path(env["XDG_CONFIG_HOME"]) / "hadalis/automation.json", config)
    private_state = Path(env["XDG_STATE_HOME"]) / "hadalis-automation"
    _write(private_state / "manager.json", state)
    log = base / "quickshell.log"
    # A killed private fixture should never produce an unbounded core dump.
    old_core = resource.getrlimit(resource.RLIMIT_CORE)
    resource.setrlimit(resource.RLIMIT_CORE, (0, old_core[1]))
    proc = None
    try:
        with log.open("wb") as stream:
            log.chmod(0o600)
            proc = subprocess.Popen(["dbus-run-session", "--", "qs", "-p", str(fixture)],
                                    env=env, stdout=stream, stderr=subprocess.STDOUT, start_new_session=True)
            deadline = time.monotonic() + 45
            while time.monotonic() < deadline:
                text = log.read_text(errors="replace")
                assert "AUTOMATION_UI_FAIL" not in text, str(log)
                assert log.stat().st_size < 2 * 1024 * 1024, "fixture output exceeded bound"
                if "AUTOMATION_UI_PASS" in text:
                    break
                assert proc.poll() is None, f"Quickshell fixture exited; inspect {log}"
                time.sleep(0.1)
            else:
                raise AssertionError(f"native frontend acceptance timed out; inspect {log}")
            saved = json.loads((private_state / "manager.json").read_text())
            assert saved["engine_version"] == 2 and set(saved["profiles"]) == {"fixture-keep"}
            archives = list((private_state / "removed-profiles").glob("*.json"))
            assert len(archives) == 1, "pending removal must retain a private recovery receipt"
            os.killpg(proc.pid, signal.SIGKILL)
            proc.wait(timeout=5)
            time.sleep(0.25)
    finally:
        if proc is not None:
            try: os.killpg(proc.pid, signal.SIGKILL)
            except ProcessLookupError: pass
            proc.wait(timeout=5)
        resource.setrlimit(resource.RLIMIT_CORE, old_core)
    after = services()
    assert {u: v["MainPID"] for u,v in after.items()} == {u: v["MainPID"] for u,v in before.items()}, "backend restarted/died with Quickshell"
    _write(base / "result.json", {"sha":subprocess.check_output(["git","rev-parse","HEAD"],cwd=ROOT,text=True).strip(),
        "qml_source":str(qml_root), "frontend_removal":"pass", "private_shell_crash":"SIGKILL", "independent_backend":"pass", "services_before":before,"services_after":after})
    print(f"PASS: native frontend removal, private recovery receipt and Quickshell crash with all backend PIDs unchanged; {base / 'result.json'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
