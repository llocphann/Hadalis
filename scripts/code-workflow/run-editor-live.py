#!/usr/bin/env python3
"""Exercise the actual Settings page 30 and modal editor under isolated Sway.

Instrumentation is applied only to a git-archived temporary config. It never
changes the checkout, installed shell, or the user's live source files.
"""
from __future__ import annotations

import argparse
import importlib.util
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

HERE = Path(__file__).resolve().parent


def import_local(name: str, filename: str):
    spec = importlib.util.spec_from_file_location(name, HERE / filename)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


prepare_runtime = import_local("editor_prepare_runtime", "prepare-runtime.py")
runtime = import_local("editor_probe_runtime", "run-runtime.py")


def replace_once(path: Path, original: str, replacement: str) -> None:
    text = path.read_text(encoding="utf-8")
    if text.count(original) != 1:
        raise AssertionError(f"non-unique isolated editor fixture: {path}: {original!r}")
    path.write_text(text.replace(original, replacement, 1), encoding="utf-8")


def instrument(config: Path) -> None:
    session = config / "services/CodeWorkflowSession.qml"
    replace_once(
        session, '    property string selectedTargetId: "bar"\n',
        '    property var modalTestEditor: null // isolated test-only reference\n'
        '    property string selectedTargetId: "bar"\n',
    )
    page = config / "modules/settings/CodeWorkflow.qml"
    replace_once(
        page, "    Component.onCompleted: {\n",
        "    Component.onCompleted: {\n"
        "        CodeWorkflowSession.modalTestEditor = sourceEditor\n",
    )
    replace_once(
        page, "    id: root\n",
        "    id: root\n"
        "    Component.onDestruction: CodeWorkflowSession.modalTestEditor = null\n",
    )
    # Prevent tests from touching the actual source buffer, even inside the
    # temporary archive. This fixture still instantiates the real editor.
    replace_once(
        page, "                        draft: root.sourceDraft\n",
        '                        draft: "alpha\\n\\nbeta gamma"\n',
    )
    editor = config / "modules/settings/CodeWorkflowSourceEditor.qml"
    replace_once(
        editor, "    id: root\n",
        "    id: root\n"
        "    readonly property bool testTextEditFocus: editor.activeFocus\n"
        "    readonly property bool testFindFocus: findField.activeFocus\n",
    )
    shell = config / "shell.qml"
    replace_once(
        shell,
        "            report.settingsPublishedPage = GlobalStates.settingsOverlayCurrentPage\n",
        """            report.settingsPublishedPage = GlobalStates.settingsOverlayCurrentPage
            report.editorConfigReady = Config.ready
            report.editorPersistenceReady = Persistent.ready
            report.editorNavigationInitialized = settings._navigationInitialized
            report.codeWorkflowPage = CodeWorkflowRuntime.descriptor(
                "runtime/settings-overlay/page/code-workflow")
            const modal = CodeWorkflowSession.modalTestEditor
            report.modalEditor = modal ? {
                loaded: true,
                mode: modal.mode,
                caret: modal.modalCursorPosition,
                line: modal.currentLineNumber,
                text: modal.documentText,
                focused: modal.testTextEditFocus,
                visible: modal.visible,
                findFocused: modal.testFindFocus,
                findVisible: modal.findVisible,
                findText: modal.findText,
                visualAnchor: modal.visualAnchor,
                visualCursor: modal.visualCursor
            } : { loaded: false }
""",
    )
    replace_once(
        shell,
        "        function settingsClose(): void { GlobalStates.settingsOverlayOpen = false }\n",
        """        function settingsClose(): void { GlobalStates.settingsOverlayOpen = false }
        function editorCommand(command: string): string {
            const item = CodeWorkflowSession.modalTestEditor
            if (!item)
                return "missing"
            const motions = {
                h: Qt.Key_H, j: Qt.Key_J, k: Qt.Key_K, l: Qt.Key_L,
                w: Qt.Key_W, b: Qt.Key_B, e: Qt.Key_E
            }
            if (command === "home") {
                item.setMode("normal")
                item.setCursor(0)
            } else if (command === "reset") {
                item.setMode("normal")
                item.documentText = "alpha\\n\\nbeta gamma"
                item.setCursor(0)
            } else if (command === "focus") {
                item.focusEditor()
            } else if (command === "hideSource") {
                CodeWorkflowSession.sourcePreviewVisible = false
            } else if (command === "showSource") {
                CodeWorkflowSession.sourcePreviewVisible = true
            } else if (command === "normal") {
                item.setMode("normal")
            } else if (command === "visual") {
                item.setMode("visual")
            } else if (command === "insert") {
                item.enterInsertAt(item.modalCursorPosition)
            } else if (command === "find") {
                item.openFind(false)
            } else if (command === "closeFind") {
                item.closeFind()
            } else if (motions[command] !== undefined) {
                return String(item.handleMotionKey(motions[command], 0))
            } else {
                return "unknown"
            }
            return "true"
        }
""",
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--work-dir", type=Path, required=True)
    parser.add_argument("--revision", default="HEAD")
    parser.add_argument("--sway", type=Path, required=True)
    args = parser.parse_args()
    directory = args.work_dir.resolve()
    if directory.exists():
        raise SystemExit("work directory must not exist")
    manifest = prepare_runtime.prepare(directory, args.revision)
    instrument(directory / "config")
    report = {
        "schema": 1,
        "manifest": manifest,
        "environment": "headless Sway, private bus/XDG, staged page 30 QML",
        "checks": [],
        "limitations": [
            "Virtual keyboard tests only the isolated compositor, not user hardware/IME.",
            "No source Save is triggered; a fixed in-memory test draft is used.",
            "Instrumentation exists only in the staged temporary config.",
        ],
    }
    probe = runtime.Probe(directory, report, pointer=None, sway=args.sway.resolve())
    probe.env["QT_QUICK_BACKEND"] = "software"
    keyboard_keeper = None
    try:
        probe.launch()
        # wtype creates and destroys a virtual keyboard on every invocation.
        # On headless Sway this otherwise toggles wl_seat keyboard capability,
        # triggering a wl_keyboard.leave and dropping Qt's activeFocus between
        # commands. Keep an idle virtual keyboard registered for this test.
        keyboard_keeper = subprocess.Popen(
            ["wtype", "-s", "120000"], env=probe.env,
            stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE, text=True,
        )
        time.sleep(0.4)
        probe.record("Virtual keyboard seat remains registered",
                     keyboard_keeper.poll() is None)
        runtime.wait_for(
            lambda: value if (
                (value := probe.snapshot())["editorConfigReady"]
                and value["editorPersistenceReady"]
                and value["editorNavigationInitialized"]
            ) else None,
            "Config, persistence and Settings navigation initialized",
            timeout=45,
        )
        probe.ipc("settingsOpen", 30)
        ready = runtime.wait_for(
            lambda: (
                state if (
                    (state := probe.snapshot())["settingsOpen"]
                    and state["settingsPage"] == 30
                    and state["modalEditor"]["loaded"]
                    and state["codeWorkflowPage"] is not None
                    and state["codeWorkflowPage"]["state"] == "visible"
                ) else None
            ),
            "actual Settings page 30 and editor instantiated",
            timeout=70,
        )
        probe.record("Actual Code Workflow page 30 Loader is visible",
                     ready["codeWorkflowPage"]["state"] == "visible")
        probe.record("Real Source Editor QML instance has fixture draft",
                     ready["modalEditor"]["text"] == "alpha\n\nbeta gamma",
                     ready["modalEditor"])
        probe.record("Editor defaults to read-only NORMAL",
                     ready["modalEditor"]["mode"] == "normal")

        def state():
            return probe.snapshot()["modalEditor"]

        def command(cmd: str):
            return probe.ipc("editorCommand", cmd)

        def key(name: str):
            subprocess.run(["wtype", "-k", name], env=probe.env,
                           check=True, capture_output=True, text=True, timeout=12)

        # Assert the deep link survives the first Settings layout/config cycle.
        stable = probe.snapshot()
        probe.record("Page 30 remains selected after navigation initialization",
                     stable["settingsPage"] == 30
                     and stable["codeWorkflowPage"]["state"] == "visible",
                     {"page": stable["settingsPage"],
                      "lifecycle": stable["codeWorkflowPage"]["state"]})
        # This must succeed before any IPC command calls setMode/focusEditor.
        # The old fixture explicitly focused the TextEdit and concealed the
        # actual user-visible failure after opening the Settings page.
        auto_focused = runtime.wait_for(
            lambda: state() if state()["focused"] else None,
            "Source Editor auto-focus on actual page activation", timeout=20,
        )
        probe.record("Page opens with Source Editor keyboard focus without IPC focus",
                     auto_focused["mode"] == "normal", auto_focused)
        command("home")
        key("l")
        runtime.wait_for(lambda: state() if state()["caret"] == 1 else None,
                         "physical l moves NORMAL caret")
        key("j")
        runtime.wait_for(lambda: state() if state()["caret"] == 6 else None,
                         "physical j enters empty line")
        key("j")
        runtime.wait_for(lambda: state() if state()["caret"] == 8 else None,
                         "physical j restores preferred column")
        key("k")
        runtime.wait_for(lambda: state() if state()["caret"] == 6 else None,
                         "physical k stops on empty line")
        key("k")
        runtime.wait_for(lambda: state() if state()["caret"] == 1 else None,
                         "physical k restores column above empty line")
        probe.record("Physical hjkl obey empty lines and preferred column",
                     state()["caret"] == 1 and state()["line"] == 1, state())

        command("hideSource")
        hidden = runtime.wait_for(
            lambda: value if not (value := state())["focused"]
                and not value["visible"] else None,
            "hidden Source Editor relinquishes focus",
        )
        key("l")
        probe.record("Hidden Source Editor does not intercept modal keys",
                     state()["caret"] == hidden["caret"], state())
        command("showSource")
        reopened = runtime.wait_for(
            lambda: state() if state()["focused"] else None,
            "Source Editor regains focus when preview is shown",
        )
        probe.record("Showing Source preview restores modal keyboard focus",
                     reopened["mode"] == "normal", reopened)

        command("visual")
        key("j")
        visual = runtime.wait_for(
            lambda: value if (
                (value := state())["mode"] == "visual"
                and value["visualAnchor"] == 1
                and value["visualCursor"] == 6
                and value["line"] == 2
            ) else None,
            "physical j expands VISUAL and updates relative-line anchor",
        )
        probe.record("VISUAL j expands selection and tracks block cursor", True, visual)
        command("insert")
        probe.record("INSERT disables modal h/j/k/l dispatcher",
                     command("j") == "false" and state()["mode"] == "insert")
        before = state()["text"]
        subprocess.run(["wtype", "j"], env=probe.env,
                       check=True, capture_output=True, text=True, timeout=12)
        entered = runtime.wait_for(
            lambda: value if len((value := state())["text"]) == len(before) + 1
                else None,
            "native INSERT accepts literal j",
        )
        probe.record("INSERT keeps native text entry", "j" in entered["text"], entered)
        key("Escape")
        runtime.wait_for(lambda: state() if state()["mode"] == "normal" else None,
                         "Escape returns editor to NORMAL")
        probe.record("Escape from INSERT does not close Settings",
                     probe.snapshot()["settingsOpen"])

        command("find")
        runtime.wait_for(lambda: state() if state()["findFocused"] else None,
                         "Find has native keyboard focus")
        subprocess.run(["wtype", "j"], env=probe.env,
                       check=True, capture_output=True, text=True, timeout=12)
        found = runtime.wait_for(
            lambda: value if (value := state())["findText"] == "j" else None,
            "Find accepts literal j without moving editor",
        )
        probe.record("Find receives modal letters as query text", found["findVisible"], found)
        key("Escape")
        runtime.wait_for(lambda: state() if not state()["findVisible"] else None,
                         "Escape closes Find")
        probe.record("Escape from Find keeps Settings open",
                     probe.snapshot()["settingsOpen"])

        command("reset")
        command("focus")
        key("w")
        runtime.wait_for(lambda: state() if state()["caret"] == 7 else None,
                         "physical w reaches next word after blank line")
        key("b")
        runtime.wait_for(lambda: state() if state()["caret"] == 0 else None,
                         "physical b returns to previous word")
        key("e")
        runtime.wait_for(lambda: state() if state()["caret"] == 4 else None,
                         "physical e reaches word end")
        probe.record("Physical w/b/e preserve word boundaries",
                     state()["caret"] == 4, state())

        command("home")
        key("o")
        opened_below = runtime.wait_for(
            lambda: value if (
                (value := state())["mode"] == "insert"
                and value["caret"] == 6
                and value["text"] == "alpha\n\n\nbeta gamma"
            ) else None,
            "physical o opens blank line below with caret on new line",
        )
        probe.record("Physical o enters INSERT on new line below",
                     True, opened_below)
        key("Escape")
        runtime.wait_for(lambda: state() if state()["mode"] == "normal" else None,
                         "Escape after o")
        subprocess.run(["wtype", "-M", "shift", "-k", "o", "-m", "shift"],
                       env=probe.env, check=True, capture_output=True,
                       text=True, timeout=12)
        opened_above = runtime.wait_for(
            lambda: value if (
                (value := state())["mode"] == "insert"
                and value["caret"] == 6
                and value["text"] == "alpha\n\n\n\nbeta gamma"
            ) else None,
            "physical O opens blank line above with caret on new line",
        )
        probe.record("Physical O enters INSERT on new line above",
                     True, opened_above)
        key("Escape")
        runtime.wait_for(lambda: state() if state()["mode"] == "normal" else None,
                         "Escape after O")

        probe.ipc("settingsClose")
        closed = runtime.wait_for(
            lambda: value if not (value := probe.snapshot())["settingsLoaded"]
                and not value["modalEditor"]["loaded"] else None,
            "Settings unload destroys test editor",
            timeout=30,
        )
        probe.record("Unloading Settings releases real editor", True, closed["modalEditor"])
        log = (directory / "quickshell.log").read_text(encoding="utf-8", errors="replace")
        parse_or_type = [
            line for line in log.splitlines()
            if re.search(r"Expected token|Cannot assign to non-existent property|"
                         r"Type CodeWorkflow(?:SourceEditor|IrCanvas)? unavailable",
                         line, re.IGNORECASE)
        ]
        probe.record("Real page 30 loaded without QML parse/property errors",
                     not parse_or_type, parse_or_type[-15:])
    except Exception as exc:
        report["failure"] = repr(exc)
        try:
            report["failureSnapshot"] = probe.snapshot()
        except Exception:
            pass
    finally:
        if keyboard_keeper is not None:
            keyboard_keeper.terminate()
            try:
                keyboard_keeper.wait(timeout=5)
            except subprocess.TimeoutExpired:
                keyboard_keeper.kill()
                keyboard_keeper.wait(timeout=5)
            if keyboard_keeper.stderr:
                keyboard_keeper.stderr.close()
        probe.close()
        (directory / "editor-live-report.json").write_text(
            json.dumps(report, indent=2, ensure_ascii=False) + "\n",
            encoding="utf-8",
        )
    print(json.dumps({
        "report": str(directory / "editor-live-report.json"),
        "checks": len(report["checks"]),
        "failure": report.get("failure"),
    }, indent=2))
    return int(bool(report.get("failure")))


if __name__ == "__main__":
    raise SystemExit(main())
