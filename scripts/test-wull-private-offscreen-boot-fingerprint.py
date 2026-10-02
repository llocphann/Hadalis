#!/usr/bin/env python3
"""INERT negative/positive tests for private no-Qt boot-log fingerprint."""
import ast
import hashlib
from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "scripts/wull-private-offscreen-boot-fingerprint.py"
raw = SOURCE.read_bytes()
assert hashlib.sha1(
    b"blob " + str(len(raw)).encode() + b"\0" + raw
).hexdigest() == "2c7a4e069492c1a72d321f91fa509d9d94736002"
ast.parse(raw.decode("utf-8"))
module = runpy.run_path(str(SOURCE), run_name="wull_boot_fingerprint_inert")
classify = module["classify"]

assert module["MAX_BYTES"] == 524288
assert len(module["PATTERNS"]) == 12
assert classify("") == []
rows = classify("Quickshell started\n"
                "No configuration at /home/PRIVATE-USERNAME/config\n"
                "module PRIVATE_QML_MODULE not installed\n"
                "private token: TOP=923.4, x=72, /tmp/secret.json")
assert len(rows) == 4
assert "QUICKSHELL_MESSAGE" in rows[0][0]
assert "CONFIG_RESOLUTION" in rows[1][0]
assert "QML_IMPORT" in rows[2][0]
assert rows[3][0] == ["UNCLASSIFIED"]
assert rows[3][1] == ["NONE"]
# Everything returned is a static class, static safe term, or static length band.
allowed_classes = {name for name, _ in module["PATTERNS"]} | {"UNCLASSIFIED"}
allowed_terms = {name.upper() for name in module["SAFE_TERMS"]} | {"NONE"}
allowed_bands = {"SHORT", "MEDIUM", "LONG", "VERY_LONG"}
for classes, terms, band in rows:
    assert set(classes) <= allowed_classes
    assert set(terms) <= allowed_terms
    assert band in allowed_bands
    assert "PRIVATE" not in str((classes, terms, band))
    assert "/home/" not in str((classes, terms, band))
    assert "923" not in str((classes, terms, band))
for value in (None, 23, [], {}):
    try:
        classify(value)
    except ValueError:
        pass
    else:
        raise AssertionError("Unsafe log input accepted")
try:
    classify("q\n" * 1025)
except ValueError:
    pass
else:
    raise AssertionError("Unbounded private line count accepted")
for old_code in module["SAFE_TERMS"]:
    assert "/" not in old_code and "<" not in old_code
assert "subprocess.Popen" not in SOURCE.read_text()
assert "os.kill" not in SOURCE.read_text()
assert "raw.splitlines()" in SOURCE.read_text()
print("WULL_PRIVATE_BOOT_FINGERPRINT_INERT_PASS")
