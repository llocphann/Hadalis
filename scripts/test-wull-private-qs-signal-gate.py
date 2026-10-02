#!/usr/bin/env python3
"""Inert exact-blob, negative, privacy and conditional QS signal gate tests."""
import ast
import hashlib
from pathlib import Path
import runpy
import signal
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts/wull-private-qs-signal-gate.py"
raw = SCRIPT.read_bytes()
assert hashlib.sha1(
    b"blob " + str(len(raw)).encode() + b"\0" + raw
).hexdigest() == "2380e7c2a46569e8c21ca3f0c4cea0ac9441f61f", "private QS signal gate source not reviewed"
source = raw.decode("utf-8")
ast.parse(source)
m = runpy.run_path(str(SCRIPT), run_name="wull_qs_signal_inert_contract")
assert m["OLD_PIN"] == "edd28683dc1ce679f24aa460e914cfad5abdc0a6"
assert m["FROZEN_PIN"] == "0dd833ed05d54e9d1045553a1da8be8f66b6511a"
assert m["LOW_LIMIT"] == 524288
assert m["HIGH_LIMIT"] == 8388608
assert m["QS_VERSION"] == "0.3.1"
assert m["STATES"] == ("ZERO", "NONZERO", "SIGNAL", "TIMEOUT", "OSERROR")
classify = m["classify_return"]
assert classify(0) == ("ZERO", "NONE")
assert classify(2) == ("NONZERO", "NONE")
assert classify(None) == ("TIMEOUT", "NONE")
assert classify(-signal.SIGABRT) == ("SIGNAL", "SIGABRT")
assert classify(-signal.SIGXFSZ) == ("SIGNAL", "SIGXFSZ")
assert classify(-signal.SIGSEGV) == ("SIGNAL", "SIGSEGV")
assert classify(-signal.SIGSYS) == ("SIGNAL", "SIGSYS")
read = m["receipt_read"]
with tempfile.TemporaryDirectory(prefix="wull-signal-inert-") as name:
    root = Path(name)
    p = root / "test.private.txt"
    for kind, sig in (
            ("ZERO", "NONE"), ("NONZERO", "NONE"),
            ("SIGNAL", "SIGABRT"), ("SIGNAL", "SIGXFSZ"),
            ("TIMEOUT", "NONE"), ("OSERROR", "NONE")):
        p.write_text("STATE=" + kind + "\nQS_SIGNAL=" + sig + "\n",
                     encoding="ascii")
        assert read(p) == (kind, sig)
    for unsafe in (
            "STATE=SIGNAL\nQS_SIGNAL=NONE\n",
            "STATE=ZERO\nQS_SIGNAL=SIGABRT\n",
            "STATE=SIGNAL\nQS_SIGNAL=SIGUSR1\n",
            "STATE=SIGNAL\nQS_SIGNAL=SIGXFSZ\n/home/PRIVATE\n",
            "STATE=SIGNAL\nQS_SIGNAL=SIGXFSZ"):
        p.write_text(unsafe, encoding="ascii")
        assert read(p) is None
    link = root / "symlink.private.txt"
    link.symlink_to(p)
    assert read(link) is None
    assert read(root / "nonexistent") is None
# Same original minimal QML and isolated environment; no Wull import here.
assert 'previous["QML"]' in source
assert 'previous["QML"].count("WULL_MINIMAL_QML_COMPONENT_LOADED") != 1' in source
assert 'borrowed["guard"](state)' in source
assert 'borrowed["audit"](source)' in source
assert 'if outcome == ("SIGNAL", "SIGXFSZ"):' in source
assert '"CONDITIONAL_CONTROL=NOT_TRIGGERED"' in source
assert 'resource.setrlimit(resource.RLIMIT_CORE, (0, 0))' in source
assert 'resource.setrlimit(resource.RLIMIT_FSIZE, (max_bytes, max_bytes))' in source
assert '"WAYLAND_DISPLAY", "NIRI_SOCKET", "DISPLAY"' in source
assert '"QT_QPA_PLATFORM": "offscreen"' in source
assert '"QT_DEBUG_PLUGINS": "1"' in source
assert '[qs, "--verbose", "--path", shell]' in source
assert '"QS_SIGNAL=" + sig' in source
assert 'cleanup(proc.pid)' in source
assert 'borrowed["clean"]()' in source
assert "git push" not in source and "xdotool" not in source
print("WULL_PRIVATE_QS_SIGNAL_INERT_PASS")
