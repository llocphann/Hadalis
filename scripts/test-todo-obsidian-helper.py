#!/usr/bin/env python3
"""Regression tests for scripts/todo/obsidian_todo.py."""

from __future__ import annotations

import codecs
import importlib.util
import os
import stat
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent / "todo" / "obsidian_todo.py"
SPEC = importlib.util.spec_from_file_location("obsidian_todo", SCRIPT)
assert SPEC is not None and SPEC.loader is not None
obsidian_todo = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(obsidian_todo)


class ObsidianTodoTests(unittest.TestCase):
    def make_vault(self, data: bytes, note: str = "Hadalis/Todo.md"):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        vault = Path(tmp.name) / "Vault"
        path = vault / note
        path.parent.mkdir(parents=True)
        path.write_bytes(data)
        return vault, path

    def scan(self, text: str, newline: str = "\n"):
        body = text.replace("\n", newline).encode("utf-8")
        vault, path = self.make_vault(body)
        return vault, path, obsidian_todo.scan_note(str(vault), "Hadalis/Todo.md")

    def test_parses_tasks_and_preserves_structure(self):
        _, _, result = self.scan(
            """# Tasks
<!-- hadalis:todo:start -->
- [ ] plain
  * [x] nested
> - [/] progress
1. [-] cancelled
12) [Q] custom metadata 📅 2026-09-25
not a task
<!-- hadalis:todo:end -->
"""
        )
        tasks = result["tasks"]
        self.assertEqual([t["listMarker"] for t in tasks], ["-", "*", "-", "1.", "12)"])
        self.assertEqual([t["statusType"] for t in tasks], [
            "TODO", "DONE", "IN_PROGRESS", "CANCELLED", "TODO"
        ])
        self.assertEqual(tasks[1]["indent"], "  ")
        self.assertEqual(tasks[2]["indent"], "> ")
        self.assertEqual(tasks[4]["content"], "custom metadata 📅 2026-09-25")
        self.assertTrue(tasks[1]["done"])
        self.assertFalse(tasks[3]["done"])

    def test_duplicate_text_has_distinct_ephemeral_ids(self):
        _, _, result = self.scan(
            """<!-- hadalis:todo:start -->
- [ ] same
- [ ] same
<!-- hadalis:todo:end -->
"""
        )
        self.assertEqual(len(result["tasks"]), 2)
        self.assertNotEqual(result["tasks"][0]["id"], result["tasks"][1]["id"])

    def test_fenced_tasks_and_markers_are_ignored(self):
        _, _, result = self.scan(
            """```md
<!-- hadalis:todo:start -->
- [ ] fake
<!-- hadalis:todo:end -->
```
<!-- hadalis:todo:start -->
- [ ] real
~~~md
- [ ] fenced
~~~
<!-- hadalis:todo:end -->
"""
        )
        self.assertEqual([t["content"] for t in result["tasks"]], ["real"])

    def test_blockquote_fence_is_ignored(self):
        _, _, result = self.scan(
            """<!-- hadalis:todo:start -->
> ```
> - [ ] fake
> ```
- [ ] real
<!-- hadalis:todo:end -->
"""
        )
        self.assertEqual([t["content"] for t in result["tasks"]], ["real"])

    def test_crlf_bom_and_final_newline_are_reported(self):
        text = (
            "<!-- hadalis:todo:start -->\r\n"
            "- [ ] café\r\n"
            "<!-- hadalis:todo:end -->\r\n"
        ).encode("utf-8")
        vault, _ = self.make_vault(codecs.BOM_UTF8 + text)
        result = obsidian_todo.scan_note(str(vault), "Hadalis/Todo.md")
        self.assertTrue(result["document"]["bom"])
        self.assertEqual(result["document"]["newline"], "crlf")
        self.assertTrue(result["document"]["finalNewline"])
        self.assertEqual(result["tasks"][0]["content"], "café")

    def test_no_final_newline_is_reported(self):
        _, _, result = self.scan(
            "<!-- hadalis:todo:start -->\n"
            "- [ ] task\n"
            "<!-- hadalis:todo:end -->"
        )
        self.assertFalse(result["document"]["finalNewline"])

    def test_missing_or_duplicate_markers_fail_closed(self):
        with self.assertRaises(obsidian_todo.TodoError) as missing:
            self.scan("- [ ] task\n")
        self.assertEqual(missing.exception.code, "invalid_managed_section")

        with self.assertRaises(obsidian_todo.TodoError) as duplicate:
            self.scan(
                """<!-- hadalis:todo:start -->
<!-- hadalis:todo:start -->
- [ ] task
<!-- hadalis:todo:end -->
"""
            )
        self.assertEqual(duplicate.exception.code, "invalid_managed_section")

    def test_out_of_order_markers_fail_closed(self):
        with self.assertRaises(obsidian_todo.TodoError) as error:
            self.scan(
                """<!-- hadalis:todo:end -->
- [ ] task
<!-- hadalis:todo:start -->
"""
            )
        self.assertEqual(error.exception.code, "invalid_managed_section")

    def test_note_path_must_be_vault_relative(self):
        vault, _ = self.make_vault(
            b"<!-- hadalis:todo:start -->\n<!-- hadalis:todo:end -->\n"
        )
        for bad in ("../outside.md", "/tmp/outside.md", r"..\outside.md", ""):
            with self.subTest(path=bad):
                with self.assertRaises(obsidian_todo.TodoError):
                    obsidian_todo.resolve_note(str(vault), bad)

    @unittest.skipUnless(hasattr(os, "symlink"), "symlinks unavailable")
    def test_symlink_escape_is_rejected(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        root = Path(tmp.name)
        vault = root / "Vault"
        vault.mkdir()
        outside = root / "outside.md"
        outside.write_text(
            "<!-- hadalis:todo:start -->\n<!-- hadalis:todo:end -->\n",
            encoding="utf-8",
        )
        (vault / "escape.md").symlink_to(outside)
        with self.assertRaises(obsidian_todo.TodoError) as error:
            obsidian_todo.scan_note(str(vault), "escape.md")
        self.assertEqual(error.exception.code, "note_outside_vault")

    def test_filesystem_root_is_rejected(self):
        with self.assertRaises(obsidian_todo.TodoError) as error:
            obsidian_todo.resolve_note("/", "tmp/example.md")
        self.assertEqual(error.exception.code, "invalid_vault_path")

    def test_basic_toggle_preserves_bom_crlf_spacing_and_outside_bytes(self):
        original = codecs.BOM_UTF8 + (
            "# Before\r\n"
            "<!-- hadalis:todo:start -->\r\n"
            "  *   [ ]   keep spacing\r\n"
            "<!-- hadalis:todo:end -->\r\n"
            "# After\r\n"
        ).encode("utf-8")
        vault, path = self.make_vault(original)
        before = obsidian_todo.scan_note(str(vault), "Hadalis/Todo.md")
        task = before["tasks"][0]
        result = obsidian_todo.toggle_basic_task(
            str(vault), "Hadalis/Todo.md", task["id"], before["document"]["sha256"]
        )
        raw = path.read_bytes()
        self.assertTrue(raw.startswith(codecs.BOM_UTF8))
        self.assertIn(b"  *   [x]   keep spacing\r\n", raw)
        self.assertTrue(raw.endswith(b"# After\r\n"))
        self.assertTrue(result["tasks"][0]["done"])
        self.assertEqual(result["document"]["newline"], "crlf")

    def test_basic_toggle_rejects_rich_metadata_and_custom_status(self):
        for line in (
            "- [ ] repeat 🔁 every week",
            "- [ ] due 📅 2026-09-25",
            "- [ ] [due:: 2026-09-25]",
            "- [/] in progress",
            "- [Q] custom",
        ):
            with self.subTest(line=line):
                vault, _, scan = self.scan(
                    "<!-- hadalis:todo:start -->\n"
                    + line + "\n"
                    + "<!-- hadalis:todo:end -->\n"
                )
                with self.assertRaises(obsidian_todo.TodoError) as error:
                    obsidian_todo.toggle_basic_task(
                        str(vault), "Hadalis/Todo.md",
                        scan["tasks"][0]["id"], scan["document"]["sha256"],
                    )
                self.assertEqual(error.exception.code, "rich_task_required")

    def test_delete_can_remove_rich_task_without_completion_semantics(self):
        vault, path, scan = self.scan(
            """# Before
<!-- hadalis:todo:start -->
- [ ] recurring 🔁 every day
- [ ] keep
<!-- hadalis:todo:end -->
# After
"""
        )
        result = obsidian_todo.delete_task(
            str(vault), "Hadalis/Todo.md",
            scan["tasks"][0]["id"], scan["document"]["sha256"],
        )
        text = path.read_text(encoding="utf-8")
        self.assertNotIn("recurring", text)
        self.assertIn("- [ ] keep", text)
        self.assertIn("# Before", text)
        self.assertIn("# After", text)
        self.assertEqual([t["content"] for t in result["tasks"]], ["keep"])

    def test_add_requires_document_and_managed_hashes(self):
        vault, path, scan = self.scan(
            """# Before
<!-- hadalis:todo:start -->
- [ ] existing
<!-- hadalis:todo:end -->
# After
"""
        )
        result = obsidian_todo.add_basic_task(
            str(vault), "Hadalis/Todo.md", "new task",
            scan["document"]["sha256"], scan["managed"]["sha256"],
        )
        text = path.read_text(encoding="utf-8")
        self.assertIn("- [ ] existing\n- [ ] new task\n<!-- hadalis:todo:end -->", text)
        self.assertTrue(text.startswith("# Before\n"))
        self.assertTrue(text.endswith("# After\n"))
        self.assertEqual(len(result["tasks"]), 2)

    def test_add_rejects_multiline_text(self):
        vault, _, scan = self.scan(
            "<!-- hadalis:todo:start -->\n<!-- hadalis:todo:end -->\n"
        )
        with self.assertRaises(obsidian_todo.TodoError) as error:
            obsidian_todo.add_basic_task(
                str(vault), "Hadalis/Todo.md", "one\ntwo",
                scan["document"]["sha256"], scan["managed"]["sha256"],
            )
        self.assertEqual(error.exception.code, "invalid_task_text")

    def test_stale_document_hash_fails_without_writing(self):
        vault, path, scan = self.scan(
            """<!-- hadalis:todo:start -->
- [ ] task
<!-- hadalis:todo:end -->
"""
        )
        path.write_text(
            """external
<!-- hadalis:todo:start -->
- [ ] task
<!-- hadalis:todo:end -->
""",
            encoding="utf-8",
        )
        external = path.read_bytes()
        with self.assertRaises(obsidian_todo.TodoError) as error:
            obsidian_todo.toggle_basic_task(
                str(vault), "Hadalis/Todo.md",
                scan["tasks"][0]["id"], scan["document"]["sha256"],
            )
        self.assertEqual(error.exception.code, "conflict")
        self.assertEqual(path.read_bytes(), external)

    def test_stale_task_id_fails_without_writing(self):
        vault, path, scan = self.scan(
            """<!-- hadalis:todo:start -->
- [ ] task
<!-- hadalis:todo:end -->
"""
        )
        current = obsidian_todo.scan_note(str(vault), "Hadalis/Todo.md")
        with self.assertRaises(obsidian_todo.TodoError) as error:
            obsidian_todo.toggle_basic_task(
                str(vault), "Hadalis/Todo.md",
                "deadbeef", current["document"]["sha256"],
            )
        self.assertEqual(error.exception.code, "conflict")
        self.assertIn("- [ ] task", path.read_text(encoding="utf-8"))

    def test_atomic_write_preserves_file_mode(self):
        vault, path, scan = self.scan(
            """<!-- hadalis:todo:start -->
- [ ] task
<!-- hadalis:todo:end -->
"""
        )
        path.chmod(0o640)
        obsidian_todo.toggle_basic_task(
            str(vault), "Hadalis/Todo.md",
            scan["tasks"][0]["id"], scan["document"]["sha256"],
        )
        self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o640)


if __name__ == "__main__":
    unittest.main()
