#!/usr/bin/env python3
"""Behavior checks for the development-only parser spike.

Set HADALIS_WORKFLOW_GRAMMAR to the library built by build-parser.sh.
No downloads or builds happen inside the canonical local validator.
"""

from dataclasses import replace
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

from corpus import inspect
from native import Parser, insertion, verify_ranges
from semantics import extract


GRAMMAR = os.environ.get("HADALIS_WORKFLOW_GRAMMAR")
SAMPLE = b'''pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
Item {
    id: root
    // Preserve this comment and its spacing.
    required property int index
    property alias childWidth: child.width
    readonly property int limit: 42
    property var current: service.activePlayer
    signal changed(int value)
    onChanged: value => { root.width = value }
    function reset(): void { root.width = 0 }
    component Inner: Item { property string label: "inner" }
    component Outer: Item {
        Inner { id: child }
    }
    Loader { id: lazy; active: false; sourceComponent: Component { Rectangle {} } }
    LazyLoader { active: false; component: Item {} }
    Connections { target: service; function onChanged() { root.reset() } }
    Binding { target: root; property: "width"; value: 42 }
    anchors { left: parent.left; right: parent.right }
    Behavior on opacity { NumberAnimation {} }
    Component.onCompleted: { root.width = Qt.binding(() => root.limit) }
}
'''


