#!/usr/bin/env python3
"""INERT, negative-and-positive synthetic tests; never launches Quickshell."""
import ast
import hashlib
from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts/wull-private-minimal-boot-log-review.py"
raw = SCRIPT.read_bytes()
digest = hashlib.sha1(b"blob " + str(len(raw)).encode() + b"\0" + raw).hexdigest()
assert digest == "0557565ca81685aa7e1bf2a2fd820e0a58d9742c", "postmortem code changed after source review"
ast.parse(raw.decode("utf-8"))
m = runpy.run_path(str(SCRIPT), run_name="wull_private_minimal_log_review_inert")
assert m["OLD_SOURCE"] == "284001594ca472ec6a098956754ad13bfa977e7a"
assert m["OLD_PROBE_BLOB"] == "edd28683dc1ce679f24aa460e914cfad5abdc0a6"
assert m["LABELS"] == ("OFFSCREEN_FILE", "OFFSCREEN_DIRECTORY", "MINIMAL_FILE")
assert m["MAX_BYTES"] == 524288
classify = m["classify"]
r = classify(
    'qt.core.plugin: looking at "/home/PRIVATE/plugin/libqoffscreen.so"\n'
    'qt.core.plugin: Found metadata in lib "/home/PRIVATE/plugin"\n'
    'qt.core.plugin: loaded library "/home/PRIVATE/plugin"\n'
    'WULL_MINIMAL_CHILD_EXIT=SIGNAL\n')
assert r["FAILURES"] == "NO_EXPLICIT_FAILURE_PATTERN"
assert "QT_PLUGIN_DISCOVERY" in r["QT_EVENTS"]
assert "QT_PLUGIN_LOADED" in r["QT_EVENTS"]
assert r["QML_MARKER"] == "NONE" and r["CHILD_EXIT"] == "SIGNAL"
assert r["EXPLICIT_SIGNALS"] == "NONE_IN_LOG"
failure = classify(
    "qt.qpa.plugin: Could not load the Qt platform plugin 'offscreen' "
    "even though it was found.\n"
    "This application failed to start because no Qt platform plugin "
    "could be initialized.\n"
    "file size limit exceeded\n"
    "WULL_MINIMAL_QML_COMPONENT_LOADED\n"
    "WULL_MINIMAL_CHILD_EXIT=SIGNAL\nSIGABRT\n"
    "/home/PRIVATE/session X=638.22 TOKEN=SECRET\n")
assert "QPA_CANNOT_LOAD" in failure["FAILURES"]
assert "QPA_NO_PLATFORM_INITIALIZED" in failure["FAILURES"]
assert "RESOURCE_LIMIT" in failure["FAILURES"]
assert failure["QML_MARKER"] == "ONE"
assert failure["EXPLICIT_SIGNALS"] == "SIGABRT"
private_output = str(failure)
for forbidden in ("/home/", "PRIVATE", "638.22", "SECRET"):
    assert forbidden not in private_output, forbidden
duplicate = classify("WULL_MINIMAL_QML_COMPONENT_LOADED\n"
                     "WULL_MINIMAL_QML_COMPONENT_LOADED\n"
                     "WULL_MINIMAL_CHILD_EXIT=SIGNAL\n"
                     "WULL_MINIMAL_CHILD_EXIT=SIGNAL\n")
assert duplicate["QML_MARKER"] == "MULTIPLE"
assert duplicate["CHILD_EXIT"] == "NOT_UNIQUELY_RECORDED"
assert classify("")["CHILD_EXIT"] == "NOT_UNIQUELY_RECORDED"
for untrusted in (None, 42, {}, [], b"raw"):
    try:
        classify(untrusted)
    except ValueError:
        pass
    else:
        raise AssertionError("unreviewed log type accepted")
try:
    classify("x" * (m["MAX_BYTES"] + 1))
except ValueError:
    pass
else:
    raise AssertionError("unbounded log accepted")
try:
    classify("a\n" * 15001)
except ValueError:
    pass
else:
    raise AssertionError("unbounded log line count accepted")
source = raw.decode("utf-8")
assert "subprocess.Popen" not in source
assert "quickshell" not in source or "subprocess.run" in source
assert '["git", "-C", str(repo), *args]' in source
assert 'git(repo, "rev-parse", "HEAD") != OLD_SOURCE' in source
assert 'git(repo, "rev-parse", "HEAD:" + OLD_PROBE_PATH) != OLD_PROBE_BLOB' in source
assert 'stat.S_IMODE(st.st_mode) & 0o077' in source
assert "if len(raw_bytes) > MAX_BYTES:" in source
assert "qt.qpa.plugin" in source
assert "GATE=READ_ONLY_EXISTING_MINIMAL_LOGS_CLASSIFIED" in source
print("WULL_MINIMAL_BOOT_LOG_REVIEW_INERT_PASS")
