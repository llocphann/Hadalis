#!/usr/bin/env python3
"""Owner-local, one-shot classification of ls -l for the existing disposable fixture.

At most one explicitly approved dedicated server start, never a login.
No new fixture, deletion, journal mutation, raw vendor output or name publication.
Output is finite evidence, NOT cleanup authorization.
"""
import contextlib
import fcntl
import os
from pathlib import Path
import pwd
import re
import runpy
import stat
import subprocess
import sys
import time

HERE = Path(__file__).resolve().parent
I = runpy.run_path(str(HERE / "megaqml-phase3b-fixture-recovery-inspect.py"),
                   run_name="ls_only_inspection_dependency")
F, B = I["F"], I["B"]

REASONS = {
    "dedicated_environment_rejected", "journal_untrusted",
    "another_fixture_active", "journal_stage_unexpected",
    "trusted_package_rejected", "server_identity_ambiguous",
    "start_confirmation_rejected", "server_start_unconfirmed",
    "server_changed", "operator_confirmation_unavailable",
    "account_identity_unverified", "sync_changed_or_unavailable",
    "root_changed_or_unavailable", "local_changed_or_unavailable",
    "listing_unavailable", "listing_format_unqualified",
    "listing_header_only_unqualified", "listing_observed_unqualified",
    "supervisor_unavailable", "selftest_pass",
}
KINDS = {"unknown", "none_observed", "files_only", "folders_only",
         "mixed", "other_node_type"}
COUNTS = {"unknown", "zero", "one", "two", "three_plus"}

def emit(reason, kind="unknown", count="unknown", started=False):
    assert reason in REASONS and kind in KINDS and count in COUNTS
    print("MEGAQML_FIXTURE_REMOTE_LS_CLASSIFICATION")
    print("REASON=" + reason)
    print("NODE_KIND=" + kind)
    print("NODE_COUNT_BUCKET=" + count)
    print("SERVER_START_ATTEMPTED=" + str(started).lower())
    print("REMOTE_CLEANUP_AUTHORIZED=NO")
    print("JOURNAL_CHANGED=NO")
    print("RAW_PRIVATE_OUTPUT_PUBLISHED=NO")
    print("PHASE3B=UNQUALIFIED")

def classify(raw):
    """Fail closed on any unrecognized line or delimiter; never expose names."""
    if not raw or len(raw) > 16384 or b"\r" in raw or b"\x00" in raw:
        return None
    lines = raw.splitlines(keepends=True)
    if not lines or not re.fullmatch(
            rb"FLAGS +VERS +SIZE +DATE +NAME\n", lines[0]):
        return None
    rows = lines[1:]
    if not rows:
        return "none_observed", "zero"
    if len(rows) > 32:
        return None
    kinds = []
    for line in rows:
        m = re.fullmatch(
            rb"([d\-ribx])[et-][tp-][si-] +(?:-|[0-9]{1,3}|>999)"
            rb" +(?:-|[0-9]{1,18}) +[ -~]{4,256}\n", line)
        if not m:
            return None
        kinds.append(m.group(1))
    if all(k == b"d" for k in kinds):
        kind = "folders_only"
    elif all(k == b"-" for k in kinds):
        kind = "files_only"
    elif all(k in (b"d", b"-") for k in kinds):
        kind = "mixed"
    else:
        kind = "other_node_type"
    count = {1: "one", 2: "two"}.get(len(rows), "three_plus")
    return kind, count

