#!/usr/bin/env python3
"""Inert synthetic coverage only: private Qt boot controls never launched."""
import ast
import hashlib
from pathlib import Path
import runpy
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts/wull-private-offscreen-boot-controls.py"
raw = SCRIPT.read_bytes()
blob = hashlib.sha1(b"blob " + str(len(raw)).encode() + b"\0" + raw).hexdigest()
assert blob == "7c0a29bcaac7d576615ce20bd1b15b021cb951c0", "unexpected private startup-control source"
ast.parse(raw.decode("utf-8"))
m = runpy.run_path(str(SCRIPT), run_name="wull_inert_boot_controls")
assert m["MAX_LOG"] == 262144
assert m["EXPECTED_QS"] == "0.3.1"
assert m["TESTS"] == (
    ("MINIMAL_DYNAMIC_ENV", "minimal", True, m["MINIMAL_MARKER"]),
    ("FROZEN_DYNAMIC_ENV", "frozen", True, m["FROZEN_MARKER"]),
    ("FROZEN_HISTORICAL_ENV", "frozen", False, m["FROZEN_MARKER"]),
)
assert m["FROZEN_PIN"] == "0dd833ed05d54e9d1045553a1da8be8f66b6511a"
assert m["FROZEN_FIXTURE_PIN"] == "11df91496a8bb9b18d79498e86d1f734d78dc574"
assert m["DYNAMIC_FIXTURE_PIN"] == "6e3b5402d32d263868c1ec688925adba0fd7250b"
assert 'import Quickshell' in m["MINIMAL_QML"]
assert 'import QtQuick' in m["MINIMAL_QML"]
assert m["MINIMAL_QML"].count(m["MINIMAL_MARKER"]) == 1
assert 'QT_QPA_PLATFORM": "offscreen"' in raw.decode()
assert '"WAYLAND_DISPLAY", "NIRI_SOCKET"' in raw.decode()
assert 'os.killpg(proc.pid, signal.SIGTERM)' in raw.decode()
assert "resource.setrlimit(resource.RLIMIT_FSIZE, (MAX_LOG, MAX_LOG))" in raw.decode()
assert 'if scrub_import:' in raw.decode()
assert 'env.pop(key, None)' in raw.decode()
assert "NO_COMPOSITOR_NO_INPUT" in raw.decode()
assert "git\", \"push" not in raw.decode() and 'os.system(' not in raw.decode()
assert m["classify_exit"](0) == "ZERO"
assert m["classify_exit"](5) == "NONZERO"
assert m["classify_exit"](-9) == "SIGNAL"
assert m["classify_exit"](None) == "TIMEOUT"

with tempfile.TemporaryDirectory(prefix="wull-boot-inert-") as tmp:
    log = Path(tmp) / "private.log"
    log.write_text("Quickshell loaded\nPRIVATE-DO-NOT-SHOW\n", encoding="utf-8")
    a = m["classify_log"](log, m["MINIMAL_MARKER"])
    assert a == ("NONE", "NO", "YES")
    log.write_text("WULL_PRIVATE_BOOT_CONTROL_OK\n", encoding="utf-8")
    assert m["classify_log"](log, m["MINIMAL_MARKER"]) == ("ONE", "NO", "NO")
    log.write_text(m["MINIMAL_MARKER"] + "\n" + m["MINIMAL_MARKER"] + "\n",
                   encoding="utf-8")
    assert m["classify_log"](log, m["MINIMAL_MARKER"]) == ("MULTIPLE", "NO", "NO")
    log.write_text(m["FROZEN_MARKER"] + "PRIVATE=123.45\n"
                   "WULL_OFFSCREEN_MOTION_INVALID\n", encoding="utf-8")
    assert m["classify_log"](log, m["FROZEN_MARKER"]) == ("ONE", "YES", "NO")
    assert "PRIVATE" not in str(m["classify_log"](log, m["FROZEN_MARKER"]))
print("WULL_BOOT_CONTROLS_INERT_PASS")