@unittest.skipUnless(GRAMMAR, "optional native Spike A: set HADALIS_WORKFLOW_GRAMMAR (see README)")
class SpikeA(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if not Path(GRAMMAR).is_file():
            raise RuntimeError("HADALIS_WORKFLOW_GRAMMAR does not point to a built grammar")
        cls.parser = Parser(GRAMMAR)

    @classmethod
    def tearDownClass(cls):
        cls.parser.close()

    def entries(self, source=SAMPLE):
        with self.parser.parse(source) as (_, nodes):
            return extract("fixture.qml", source, nodes)

    def test_representative_constructs_and_incremental_reparse(self):
        result = inspect(self.parser, "fixture.qml", SAMPLE)
        self.assertFalse(result["diagnostics"])
        for kind in ("binding", "property", "handler-candidate", "connections", "lifecycle", "component", "inline-component", "explicit-binding"):
            self.assertGreater(result["counts"][kind], 0)
        self.assertEqual(result["features"]["inline-component"], 2)
        self.assertTrue(result["anchors_stable_after_prefix"])

    def test_exact_binding_and_handler_ranges(self):
        entries = self.entries()["entries"]
        current = next(e for e in entries if e["name"] == "current")
        self.assertEqual(SAMPLE[slice(*current["value_range"])].strip(), b"service.activePlayer")
        handlers = [e for e in entries if e["name"] == "onChanged"]
        self.assertEqual(len(handlers), 2)
        self.assertTrue(any(e.get("body_range") for e in handlers))

    def test_grouped_binding_is_opaque_including_descendants(self):
        entries = self.entries()["entries"]
        group = next(e for e in entries if e["name"] == "anchors")
        self.assertEqual(group["kind"], "opaque")
        left = next(e for e in entries if e["name"] == "left")
        self.assertTrue(left["opaque_context"])
        self.assertFalse(left["editable"])

    def test_imperative_rebinding_is_not_a_declarative_wire(self):
        entry = next(e for e in self.entries()["entries"] if e["name"] == "Qt.binding")
        self.assertEqual(entry["kind"], "opaque")
        self.assertIn("imperative-rebinding", entry["reason"])

    def test_no_entry_claims_edit_safety(self):
        self.assertTrue(all(not e["editable"] for e in self.entries()["entries"]))

    def test_scoped_ids_do_not_collide_across_inline_components(self):
        source = b"import QtQuick\nItem { component A: Item { id: child; property int x: 1 } component B: Item { id: child; property int x: 2 } }"
        entries = self.entries(source)["entries"]
        properties = [e for e in entries if e["name"] == "x"]
        self.assertEqual(len({e["anchor"] for e in properties}), 2)

    def test_ambiguous_member_anchors_are_reported(self):
        result = self.entries(b"import QtQuick\nItem { width: 1; width: 2 }")
        self.assertTrue(result["anchor_collisions"])
        self.assertTrue(all(not e["anchor_unique"] for e in result["entries"] if e["name"] == "width"))

    def test_invalid_source_reports_error_or_missing_tokens(self):
        for source in (b"import QtQuick\nItem { width: ", b"import QtQuick\nItem { property int width: }"):
            with self.subTest(source=source):
                self.assertTrue(self.entries(source)["diagnostics"])

    def test_unicode_crlf_bom_comments_and_no_final_newline(self):
        source = '\ufeff// tiếng Việt 🌊\r\nimport QtQuick\r\nItem { property string s: "𝄞界" /* τέλος */ }'.encode()
        result = inspect(self.parser, "unicode.qml", source)
        self.assertFalse(result["diagnostics"])
        self.assertTrue(result["preservation"]["byte_identical"])
        self.assertEqual(result["preservation"]["comments"], 2)

    def test_invalid_utf8_is_rejected(self):
        with self.assertRaises(UnicodeError):
            with self.parser.parse(b"Item { //\xff\n }"):
                pass

    def test_range_checker_detects_bad_offsets(self):
        with self.parser.parse(SAMPLE) as (_, nodes):
            damaged = [replace(nodes[0], end=len(SAMPLE) + 1), *nodes[1:]]
            with self.assertRaises(AssertionError):
                verify_ranges(SAMPLE, damaged)

    def test_unrelated_line_inside_object_preserves_anchors(self):
        offset, text = SAMPLE.index(b"    readonly"), b"    // unrelated\n\n"
        moved = SAMPLE[:offset] + text + SAMPLE[offset:]
        with self.parser.parse(SAMPLE) as (tree, nodes):
            before = extract("fixture.qml", SAMPLE, nodes)
            with self.parser.parse(moved, tree, insertion(SAMPLE, offset, text)) as (_, incremental):
                after = extract("fixture.qml", moved, incremental)
            with self.parser.parse(moved) as (_, fresh):
                self.assertEqual(fresh, incremental)
        self.assertEqual([e["anchor"] for e in before["entries"]], [e["anchor"] for e in after["entries"]])

    def test_same_named_js_function_does_not_become_qml_action(self):
        result = self.entries(b"import QtQuick\nItem { function outer() { function inner() {} } }")
        self.assertEqual([e["name"] for e in result["entries"] if e["kind"] == "function"], ["outer"])

    def test_retained_bytes_preserve_opaque_script(self):
        source = b'''import QtQuick\nItem { property var f: (() => { const re = /a{2}/g; return `value ${1+2}` })() } // tail'''
        result = inspect(self.parser, "script.qml", source)
        self.assertFalse(result["diagnostics"])
        self.assertTrue(result["preservation"]["byte_identical"])

    def test_nested_inline_declaration_is_rejected_despite_clean_cst(self):
        source = b"import QtQuick\nItem { component A: Item { component B: Item {} } }\n"
        with self.parser.parse(source) as (_, nodes):
            self.assertFalse(any(n.error or n.missing for n in nodes))
            result = extract("nested.qml", source, nodes)
        self.assertEqual(result["diagnostics"][0]["reason"], "unsupported-nested-inline-component")
        nested = next(e for e in result["entries"] if e["name"] == "B")
        self.assertTrue(nested["opaque_context"])
        self.assertFalse(nested["editable"])

    def test_qt_diagnostic_oracle_for_nested_inline_declaration(self):
        candidates = ["/usr/lib/qt6/bin/qmllint", "/usr/lib/x86_64-linux-gnu/qt6/bin/qmllint", "qmllint6"]
        tool = next((shutil.which(p) for p in candidates if shutil.which(p)), None)
        if not tool:
            self.skipTest("Qt 6 qmllint unavailable; native rejection fixture still runs")
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "Nested.qml"
            path.write_bytes(b"import QtQuick\nItem { component A: Item { component B: Item {} } }\n")
            result = subprocess.run([tool, str(path)], capture_output=True, text=True, timeout=20)
        # This Qt version may exit zero; acceptance must examine diagnostics.
        self.assertIn("[syntax]", result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)