def observe(runner, identity, journal, uid):
    """Only permitted data read is one sync list, root ls, exact ls -l."""
    if not identity():
        return "account_identity_unverified", None
    if F["strict_read"](runner, *F["TWO"]) != F["BLANK"]:
        return "sync_changed_or_unavailable", None
    if not identity():
        return "account_identity_unverified", None
    root = F["strict_read"](runner, "ls", "/")
    only = journal["remote"][1:].encode("ascii") + b"\n"
    if root != only:
        return "root_changed_or_unavailable", None
    if I["local_class"](Path(journal["local"]), uid) != "empty_owned":
        return "local_changed_or_unavailable", None
    if not identity():
        return "account_identity_unverified", None
    listing = F["strict_read"](runner, "ls", "-l", journal["remote"])
    if not identity():
        return "account_identity_unverified", None
    if listing is None:
        return "listing_unavailable", None
    result = classify(listing)
    if result is None:
        return "listing_format_unqualified", None
    if result == ("none_observed", "zero"):
        return "listing_header_only_unqualified", result
    return "listing_observed_unqualified", result

def named_server_guard(uid, executable):
    """Reject a suspicious dedicated-UID server or any unreadable process."""
    try:
        with os.scandir("/proc") as entries:
            for entry in entries:
                if not entry.name.isdecimal():
                    continue
                try:
                    status = (Path(entry.path) / "status").read_bytes()[:8192]
                except FileNotFoundError:
                    continue
                except OSError:
                    return False
                m = re.search(rb"^Uid:\s*(\d+)\s", status, re.M)
                if m is None or int(m.group(1)) != uid:
                    continue
                n = re.search(rb"^Name:\s*(\S+)", status, re.M)
                if not n or n.group(1) != b"mega-cmd-server":
                    continue
                try:
                    target = Path(os.readlink(Path(entry.path) / "exe"))
                except OSError:
                    return False
                if target != executable:
                    return False
        return True
    except OSError:
        return False

def tty_start_confirmation():
    try:
        fd = os.open("/dev/tty", os.O_RDWR | os.O_NOCTTY)
        with contextlib.ExitStack() as stack:
            stack.callback(os.close, fd)
            if not os.isatty(fd):
                return False
            def wrap(mode):
                child = os.dup(fd)
                try:
                    f = os.fdopen(child, mode, encoding="utf-8", buffering=1)
                except (OSError, ValueError):
                    os.close(child)
                    raise
                return stack.enter_context(f)
            inp, out = wrap("r"), wrap("w")
            out.write(
                "Only the disposable server may start if absent. Its cached "
                "Sync state could resume. No creation or deletion.\n"
                "Type START_DISPOSABLE_LS_ONLY: "
            )
            out.flush()
            return inp.readline(64).strip() == "START_DISPOSABLE_LS_ONLY"
    except (OSError, UnicodeError, ValueError):
        return False

