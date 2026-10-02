#!/usr/bin/env python3
"""Owner-local ONE fixture on an already authenticated throwaway MEGAcmd user.

No primary account, login, background server startup or broad cleanup.
Vendor bytes, account email, paths and IDs never appear in output or logs.
An interrupted run keeps a private journal for a separate cleanup-only run.
"""
import contextlib
import fcntl
import getpass
import json
import os
from pathlib import Path
import pwd
import re
import runpy
import secrets
import stat
import sys
import termios
import time
import warnings

HERE = Path(__file__).resolve().parent
BASE = runpy.run_path(str(HERE / "megaqml-phase3b-disposable-readonly-sync.py"),
                      run_name="disposable_fixture_import")
USER = BASE["EXPECTED_USER"]
OPAQUE = BASE["OPAQUE_ID"]
RUN_STATES = BASE["RUN_STATES"]
STATUSES = BASE["STATUSES"]
JOURNAL = ".megaqml-phase3b-fixture-private.json"
LOCAL_PREFIX = ".megaqml-phase3b-fixture-"
REMOTE_PREFIX = "/MEGAQML-Phase3b-Fixture-"
FIVE = ("sync", "--output-cols=ID,LOCALPATH,REMOTEPATH,RUN_STATE,STATUS",
        "--col-separator=|")
THREE = ("sync", "--output-cols=ID,RUN_STATE,STATUS", "--col-separator=|")
TWO = ("sync", "--output-cols=ID,LOCALPATH", "--col-separator=|")
BLANK = b"\n"
MAX_SNAPSHOT = 16 * 1024
HEX = re.compile(r"[0-9a-f]{32}\Z")

def result(reason, **flags):
    allowed = {
        "explicit_fixture_ack_required", "dedicated_user_required",
        "preflight_unavailable", "private_terminal_required",
        "email_format_rejected", "whoami_not_matched",
        "preexisting_sync_or_unknown_baseline", "root_not_proven_empty",
        "existing_private_journal", "journal_not_trusted",
        "another_fixture_active",
        "local_create_failed", "remote_create_unconfirmed",
        "sync_create_unconfirmed", "nonempty_row_unqualified",
        "row_stability_unqualified", "cleanup_incomplete",
        "fixture_observed_and_cleaned",
        "cleanup_only_complete", "supervisor_error", "selftest_pass"
    }
    assert reason in allowed
    defaults = dict(
        SERVER_MATCH=False, ACCOUNT_MATCH=False, EMPTY_BASELINE=False,
        FIXTURE_ATTEMPTED=False, NONEMPTY_ROW=False,
        SAME_ID_REOBSERVED=False, SYNC_DETACHED=False,
        REMOTE_REMOVED=False, LOCAL_REMOVED=False,
        PRIVATE_RECOVERY_PENDING=False)
    defaults.update(flags)
    print("MEGAQML_DISPOSABLE_FIXTURE_RESULT")
    print("REASON=" + reason)
    for k, v in defaults.items():
        assert type(v) is bool
        print(k + "=" + str(v).lower())
    print("RAW_PRIVATE_OUTPUT_PUBLISHED=NO")
    print("VENDOR_SCOPE=ONE_THROWAWAY_FIXTURE_ONLY")
    print("PHASE3B=UNQUALIFIED")

def parse_rows(data, columns, *, max_rows=1):
    """Exact one-table candidate; no cross-response row-index join."""
    header = b"|".join(columns) + b"\n"
    if len(data) > MAX_SNAPSHOT or not data.startswith(header):
        return None
    try:
        lines = data.decode("ascii").splitlines(keepends=True)
    except UnicodeError:
        return None
    if not lines or lines[0].encode("ascii") != header:
        return None
    lines = lines[1:]
    if len(lines) != max_rows or any(not x.endswith("\n") for x in lines):
        return None
    records = []
    for line in lines:
        if line.endswith("\r\n"):
            return None
        parts = line[:-1].split("|")
        if len(parts) != len(columns) or any(not f or any(ord(c) < 32 for c in f)
                                             for f in parts):
            return None
        row = dict(zip((c.decode() for c in columns), parts))
        if not OPAQUE.fullmatch(row["ID"].encode("ascii")):
            return None
        if ("RUN_STATE" in row and
                row["RUN_STATE"].encode("ascii") not in RUN_STATES):
            return None
        if ("STATUS" in row and row["STATUS"].encode("ascii") not in STATUSES):
            return None
        records.append(row)
    return records

