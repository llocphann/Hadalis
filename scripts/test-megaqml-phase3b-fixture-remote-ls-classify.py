#!/usr/bin/env python3
"""Mock-only ls-l classifier and existing-fixture read boundary; never vendor."""
import contextlib
import io
from pathlib import Path
import runpy
import tempfile

D = runpy.run_path(str(Path(__file__).with_name(
    "megaqml-phase3b-fixture-remote-ls-classify.py")),
    run_name="inert_ls_test")
header = b"FLAGS    VERS SIZE DATE NAME\n"
folder = b"d--- - - 2026-10-02 12:00 PRIVATE_FOLDER\n"
file = b"---- 1 5 2026-10-02 12:00 PRIVATE_FILE\n"
parse = D["classify"]
assert parse(header) == ("none_observed", "zero")
assert parse(header + folder) == ("folders_only", "one")
assert parse(header + file) == ("files_only", "one")
assert parse(header + folder + file) == ("mixed", "two")
assert parse(header + file * 3) == ("files_only", "three_plus")
for invalid in (b"", b"\n", b"SECRET\n", header + b"PRIVATE_NAME\n",
                header + file + b"INJECTED\n", header + folder.replace(
                    b"PRIVATE_FOLDER", b"PRIVATE\rFOLDER"),
                header + file * 33, header + b"\xff\n"):
    assert parse(invalid) is None

with tempfile.TemporaryDirectory() as td:
    root = Path(td)
    local = root / "private-local"
    local.mkdir(mode=0o700)
    uid = D["os"].getuid()
    journal = {"local": str(local), "remote": "/PRIVATE_REMOTE",
               "stage": "sync_detached"}
    calls = []
    check = [0]
    def identity():
        check[0] += 1
        return True
    def runner(argv):
        v = tuple(argv)
        calls.append(v)
        if v == D["F"]["TWO"]:
            return 0, b"\n", b"", None
        if v == ("ls", "/"):
            return 0, b"PRIVATE_REMOTE\n", b"", None
        if v == ("ls", "-l", journal["remote"]):
            return 0, header + folder, b"", None
        raise AssertionError("UNAUTHORIZED_COMMAND")
    assert D["observe"](runner, identity, journal, uid) == (
        "listing_observed_unqualified", ("folders_only", "one"))
    assert calls == [D["F"]["TWO"], ("ls", "/"),
                     ("ls", "-l", journal["remote"])]
    assert check[0] == 4
    calls.clear()
    def mismatch(argv):
        if tuple(argv) == D["F"]["TWO"]:
            return 0, b"NOT_BLANK", b"", None
        raise AssertionError("LS_MUST_NOT_RUN")
    assert D["observe"](mismatch, identity, journal, uid)[0] == (
        "sync_changed_or_unavailable")
    assert not calls
    calls.clear()
    def malformed(argv):
        v = tuple(argv)
        calls.append(v)
        if v == D["F"]["TWO"]:
            return 0, b"\n", b"", None
        if v == ("ls", "/"):
            return 0, b"PRIVATE_REMOTE\n", b"", None
        if v == ("ls", "-l", journal["remote"]):
            return 0, b"PRIVATE_DIAGNOSTIC", b"", None
        raise AssertionError("UNAUTHORIZED_COMMAND")
    assert D["observe"](malformed, identity, journal, uid)[0] == (
        "listing_format_unqualified")

out = io.StringIO()
with contextlib.redirect_stdout(out):
    D["emit"]("listing_observed_unqualified", "folders_only", "one")
report = out.getvalue()
for secret in ("PRIVATE_FOLDER", "PRIVATE_FILE", "PRIVATE_REMOTE",
               "PRIVATE_DIAGNOSTIC"):
    assert secret not in report
assert "REMOTE_CLEANUP_AUTHORIZED=NO" in report
assert "JOURNAL_CHANGED=NO" in report
assert "PHASE3B=UNQUALIFIED" in report
print("PASS MegaQML fixture ls-l fake-only contract")