def main():
    started = False
    try:
        uid = os.getuid()
        user = pwd.getpwuid(uid)
        home = Path(user.pw_dir)
        runtime = Path(os.environ.get("XDG_RUNTIME_DIR", ""))
        if (uid == 0 or uid != os.geteuid()
                or user.pw_name != F["USER"]
                or not B["private_dir"](home, uid)
                or runtime != Path("/run/user") / str(uid)
                or not B["private_dir"](runtime, uid)):
            emit("dedicated_environment_rejected"); return 21
        lock = home / (F["JOURNAL"] + ".lock")
        fd = os.open(lock, os.O_RDONLY | os.O_NOFOLLOW)
        with os.fdopen(fd, "rb") as held:
            s = os.fstat(held.fileno())
            if not stat.S_ISREG(s.st_mode) or s.st_uid != uid or s.st_mode & 0o177:
                emit("journal_untrusted"); return 21
            try:
                fcntl.flock(held.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                emit("another_fixture_active"); return 21
            journal_path = home / F["JOURNAL"]
            if journal_path.is_symlink():
                emit("journal_untrusted"); return 21
            journal = F["load_journal"](journal_path, home, uid)
            if journal is None:
                emit("journal_untrusted"); return 21
            if journal["stage"] != "sync_detached":
                emit("journal_stage_unexpected"); return 21
            allowed = B["BOUNDARY"]["allowed_binary"]
            p = [allowed(n) for n in
                 ("mega-version", "mega-cmd-server", "mega-exec")]
            if (not all(p) or not all(map(B["trusted_program"], p))
                    or not B["PRIVATE"]["verify_private_lib_mount"](p[:2])
                    or not B["CAT"]["package_executor_owned"](p[:2], p[2])):
                emit("trusted_package_rejected"); return 21
            executor, server = p[2][0], p[1][1]
            servers = B["existing_server"]
            if not named_server_guard(uid, server) or len(servers(server, uid)) > 1:
                emit("server_identity_ambiguous"); return 21
            initial = servers(server, uid)
            if not tty_start_confirmation():
                emit("start_confirmation_rejected"); return 20
            if not named_server_guard(uid, server) or servers(server, uid) != initial:
                emit("server_changed"); return 21
            env = {"HOME": str(home), "USER": F["USER"], "LOGNAME": F["USER"],
                   "XDG_RUNTIME_DIR": str(runtime),
                   "PATH": str(executor.parent) + ":/usr/bin:/bin",
                   "LANG": "C.UTF-8", "LC_ALL": "C.UTF-8"}
            if not initial:
                started = True
                subprocess.Popen([str(p[1][0])], stdin=subprocess.DEVNULL,
                                 stdout=subprocess.DEVNULL,
                                 stderr=subprocess.DEVNULL, env=env,
                                 close_fds=True, start_new_session=True)
                deadline = time.monotonic() + 15
                prior = []
                ready = False
                while time.monotonic() < deadline:
                    if not named_server_guard(uid, server):
                        break
                    now = servers(server, uid)
                    if len(now) == 1 and now == prior:
                        ready = True
                        break
                    if len(now) > 1:
                        break
                    prior = now
                    time.sleep(0.5)
                if not ready:
                    emit("server_start_unconfirmed", started=started); return 21
            pinned = servers(server, uid)
            if len(pinned) != 1 or not named_server_guard(uid, server):
                emit("server_identity_ambiguous", started=started); return 21
            expected = I["confirmation"]()
            if expected is None:
                emit("operator_confirmation_unavailable", started=started); return 20
            def runner(argv):
                assert argv[0] in {"whoami", "sync", "ls"}
                if argv[0] == "sync":
                    assert tuple(argv) == F["TWO"]
                if argv[0] == "ls":
                    assert tuple(argv) in {
                        ("ls", "/"), ("ls", "-l", journal["remote"])}
                return B["bounded_read"]([str(executor), *argv], env)
            def identity():
                return (named_server_guard(uid, server) and
                        F["verify_identity"](runner, expected, pinned, server, uid))
            if not identity():
                emit("account_identity_unverified", started=started); return 21
            reason, classified = observe(runner, identity, journal, uid)
            kind, count = classified if classified else ("unknown", "unknown")
            emit(reason, kind, count, started)
            return 0 if reason in {"listing_observed_unqualified",
                                   "listing_header_only_unqualified"} else 21
    except (OSError, ValueError, TypeError, KeyError, UnicodeError,
            RuntimeError, AssertionError):
        emit("supervisor_unavailable", started=started); return 21

def selftest():
    assert classify(b"FLAGS VERS SIZE DATE NAME\n") == ("none_observed", "zero")
    assert classify(b"FLAGS VERS SIZE DATE NAME\n"
                    b"d--- - - 2026-10-02 12:00 SAMPLE\n") == ("folders_only", "one")
    assert classify(b"FLAGS VERS SIZE DATE NAME\n"
                    b"---- 1 24 2026-10-02 12:00 FILE\n") == ("files_only", "one")
    assert classify(b"FLAGS VERS SIZE DATE NAME\nNAME_ONLY\n") is None
    print("PASS MegaQML private ls classifier pure selftest")

if __name__ == "__main__":
    if sys.argv[1:] == ["--self-test"]:
        selftest()
    elif sys.argv[1:] == ["--approved-one-server-start-and-ls"]:
        sys.exit(main())
    else:
        emit("start_confirmation_rejected")
        sys.exit(20)