def safe_name(record, home):
    try:
        name = record["nonce"]
        if not isinstance(name, str) or not HEX.fullmatch(name):
            return False
        local = str(home / (LOCAL_PREFIX + name))
        remote = REMOTE_PREFIX + name
        return (record["local"] == local and record["remote"] == remote
                and record["stage"] in {
                    "prepared", "remote_attempted", "remote_created",
                    "sync_attempted", "sync_created", "observed",
                    "sync_detached", "remote_removed"
                } and set(record) == {"nonce", "local", "remote", "stage"})
    except (KeyError, TypeError, ValueError):
        return False

def save_journal(path, data):
    # Atomic replacement never follows an existing symlink.
    raw = json.dumps(data, sort_keys=True, separators=(",", ":")).encode()
    tmp = path.parent / (JOURNAL + ".new")
    # A killed prior attempt can leave .new; recover only our own
    # regular 0600 file inside the verified private HOME.
    if tmp.exists() or tmp.is_symlink():
        st = tmp.lstat()
        if (not stat.S_ISREG(st.st_mode) or st.st_uid != os.getuid()
                or st.st_mode & 0o177):
            raise OSError("untrusted-journal-temp")
        tmp.unlink()
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    try:
        with os.fdopen(fd, "wb") as f:
            f.write(raw)
            f.flush()
            os.fsync(f.fileno())
        # tmp was created with exclusive mode 0600 in a private HOME;
        # replacing the journal preserves this mode atomically.
        os.replace(tmp, path)
    finally:
        if tmp.exists():
            tmp.unlink()

def load_journal(path, home, uid):
    st = path.lstat()
    if not stat.S_ISREG(st.st_mode) or st.st_uid != uid or st.st_mode & 0o177:
        return None
    raw = path.read_bytes()
    if len(raw) > 1024:
        return None
    d = json.loads(raw)
    return d if safe_name(d, home) else None

def private_confirmation(cleanup_only):
    phrase = ("CLEAN_DISPOSABLE_FIXTURE" if cleanup_only
              else "CREATE_DISPOSABLE_FIXTURE")
    fd = os.open("/dev/tty", os.O_RDWR | os.O_NOCTTY)
    with contextlib.ExitStack() as stack:
        stack.callback(os.close, fd)
        if not os.isatty(fd):
            return None
        termios.tcgetattr(fd)
        def text_stream(mode):
            child = os.dup(fd)
            try:
                f = os.fdopen(child, mode, encoding="utf-8", buffering=1)
            except (ValueError, UnicodeError, OSError):
                os.close(child)
                raise
            return stack.enter_context(f)
        ins, outs = text_stream("r"), text_stream("w")
        outs.write(
            "ONLY the pre-authenticated EMPTY throwaway MEGA account in "
            "dedicated megaqml-disposable Unix session.\n"
            "One unique empty LOCAL/REMOTE Sync fixture; "
            "remove Sync and empty test folders when safely proven.\n"
            "NO primary account. No files uploaded. "
            "In uncertainty leave a private recovery journal.\n"
            "Type " + phrase + ": "
        )
        outs.flush()
        if ins.readline(64).strip() != phrase:
            return None
        with warnings.catch_warnings():
            warnings.simplefilter("error", getpass.GetPassWarning)
            email = getpass.getpass("Throwaway MEGA email (not logged): ",
                                    stream=outs)
        if BASE["classify_disposable_email"](email) is not None:
            return None
        return email.encode("ascii")

def strict_read(runner, *argv):
    rc, out, err, error = runner(tuple(argv))
    if error is not None or rc != 0 or err or len(out) > MAX_SNAPSHOT:
        return None
    return out

def verify_whoami(runner, expected):
    out = strict_read(runner, "whoami")
    return (out is not None and
            set(BASE["IDENTITY"].findall(out)) == {expected})

def verify_identity(runner, expected, server, executable, uid):
    return (BASE["existing_server"](executable, uid) == server
            and verify_whoami(runner, expected)
            and BASE["existing_server"](executable, uid) == server)

def evaluate(full_before, short, full_after, local, remote):
    five_cols = (b"ID", b"LOCALPATH", b"REMOTEPATH", b"RUN_STATE", b"STATUS")
    three_cols = (b"ID", b"RUN_STATE", b"STATUS")
    a = parse_rows(full_before, five_cols)
    b = parse_rows(short, three_cols)
    c = parse_rows(full_after, five_cols)
    if not a or not b or not c:
        return False
    return (a[0]["ID"] == b[0]["ID"] == c[0]["ID"]
            and all(row["LOCALPATH"] == local and
                    row["REMOTEPATH"] == remote for row in (a[0], c[0])))

