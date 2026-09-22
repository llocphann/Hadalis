#!/usr/bin/env python3
"""Regression tests for filesystem-canonical Zettelkasten quick notes."""
from __future__ import annotations

import importlib.util
import tempfile
import unittest
from datetime import datetime, timezone
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent / "notes" / "zettelkasten.py"
SPEC = importlib.util.spec_from_file_location("zettelkasten", SCRIPT)
assert SPEC is not None and SPEC.loader is not None
zettel = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(zettel)


class ZettelkastenTests(unittest.TestCase):
    def vault(self) -> Path:
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        vault = Path(tmp.name) / "Vault"
        vault.mkdir()
        return vault

    def test_capture_creates_fleeting_zettel(self):
        vault = self.vault()
        now = datetime(2026, 9, 22, 11, 42, 31, tzinfo=timezone.utc)
        result = zettel.capture(
            str(vault), "00_Capture/03_Zettelkasten",
            "Atomic notes", "A short capture.", "Fleeting", now,
        )
        path = Path(result["noteFullPath"])
        self.assertTrue(path.is_file())
        self.assertEqual(
            result["notePath"],
            "00_Capture/03_Zettelkasten/20260922114231 - Atomic notes.md",
        )
        text = path.read_text(encoding="utf-8")
        self.assertIn('id: "20260922114231"', text)
        self.assertIn('type: "Fleeting"', text)
        self.assertIn("# Atomic notes", text)
        self.assertIn("A short capture.", text)

    def test_title_falls_back_to_first_body_line(self):
        vault = self.vault()
        result = zettel.capture(
            str(vault), "Zettel", "", "## Derived title\nBody",
            now=datetime(2026, 9, 22, 1, 2, 3, tzinfo=timezone.utc),
        )
        self.assertEqual(result["title"], "Derived title")
        self.assertIn("Derived title.md", result["notePath"])

    def test_filename_sanitizes_path_characters(self):
        vault = self.vault()
        result = zettel.capture(
            str(vault), "Zettel", "a/b:c", "",
            now=datetime(2026, 9, 22, 1, 2, 3, tzinfo=timezone.utc),
        )
        self.assertNotIn("/", Path(result["noteFullPath"]).name)
        self.assertIn("a b c", Path(result["noteFullPath"]).name)

    def test_collision_allocates_unique_filename(self):
        vault = self.vault()
        now = datetime(2026, 9, 22, 1, 2, 3, tzinfo=timezone.utc)
        first = zettel.capture(str(vault), "Zettel", "same", "", now=now)
        second = zettel.capture(str(vault), "Zettel", "same", "", now=now)
        self.assertNotEqual(first["noteFullPath"], second["noteFullPath"])
        self.assertTrue(second["noteFullPath"].endswith("-2.md"))

    def test_folder_escape_is_rejected(self):
        vault = self.vault()
        with self.assertRaises(zettel.ZettelError) as error:
            zettel.capture(str(vault), "../escape", "bad", "")
        self.assertEqual(error.exception.code, "invalid_folder")


if __name__ == "__main__":
    unittest.main()
