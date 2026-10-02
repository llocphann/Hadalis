#!/usr/bin/env python3
"""Inert, no-Qt synthetic negative tests of retained Quickshell log postmortem."""
import ast
import hashlib
from pathlib import Path
import runpy
import tempfile

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts/wull-private-qslog-postmortem.py"
raw = SCRIPT.read_bytes()
blob = hashlib.sha1(b"blob " + str(len(raw)).encode() + b"\0" + raw).hexdigest()
assert blob == "edd1b35e4a20706daf8d72ee8d8d0ffec7943e08"
ast.parse(raw.decode("utf-8"))
module = runpy.run_path(str(SCRIPT), run_name="wull_qslog_postmortem_inert")
assert module["SOURCE"] == "7c9e01dcd3db964a837b12755b088dd2594c9b6d"
assert module["FINGERPRINT_BLOB"] == "2c7a4e069492c1a72d321f91fa509d9d94736002"
assert module["LABELS"] == (
    "MINIMAL_DYNAMIC_ENV", "FROZEN_DYNAMIC_ENV", "FROZEN_HISTORICAL_ENV")
assert module["MAX_LOG"] == 524288
runtime = Path("/run/user/1000")
config = Path("/private/boot-controls/minimal_dynamic_env/shell/shell.qml")
qslog = runtime / "quickshell/by-id/abc1234/log.qslog"
banners = (
    f'INFO: Launching config: "{config}"\n'
    'INFO: Shell ID: "0123456789abcdef0123456789abcdef" '
    'Path ID "0123456789abcdef0123456789abcdef"\n'
    f'INFO: Saving logs to "{qslog}"\n')
assert module["banner"](banners, config, runtime) == (
    "STANDARD_3_BANNERS", qslog)
assert module["banner"](banners, Path("/other/shell.qml"), runtime) == (
    "UNVERIFIED_BANNER", None)
assert module["banner"](banners.replace("log.qslog", "private.json"),
                        config, runtime) == ("UNVERIFIED_BANNER", None)
assert module["banner"](banners.replace("abc1234", "../foreign"),
                        config, runtime) == ("UNVERIFIED_BANNER", None)
assert module["banner"](banners.replace("Shell ID:", "Private ID:"),
                        config, runtime) == ("NONSTANDARD", None)
assert module["banner"](banners + "fourth private secret line\n",
                        config, runtime) == ("NONSTANDARD", None)
with tempfile.TemporaryDirectory(prefix="wull-qslog-inert-") as tmp:
    logfile = Path(tmp) / "log.qslog"
    assert module["safe_log"](logfile) == "NOT_AVAILABLE"
    logfile.write_bytes(b"fake binary private content\n")
    assert module["safe_log"](logfile) == "AVAILABLE"
    assert module["safe_log"](None) == "NO_VERIFIED_PATH"
    link = Path(tmp) / "link.qslog"
    link.symlink_to(logfile)
    assert module["safe_log"](link) == "NOT_AVAILABLE"
assert module["decoded_categories"]("fake secret", lambda x: [
    (["UNCLASSIFIED"], ["NONE"], "SHORT")]) == [
        (["UNCLASSIFIED"], ["NONE"], "SHORT")]
assert module["decoded_categories"]("x" * (module["MAX_LOG"] + 1),
                                    lambda x: []) is None
assert "subprocess.Popen" not in raw.decode("utf-8")
assert "qs_log_argv" in raw.decode("utf-8")
assert '["git", "-C"' in raw.decode("utf-8")
assert "PRIVATE_EXISTING_QSLOG_POSTMORTEM_ONLY" in raw.decode("utf-8")
print("WULL_PRIVATE_QSLOG_POSTMORTEM_INERT_PASS")