def cleanup(runner, check_identity, journal, path, home):
    """Fail closed on any ambiguous account, row, path or remote contents."""
    flags = dict(SYNC_DETACHED=False, REMOTE_REMOVED=False,
                 LOCAL_REMOVED=False)
    local, remote = journal["local"], journal["remote"]
    stage = journal["stage"]
    if stage not in {"prepared", "remote_attempted", "remote_created"}:
        if not check_identity():
            return flags
        before = strict_read(runner, *TWO)
        if before != BLANK:
            rows = parse_rows(before or b"", (b"ID", b"LOCALPATH"))
            if not rows or rows[0]["LOCALPATH"] != local:
                return flags
            if not check_identity():
                return flags
            # Vendor deletes the sync configuration, NOT remote/local files.
            if strict_read(runner, "sync", "--delete", local) is None:
                return flags
            if not check_identity() or strict_read(runner, *TWO) != BLANK:
                return flags
        journal["stage"] = "sync_detached"
        save_journal(path, journal)
    elif stage != "prepared":
        # Even a partially succeeded create may have registered the sync.
        if not check_identity():
            return flags
        before = strict_read(runner, *TWO)
        if before != BLANK:
            rows = parse_rows(before or b"", (b"ID", b"LOCALPATH"))
            if not rows or rows[0]["LOCALPATH"] != local:
                return flags
            if not check_identity() or strict_read(
                    runner, "sync", "--delete", local) is None:
                return flags
            if not check_identity() or strict_read(runner, *TWO) != BLANK:
                return flags
        journal["stage"] = "sync_detached"
        save_journal(path, journal)
    else:
        journal["stage"] = "sync_detached"
        save_journal(path, journal)
    flags["SYNC_DETACHED"] = True

    # Only exact regenerated unique path, ONLY clean ls contents, ONLY
    # after no Sync remains. rm -r -f is otherwise forbidden.
    if stage not in ("prepared", "remote_removed"):
        if not check_identity():
            return flags
        listing = strict_read(runner, "ls", remote)
        if listing not in (b"", BLANK):
            return flags
        if (not check_identity()
                or strict_read(runner, *TWO) != BLANK
                or not check_identity()):
            return flags
        if strict_read(runner, "rm", "-r", "-f", remote) is None:
            return flags
        # Recheck the entire account root which was proven empty before
        # provisioning; never accept an arbitrary root listing as cleanup.
        if not check_identity() or strict_read(runner, "ls", "/") not in (b"", BLANK):
            return flags
    journal["stage"] = "remote_removed"
    save_journal(path, journal)
    flags["REMOTE_REMOVED"] = True
    folder = Path(local)
    try:
        if folder.is_symlink():
            return flags
        st = folder.lstat()
        if not stat.S_ISDIR(st.st_mode) or st.st_uid != os.getuid():
            return flags
        folder.rmdir()  # strictly empty: cannot erase user data.
    except FileNotFoundError:
        # PREPARED might predate local mkdir; REMOTE_REMOVED might have
        # already rmdir'ed local just before the last journal unlink.
        if stage not in ("prepared", "remote_removed"):
            return flags
    except OSError:
        return flags
    flags["LOCAL_REMOVED"] = True
    path.unlink()
    return flags

