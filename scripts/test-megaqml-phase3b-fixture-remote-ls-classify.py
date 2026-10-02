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
    bad_reason, bad_shape = D["observe"](malformed, identity, journal, uid)
    assert bad_reason == "listing_format_unqualified"
    assert bad_shape == (
        "unrecognized", "unknown", "incomplete", "absent", "unknown")


# Source-format fingerprint is diagnostics ONLY: no relaxed acceptance.
fingerprint = D["format_fingerprint"]
assert fingerprint(header + folder) == (
    "exact", "all_four_flag_candidate", "lf", "absent", "one")
assert fingerprint(header + folder + file) == (
    "exact", "all_four_flag_candidate", "lf", "absent", "two")
assert fingerprint(b"FLAGS VERS SIZE DATE HANDLE NAME\n" + folder) == (
    "whitespace_variant", "all_four_flag_candidate", "lf", "absent", "one")
assert fingerprint(b"FLAGS VERS SIZE DATE EXTRA NAME\n" + folder) == (
    "flags_prefix_other", "all_four_flag_candidate", "lf", "absent", "one")
assert fingerprint(b"FLAGS VERS SIZE DATE NAME\r\n" + folder) == (
    "exact", "all_four_flag_candidate", "carriage_return", "absent", "one")
assert fingerprint(header + b"---- 1 5 Jan 02 2026 PRIVATE_\xc3\xa9\n") == (
    "exact", "all_four_flag_candidate", "lf", "present", "one")
assert fingerprint(b"---- 1 5 JAN 02 2026 PRIVATE\n") == (
    "headerless_row_candidate", "all_four_flag_candidate",
    "lf", "absent", "one")
assert fingerprint(header + b"\x00\n") == (
    "exact", "no_four_flag_candidate", "lf", "present", "one")
assert fingerprint(header) == (
    "exact", "none", "lf", "absent", "zero")
assert parse(header + b"PRIVATE\x00\n") is None
assert parse(header + b"---- 1 5 Jan 02 2026 PRIVATE_\xc3\xa9\n") is None

# The new exact-path grammar is independent from the old generic ls-l
# parser; it does not accept a header-plus-row or an arbitrary path.
remote = "/MEGAQML-Phase3b-Fixture-" + "b" * 32
prefix = remote.encode("ascii") + b": \n"
header_only = b"FLAGS VERS SIZE DATE NAME\n"
pair = D["classify_exact_pair"]
assert pair(prefix, prefix + header_only, remote) == (
    "prefix_header_only_candidate")
assert pair(b"\n", header_only, remote) == (
    "direct_header_only_candidate")
for plain, detailed, path in (
    (prefix, prefix + header_only + folder, remote),
    (prefix, prefix + b"BAD\n", remote),
    (prefix + b"PRIVATE\n", prefix + header_only, remote),
    (prefix, prefix + header_only, remote + "OTHER"),
    (prefix, prefix + header_only, "/NOT_DISPOSABLE"),
):
    assert pair(plain, detailed, path) == "mismatch"

with tempfile.TemporaryDirectory() as td:
    root = Path(td)
    local = root / "local"
    local.mkdir(mode=0o700)
    journal = {"remote": remote, "local": str(local),
               "stage": "sync_detached"}
    uid = D["os"].getuid()
    calls = []
    checks = [0]
    def identity():
        checks[0] += 1
        return True
    def runner(argv):
        v = tuple(argv)
        calls.append(v)
        if v == D["F"]["TWO"]:
            return 0, b"\n", b"", None
        if v == ("ls", "/"):
            return 0, remote[1:].encode("ascii") + b"\n", b"", None
        if v == ("ls", remote):
            return 0, prefix, b"", None
        if v == ("ls", "-l", remote):
            return 0, prefix + header_only, b"", None
        raise AssertionError("UNAUTHORIZED_VENDOR_COMMAND")
    assert D["observe_prefix_pair"](runner, identity, journal, uid) == (
        "prefix_pair_consistent_unqualified",
        "prefix_header_only_candidate")
    assert calls == [D["F"]["TWO"], ("ls", "/"),
                     ("ls", remote), ("ls", "-l", remote)]
    assert checks[0] == 5
    calls.clear()
    checks[0] = 0
    def with_child(argv):
        v = tuple(argv)
        if v == ("ls", "-l", remote):
            return 0, prefix + header_only + folder, b"", None
        return runner(argv)
    assert D["observe_prefix_pair"](with_child, identity, journal, uid) == (
        "prefix_pair_mismatch_unqualified", "mismatch")
    journal["stage"] = "sync_detached"
    assert len(list(root.iterdir())) == 1

source = Path(D["__file__"]).read_text() if "__file__" in D else (
    Path(__file__).with_name("megaqml-phase3b-fixture-remote-ls-classify.py")
    .read_text())
assert '--approved-one-server-start-and-ls' not in source
assert '--approved-additional-one-ls-format-probe' not in source
assert '--approved-journal-exact-prefix-pair-only' in source
assert 'START_DISPOSABLE_PREFIX_ONLY' in source
assert "REMOTE_CLEANUP_AUTHORIZED=NO" in source

out = io.StringIO()
with contextlib.redirect_stdout(out):
    D["emit"]("listing_format_unqualified", shape=fingerprint(header + folder))
report = out.getvalue()
for secret in ("PRIVATE_FOLDER", "PRIVATE_FILE", "PRIVATE_REMOTE",
               "PRIVATE_DIAGNOSTIC"):
    assert secret not in report
assert "FORMAT_HEADER=exact" in report
assert "EXACT_PATH_LISTING_PAIR=not_tested" in report
out2 = io.StringIO()
with contextlib.redirect_stdout(out2):
    D["emit"]("prefix_pair_consistent_unqualified",
              pair="prefix_header_only_candidate")
report2 = out2.getvalue()
assert "EXACT_PATH_LISTING_PAIR=prefix_header_only_candidate" in report2
assert "REMOTE_CLEANUP_AUTHORIZED=NO" in report2
assert "PRIVATE_FOLDER" not in report2
assert "FORMAT_ROW_PREFIXES=all_four_flag_candidate" in report
assert "REMOTE_CLEANUP_AUTHORIZED=NO" in report
assert "JOURNAL_CHANGED=NO" in report
assert "PHASE3B=UNQUALIFIED" in report

# The original-account gate uses only synthetic PTYs and an exact token.
# An assertion is not cryptographic proof of historical account identity.
import os
import pty
import tty
import inspect

def private_ack(line):
    master, slave = pty.openpty()
    try:
        tty.setraw(slave)
        os.write(master, line.encode("ascii") + b"\n")
        return D["tty_original_account_attestation"](
            open_tty=lambda path, flags: os.dup(slave))
    finally:
        os.close(master)
        os.close(slave)

assert private_ack("VERIFIED_SAME_ORIGINAL_ACCOUNT") is True
assert private_ack("VERIFIED_SAME_ORIGINAL_ACCOUNT_EXTRA") is False
assert private_ack(" VERIFIED_SAME_ORIGINAL_ACCOUNT") is False
assert private_ack("START_DISPOSABLE_PREFIX_ONLY") is False
assert D["tty_original_account_attestation"](
    open_tty=lambda path, flags: (_ for _ in ()).throw(OSError())) is False
main_source = inspect.getsource(D["main"])
assert main_source.index("if not tty_original_account_attestation():") < main_source.index("subprocess.Popen(")

print("PASS MegaQML fixture ls-l fake-only contract")
