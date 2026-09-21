#!/usr/bin/env python3
"""Regression tests for the non-launching Obsidian Tasks runtime bridge."""

from __future__ import annotations

import importlib.util
import json
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent / "todo"
SCRIPT = SCRIPT_DIR / "obsidian_tasks.py"

import sys
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

SPEC = importlib.util.spec_from_file_location("obsidian_tasks", SCRIPT)
assert SPEC is not None and SPEC.loader is not None
obsidian_tasks = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(obsidian_tasks)


class ObsidianTasksRuntimeTests(unittest.TestCase):
    def make_vault(self, text: str = ""):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        vault = Path(tmp.name) / "Vault"
        note = vault / "Hadalis" / "Todo.md"
        note.parent.mkdir(parents=True)
        note.write_text(
            text
            or "<!-- hadalis:todo:start -->\n"
               "- [ ] task\n"
               "<!-- hadalis:todo:end -->\n",
            encoding="utf-8",
        )
        return vault, note

    def patch(self, name, value):
        original = getattr(obsidian_tasks, name)
        setattr(obsidian_tasks, name, value)
        self.addCleanup(lambda: setattr(obsidian_tasks, name, original))

    def test_process_classifier_accepts_app_and_rejects_cli(self):
        self.assertTrue(obsidian_tasks._looks_like_obsidian_app("obsidian", ["/usr/bin/obsidian"]))
        self.assertTrue(obsidian_tasks._looks_like_obsidian_app("", ["/opt/Obsidian/obsidian", "--type=renderer"]))
        self.assertFalse(obsidian_tasks._looks_like_obsidian_app("obsidian-cli", ["/home/u/.local/bin/obsidian-cli"]))
        self.assertFalse(obsidian_tasks._looks_like_obsidian_app("python3", ["python3", "obsidian_tasks.py"]))

    def test_stopped_probe_never_invokes_cli(self):
        vault, _ = self.make_vault()
        self.patch("_obsidian_running", lambda: False)
        self.patch("_find_cli", lambda: "/fake/obsidian")

        def forbidden(*_args, **_kwargs):
            raise AssertionError("CLI must not run while Obsidian is stopped")

        self.patch("_run_cli", forbidden)
        result = obsidian_tasks.probe_capabilities(str(vault))
        self.assertFalse(result["obsidianRunning"])
        self.assertFalse(result["cliResponsive"])
        self.assertFalse(result["richMutationAvailable"])

    def test_eval_json_parser_handles_cli_prefix_and_quoted_json(self):
        self.assertEqual(
            obsidian_tasks._parse_eval_json('noise\n=> {"vaultPath":"/v"}\n'),
            {"vaultPath": "/v"},
        )
        quoted = json.dumps(json.dumps({"vaultPath": "/v"}))
        self.assertEqual(
            obsidian_tasks._parse_eval_json("=> " + quoted),
            {"vaultPath": "/v"},
        )

    def test_settings_defaults_and_custom_status_are_sanitized(self):
        summary = obsidian_tasks._settings_summary({
            "globalFilter": "#task",
            "statusSettings": {
                "customStatuses": [
                    {
                        "symbol": "?",
                        "name": "Question",
                        "nextStatusSymbol": "x",
                        "type": "ON_HOLD",
                    },
                    {
                        "symbol": "!",
                        "name": "Bad type",
                        "nextStatusSymbol": "x",
                        "type": "NOT_A_TYPE",
                    },
                ]
            },
        })
        self.assertEqual(summary["globalFilter"], "#task")
        self.assertEqual(summary["taskFormat"], "tasksPluginEmoji")
        self.assertTrue(summary["setDoneDate"])
        by_symbol = {entry["symbol"]: entry for entry in summary["statuses"]}
        self.assertEqual(by_symbol["?"]["type"], "ON_HOLD")
        self.assertEqual(by_symbol["!"]["type"], "TODO")
        self.assertEqual(by_symbol["/"]["type"], "IN_PROGRESS")

    def test_capability_probe_matches_physical_vault(self):
        vault, _ = self.make_vault()
        self.patch("_obsidian_running", lambda: True)
        self.patch("_find_cli", lambda: "/fake/obsidian")

        payload = {
            "vaultPath": str(vault.resolve()),
            "tasksPluginEnabled": True,
            "tasksPluginVersion": "7.22.0",
            "tasksApiAvailable": True,
            "settings": {"globalFilter": "#task"},
        }

        def fake_cli(_cli, _args, _timeout):
            return subprocess.CompletedProcess(
                ["obsidian"], 0, stdout="=> " + json.dumps(payload), stderr=""
            )

        self.patch("_run_cli", fake_cli)
        result = obsidian_tasks.probe_capabilities(str(vault))
        self.assertTrue(result["cliResponsive"])
        self.assertTrue(result["activeVaultMatches"])
        self.assertTrue(result["tasksApiAvailable"])
        self.assertTrue(result["richMutationAvailable"])
        self.assertEqual(result["tasksSettings"]["globalFilter"], "#task")

    def test_capability_probe_fails_closed_on_other_vault(self):
        vault, _ = self.make_vault()
        other_tmp = tempfile.TemporaryDirectory()
        self.addCleanup(other_tmp.cleanup)
        other = Path(other_tmp.name).resolve()
        self.patch("_obsidian_running", lambda: True)
        self.patch("_find_cli", lambda: "/fake/obsidian")

        payload = {
            "vaultPath": str(other),
            "tasksPluginEnabled": True,
            "tasksApiAvailable": True,
            "settings": {},
        }
        self.patch(
            "_run_cli",
            lambda *_args: subprocess.CompletedProcess(
                ["obsidian"], 0, stdout="=> " + json.dumps(payload), stderr=""
            ),
        )
        result = obsidian_tasks.probe_capabilities(str(vault))
        self.assertFalse(result["activeVaultMatches"])
        self.assertFalse(result["richMutationAvailable"])

    def test_toggle_eval_uses_tasks_api_vault_process_and_exact_line_guard(self):
        code = obsidian_tasks._toggle_eval_code(
            "/vault", "Hadalis/Todo.md", 7, "- [ ] café"
        )
        self.assertIn("adapter.getBasePath()!==expectedVault", code)
        self.assertIn("app.vault.getFileByPath(notePath)", code)
        self.assertIn("executeToggleTaskDoneCommand", code)
        self.assertIn("app.vault.process(file,(data)=>", code)
        self.assertIn("if(r.raw!==expectedRaw)", code)
        self.assertIn("transformed.split", code)
        self.assertNotIn("vault=", code)

    def test_toggle_when_stopped_never_invokes_cli(self):
        vault, _ = self.make_vault()
        scan = obsidian_tasks.obsidian_todo.scan_note(str(vault), "Hadalis/Todo.md")
        self.patch("_obsidian_running", lambda: False)
        self.patch("_find_cli", lambda: "/fake/obsidian")

        def forbidden(*_args, **_kwargs):
            raise AssertionError("CLI must not run while Obsidian is stopped")

        self.patch("_run_cli", forbidden)
        with self.assertRaises(obsidian_tasks.RuntimeErrorInfo) as error:
            obsidian_tasks.toggle_tasks_task(
                str(vault),
                "Hadalis/Todo.md",
                scan["tasks"][0]["id"],
                scan["document"]["sha256"],
            )
        self.assertEqual(error.exception.code, "obsidian_not_running")

    def test_toggle_requires_fresh_document_hash_before_cli(self):
        vault, note = self.make_vault()
        scan = obsidian_tasks.obsidian_todo.scan_note(str(vault), "Hadalis/Todo.md")
        note.write_text(
            "<!-- hadalis:todo:start -->\n- [ ] changed\n<!-- hadalis:todo:end -->\n",
            encoding="utf-8",
        )
        self.patch("_obsidian_running", lambda: True)
        self.patch("_find_cli", lambda: "/fake/obsidian")

        def forbidden(*_args, **_kwargs):
            raise AssertionError("CLI must not run after CAS failure")

        self.patch("_run_cli", forbidden)
        with self.assertRaises(obsidian_tasks.obsidian_todo.TodoError) as error:
            obsidian_tasks.toggle_tasks_task(
                str(vault),
                "Hadalis/Todo.md",
                scan["tasks"][0]["id"],
                scan["document"]["sha256"],
            )
        self.assertEqual(error.exception.code, "conflict")

    def test_success_is_verified_by_fresh_filesystem_scan(self):
        vault, note = self.make_vault()
        scan = obsidian_tasks.obsidian_todo.scan_note(str(vault), "Hadalis/Todo.md")
        self.patch("_obsidian_running", lambda: True)
        self.patch("_find_cli", lambda: "/fake/obsidian")
        calls = []

        capability = {
            "vaultPath": str(vault.resolve()),
            "tasksPluginEnabled": True,
            "tasksPluginVersion": "7.22.0",
            "tasksApiAvailable": True,
            "settings": {},
        }

        def fake_cli(_cli, args, _timeout):
            code = next(arg[5:] for arg in args if arg.startswith("code="))
            calls.append(code)
            if "executeToggleTaskDoneCommand" not in code:
                return subprocess.CompletedProcess(
                    ["obsidian"], 0,
                    stdout="=> " + json.dumps(capability),
                    stderr="",
                )
            current = note.read_text(encoding="utf-8")
            note.write_text(current.replace("- [ ] task", "- [x] task"), encoding="utf-8")
            # Deliberately empty: mutation stdout is not an acknowledgement.
            return subprocess.CompletedProcess(["obsidian"], 0, stdout="", stderr="")

        self.patch("_run_cli", fake_cli)
        result = obsidian_tasks.toggle_tasks_task(
            str(vault),
            "Hadalis/Todo.md",
            scan["tasks"][0]["id"],
            scan["document"]["sha256"],
        )
        self.assertTrue(result["verified"])
        self.assertEqual(result["mutation"], "toggle-tasks")
        self.assertTrue(result["tasks"][0]["done"])
        self.assertEqual(len(calls), 2)

    def test_unchanged_file_is_not_accepted_as_mutation_success(self):
        vault, _ = self.make_vault()
        scan = obsidian_tasks.obsidian_todo.scan_note(str(vault), "Hadalis/Todo.md")
        self.patch("_obsidian_running", lambda: True)
        self.patch("_find_cli", lambda: "/fake/obsidian")
        capability = {
            "vaultPath": str(vault.resolve()),
            "tasksPluginEnabled": True,
            "tasksApiAvailable": True,
            "settings": {},
        }

        def fake_cli(_cli, args, _timeout):
            code = next(arg[5:] for arg in args if arg.startswith("code="))
            if "executeToggleTaskDoneCommand" not in code:
                return subprocess.CompletedProcess(
                    ["obsidian"], 0,
                    stdout="=> " + json.dumps(capability), stderr=""
                )
            return subprocess.CompletedProcess(["obsidian"], 0, stdout="", stderr="")

        self.patch("_run_cli", fake_cli)
        with self.assertRaises(obsidian_tasks.RuntimeErrorInfo) as error:
            obsidian_tasks.toggle_tasks_task(
                str(vault),
                "Hadalis/Todo.md",
                scan["tasks"][0]["id"],
                scan["document"]["sha256"],
            )
        self.assertEqual(error.exception.code, "mutation_unverified")


if __name__ == "__main__":
    unittest.main()