def real_main(cleanup_only=False):
    if os.geteuid() == 0 or os.geteuid() != os.getuid():
        result("dedicated_user_required")
        return 20
    try:
        user = pwd.getpwuid(os.geteuid())
        home = Path(user.pw_dir)
        uid = user.pw_uid
        runtime = Path(os.environ.get("XDG_RUNTIME_DIR", ""))
        if (user.pw_name != USER or home in (Path("/"), Path("/home"))
                or not re.fullmatch(r"/[A-Za-z0-9_/-]+", str(home))
                or not BASE["private_dir"](home, uid)
                or runtime != Path("/run/user") / str(uid)
                or not BASE["private_dir"](runtime, uid)):
            result("dedicated_user_required")
            return 20
        boundary = BASE["BOUNDARY"]
        allowed = boundary["allowed_binary"]
        pairs = [allowed(n) for n in ("mega-version", "mega-cmd-server",
                                       "mega-exec")]
        if (not all(pairs) or
                not all(map(BASE["trusted_program"], pairs)) or
                not BASE["PRIVATE"]["verify_private_lib_mount"](pairs[:2]) or
                not BASE["CAT"]["package_executor_owned"](pairs[:2], pairs[2])):
            result("preflight_unavailable")
            return 20
        executor, server_bin = pairs[2][0], pairs[1][1]
        servers = BASE["existing_server"](server_bin, uid)
        if len(servers) != 1:
            result("preflight_unavailable")
            return 20
        jpath = home / JOURNAL
        if jpath.is_symlink():
            result("journal_not_trusted")
            return 20
        if jpath.exists() and not cleanup_only:
            result("existing_private_journal", SERVER_MATCH=True,
                   PRIVATE_RECOVERY_PENDING=True)
            return 20
        if not jpath.exists() and cleanup_only:
            result("journal_not_trusted", SERVER_MATCH=True)
            return 20
        if cleanup_only:
            journal = load_journal(jpath, home, uid)
            if journal is None:
                result("journal_not_trusted", SERVER_MATCH=True)
                return 20
        try:
            expected = private_confirmation(cleanup_only)
        except (OSError, UnicodeError, EOFError, ValueError,
                getpass.GetPassWarning):
            expected = None
        if expected is None:
            result("private_terminal_required", SERVER_MATCH=True,
                   PRIVATE_RECOVERY_PENDING=jpath.exists())
            return 20
        env = {
            "HOME": str(home), "USER": USER, "LOGNAME": USER,
            "XDG_RUNTIME_DIR": str(runtime),
            "PATH": str(executor.parent) + ":/usr/bin:/bin",
            "LANG": "C.UTF-8", "LC_ALL": "C.UTF-8",
        }
        def runner(argv):
            return BASE["bounded_read"]([str(executor), *argv], env)
        def identity():
            return verify_identity(runner, expected, servers, server_bin, uid)
        if not identity():
            result("whoami_not_matched", SERVER_MATCH=True,
                   PRIVATE_RECOVERY_PENDING=jpath.exists())
            return 21
        if cleanup_only:
            flags = cleanup(runner, identity, journal, jpath, home)
            finished = all(flags.values())
            result("cleanup_only_complete" if finished else "cleanup_incomplete",
                   SERVER_MATCH=True, ACCOUNT_MATCH=True,
                   PRIVATE_RECOVERY_PENDING=not finished, **flags)
            return 0 if finished else 21
        # Baseline enforces no pre-existing MEGAcmd Sync AND an empty
        # root listing before we add any cloud state, regardless of the
        # operator's declaration that the separate account is empty.
        if strict_read(runner, *FIVE) != BLANK:
            result("preexisting_sync_or_unknown_baseline",
                   SERVER_MATCH=True, ACCOUNT_MATCH=True)
            return 21
        if strict_read(runner, "ls", "/") not in (b"", BLANK):
            result("root_not_proven_empty",
                   SERVER_MATCH=True, ACCOUNT_MATCH=True)
            return 21
        if not identity():
            result("whoami_not_matched", SERVER_MATCH=True,
                   ACCOUNT_MATCH=False)
            return 21
        nonce = secrets.token_hex(16)
        journal = {"nonce": nonce, "stage": "prepared",
                   "local": str(home / (LOCAL_PREFIX + nonce)),
                   "remote": REMOTE_PREFIX + nonce}
        if not safe_name(journal, home):
            result("supervisor_error", SERVER_MATCH=True, ACCOUNT_MATCH=True)
            return 21
        try:
            # Journal first: even SIGINT between mkdir and the first
            # vendor call leaves an exact private recovery target.
            save_journal(jpath, journal)
            os.mkdir(journal["local"], 0o700)
        except OSError:
            result("local_create_failed", SERVER_MATCH=True, ACCOUNT_MATCH=True,
                   PRIVATE_RECOVERY_PENDING=jpath.exists())
            return 21
        why = "sync_create_unconfirmed"
        flags = {"SERVER_MATCH": True, "ACCOUNT_MATCH": True,
                 "EMPTY_BASELINE": True, "FIXTURE_ATTEMPTED": False,
                 "NONEMPTY_ROW": False, "SAME_ID_REOBSERVED": False}
        try:
            if not identity():
                why = "whoami_not_matched"
            else:
                journal["stage"] = "remote_attempted"
                save_journal(jpath, journal)
                if strict_read(runner, "mkdir", journal["remote"]) is None:
                    why = "remote_create_unconfirmed"
                else:
                    journal["stage"] = "remote_created"
                    save_journal(jpath, journal)
                    if not identity() or strict_read(
                            runner, "ls", journal["remote"]) not in (b"", BLANK):
                        why = "remote_create_unconfirmed"
                    else:
                        journal["stage"] = "sync_attempted"
                        save_journal(jpath, journal)
                        flags["FIXTURE_ATTEMPTED"] = True
                        if not identity() or strict_read(
                                runner, "sync", journal["local"],
                                journal["remote"]) is None:
                            why = "sync_create_unconfirmed"
                        else:
                            journal["stage"] = "sync_created"
                            save_journal(jpath, journal)
                            why = "nonempty_row_unqualified"
                            for _ in range(4):
                                if not identity():
                                    break
                                full_a = strict_read(runner, *FIVE)
                                if full_a is not None and parse_rows(
                                    full_a,
                                    (b"ID", b"LOCALPATH", b"REMOTEPATH",
                                     b"RUN_STATE", b"STATUS")):
                                    flags["NONEMPTY_ROW"] = True
                                    compact = strict_read(runner, *THREE)
                                    full_b = strict_read(runner, *FIVE)
                                    if None not in (compact, full_b) and evaluate(
                                            full_a, compact, full_b,
                                            journal["local"], journal["remote"]):
                                        flags["SAME_ID_REOBSERVED"] = True
                                        journal["stage"] = "observed"
                                        save_journal(jpath, journal)
                                        why = "fixture_observed_and_cleaned"
                                        break
                                time.sleep(1)
                            if why == "nonempty_row_unqualified" and flags["NONEMPTY_ROW"]:
                                why = "row_stability_unqualified"
        finally:
            cleanup_flags = cleanup(runner, identity, journal, jpath, home)
        flags.update(cleanup_flags)
        finished = all(cleanup_flags.values())
        if not finished:
            why = "cleanup_incomplete"
        result(why, **flags, PRIVATE_RECOVERY_PENDING=not finished)
        return 0 if why == "fixture_observed_and_cleaned" else 21
    except (OSError, RuntimeError, ValueError, UnicodeError, KeyError,
            TypeError, KeyboardInterrupt, json.JSONDecodeError):
        # Exception text/paths are private and deliberately not logged.
        pending = ("jpath" in locals() and isinstance(jpath, Path)
                   and jpath.exists())
        result("supervisor_error", PRIVATE_RECOVERY_PENDING=pending)
        return 21

