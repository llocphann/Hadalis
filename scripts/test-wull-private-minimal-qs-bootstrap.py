#!/usr/bin/env python3
"""Inert synthetic source pin, private output categories and launcher contract."""
import ast
import hashlib
from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts/wull-private-minimal-qs-bootstrap.py"
raw = SCRIPT.read_bytes()
sha = hashlib.sha1(b"blob " + str(len(raw)).encode() + b"\0" + raw).hexdigest()
assert sha == "edd28683dc1ce679f24aa460e914cfad5abdc0a6", "unreviewed private bootstrap source"
ast.parse(raw.decode("utf-8"))
m = runpy.run_path(str(SCRIPT), run_name="wull_inert_minimal_boot")
assert m["QS_VERSION"] == "0.3.1"
assert m["MAX_LOG"] == 524288
assert m["PROBES"] == (
    ("OFFSCREEN_FILE", "offscreen", "file"),
    ("OFFSCREEN_DIRECTORY", "offscreen", "directory"),
    ("MINIMAL_FILE", "minimal", "file"),
)
assert m["FROZEN_PIN"] == "0dd833ed05d54e9d1045553a1da8be8f66b6511a"
assert 'import QtQuick' in m["QML"] and 'import Quickshell' in m["QML"]
assert m["QML"].count(m["QML_MARKER"]) == 1
assert "PanelWindow" not in m["QML"] and "WaterDropletBody" not in m["QML"]
interpret = m["interpret_log"]
assert interpret("") == {
    "QML_MARKER": "NONE", "QS_CHILD_EXIT": "UNKNOWN",
    "ERROR_CLASSES": "NO_RECOGNIZED_ERROR"}
assert interpret("INFO " + m["QML_MARKER"] + "\n"
                 + m["CHILD_MARKER"] + "ZERO\n") == {
    "QML_MARKER": "ONE", "QS_CHILD_EXIT": "ZERO",
    "ERROR_CLASSES": "NO_RECOGNIZED_ERROR"}
negative = interpret(m["QML_MARKER"] + "\n" + m["QML_MARKER"]
                     + "\n" + m["CHILD_MARKER"] + "ZERO\n"
                     + m["CHILD_MARKER"] + "SIGNAL\n")
assert negative["QML_MARKER"] == "MULTIPLE"
assert negative["QS_CHILD_EXIT"] == "UNKNOWN"
assert m["child_exit_status"](0) == "ZERO"
assert m["child_exit_status"](2) == "NONZERO"
assert m["child_exit_status"](-11) == "SIGNAL"
assert m["child_exit_status"](None) == "TIMEOUT"
sample = "private path /home/user/secret x=9876 qt.qpa.plugin failed"
labels = m["categorized_log"](sample)
assert "QT_PLATFORM_OR_PLUGIN" in labels and "GENERAL_ERROR" in labels
assert "/home/" not in str(labels) and "9876" not in str(labels)
try:
    m["categorized_log"]("x" * (m["MAX_LOG"] + 1))
except ValueError:
    pass
else:
    raise AssertionError("unbounded diagnostic output accepted")
for forbidden in ("subprocess.Popen" in m["QML"],
                  "WAYLAND_DISPLAY" in m["QML"],
                  "NIRI_SOCKET" in m["QML"]):
    assert not forbidden
source = raw.decode("utf-8")
assert 'WAYLAND_DISPLAY", "NIRI_SOCKET", "DISPLAY"' in source
assert '"QML_IMPORT_PATH", "QML2_IMPORT_PATH"' in source
assert 'QT_DEBUG_PLUGINS": "1"' in source
assert 'QT_QPA_PLATFORM": qpa' in source
assert 'borrowed["guard"](state)' in source
assert 'borrowed["audit"](source)' in source
assert "os.killpg(pid, signal.SIGTERM)" in source
assert "resource.setrlimit(resource.RLIMIT_FSIZE, (MAX_LOG, MAX_LOG))" in source
assert '[qs, "--verbose", "--path", path]' in source
assert 'if sys.argv[1:2] == ["--child"]:' in source
assert '"git", "push"' not in source and "xdotool" not in source
print("WULL_MINIMAL_QS_BOOTSTRAP_INERT_PASS")