def locked_main(cleanup_only=False):
    # An opt-in second terminal cannot race mutation/cleanup in same UID.
    # The owner-private lock contains no credentials, paths or vendor output.
    try:
        if os.geteuid() == 0 or os.geteuid() != os.getuid():
            result("dedicated_user_required")
            return 20
        user = pwd.getpwuid(os.geteuid())
        home = Path(user.pw_dir)
        if (user.pw_name != USER or not BASE["private_dir"](home, user.pw_uid)
                or not re.fullmatch(r"/[A-Za-z0-9_/-]+", str(home))):
            result("dedicated_user_required")
            return 20
        lockpath = home / (JOURNAL + ".lock")
        fd = os.open(lockpath, os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW, 0o600)
        try:
            st = os.fstat(fd)
            if (not stat.S_ISREG(st.st_mode) or st.st_uid != user.pw_uid
                    or st.st_mode & 0o177):
                result("journal_not_trusted")
                return 20
            try:
                fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                result("another_fixture_active")
                return 20
            return real_main(cleanup_only)
        finally:
            os.close(fd)
    except (OSError, KeyError, ValueError):
        result("preflight_unavailable")
        return 21

def self_test():
    assert parse_rows(b"ID|LOCALPATH\nABCdef12|-path-\n",
                      (b"ID", b"LOCALPATH")) == [
                          {"ID": "ABCdef12", "LOCALPATH": "-path-"}]
    assert parse_rows(b"\n", (b"ID", b"LOCALPATH")) is None
    assert parse_rows(b"ID|LOCALPATH\nABCdef12|/a\nABCdef12|/b\n",
                      (b"ID", b"LOCALPATH")) is None
    sample = {"nonce": "a" * 32, "stage": "prepared",
              "local": "/home/test/" + LOCAL_PREFIX + "a" * 32,
              "remote": REMOTE_PREFIX + "a" * 32}
    assert safe_name(sample, Path("/home/test"))
    sample["remote"] = "/other-folder"
    assert not safe_name(sample, Path("/home/test"))
    print("PASS MegaQML disposable one-fixture pure self-test")

if __name__ == "__main__":
    if sys.argv[1:] == ["--self-test"]:
        self_test()
    elif sys.argv[1:] == ["--execute-fixture"]:
        sys.exit(locked_main(False))
    elif sys.argv[1:] == ["--cleanup-only"]:
        sys.exit(locked_main(True))
    else:
        result("explicit_fixture_ack_required")
        sys.exit(20)
