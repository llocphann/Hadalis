#!/usr/bin/env python3
"""Owner-local, read-only recovery inspection for ONE unfinished fixture.

No mkdir, sync creation/deletion, remote rm, local rmdir, journal changes,
raw vendor output, email, path or Sync ID publication. Never use on a
main account. All observations are finite labels, private in memory.
"""
import contextlib
import fcntl
import getpass
import os
from pathlib import Path
import pwd
import re
import runpy
import stat
import sys
import termios
import warnings

HERE = Path(__file__).resolve().parent
F = runpy.run_path(str(HERE / "megaqml-phase3b-disposable-single-fixture.py"),
                   run_name="private_fixture_inspection_import")
B = F["BASE"]

REASONS = {
    "explicit_diagnostic_ack_required", "dedicated_user_required",
    "preflight_unavailable", "journal_untrusted", "another_fixture_active",
    "terminal_confirmation_unavailable", "account_identity_unverified",
    "inspection_complete", "inspection_unavailable", "selftest_pass"
}
STAGES = {"prepared", "remote_attempted", "remote_created", "sync_attempted",
          "sync_created", "observed", "sync_detached", "remote_removed"}
SYNC_CATS = {"unknown", "blank", "one_owned", "other"}
LIST_CATS = {"unknown", "blank", "only_fixture", "other"}
REMOTE_CATS = {"unknown", "empty", "nonempty"}
LOCAL_CATS = {"unknown", "absent", "empty_owned", "nonempty_owned", "other"}
PLANS = {"no_action", "remote_cleanup_candidate", "remote_absence_candidate"}

def result(reason, stage="unknown", sync="unknown", root="unknown",
           remote="unknown", local="unknown", plan="no_action",
           server=False, identity=False):
    assert reason in REASONS
    assert stage == "unknown" or stage in STAGES
    assert sync in SYNC_CATS and root in LIST_CATS
    assert remote in REMOTE_CATS and local in LOCAL_CATS and plan in PLANS
    for item in (reason, stage, sync, root, remote, local, plan):
        assert re.fullmatch(r"[a-z_]+", item)
    print("MEGAQML_FIXTURE_RECOVERY_INSPECTION")
    print("REASON=" + reason)
    print("SERVER_MATCH=" + str(server).lower())
    print("ACCOUNT_MATCH=" + str(identity).lower())
    print("PRIVATE_JOURNAL_STAGE=" + stage)
    print("SYNC_STATUS=" + sync)
    print("ROOT_STATUS=" + root)
    print("REMOTE_STATUS=" + remote)
    print("LOCAL_STATUS=" + local)
    print("RECOVERY_PLAN=" + plan)
    print("VENDOR_ACTIONS=READ_ONLY")
    print("PRIVATE_JOURNAL_CHANGED=NO")
    print("RAW_PRIVATE_OUTPUT_PUBLISHED=NO")
    print("PHASE3B=UNQUALIFIED")

def local_class(path, uid):
    try:
        st = path.lstat()  # do not follow a symlink
        if (not stat.S_ISDIR(st.st_mode) or st.st_uid != uid
                or st.st_mode & 0o077):
            return "other"
        return "nonempty_owned" if any(path.iterdir()) else "empty_owned"
    except FileNotFoundError:
        return "absent"
    except (OSError, ValueError):
        return "unknown"

def categorize(sync_bytes, root_bytes, remote_bytes, journal, uid):
    """Untrusted vendor outputs may affect only finite diagnostic labels."""
    local = journal["local"].encode("ascii")
    only_remote_name = journal["remote"][1:].encode("ascii") + b"\n"
    sync = "unknown"
    if sync_bytes is not None:
        if sync_bytes == b"\n":
            sync = "blank"
        else:
            rows = F["parse_rows"](sync_bytes, (b"ID", b"LOCALPATH"))
            sync = ("one_owned" if rows and rows[0]["LOCALPATH"].encode("ascii")
                    == local else "other")
    root = ("unknown" if root_bytes is None else
            "blank" if root_bytes in (b"", b"\n") else
            "only_fixture" if root_bytes == only_remote_name else "other")
    remote = ("unknown" if remote_bytes is None else
              "empty" if remote_bytes in (b"", b"\n") else "nonempty")
    local_status = local_class(Path(journal["local"]), uid)
    plan = "no_action"
    # Candidates are explanatory labels, NOT deletion authorization.
    if (journal["stage"] == "sync_detached" and sync == "blank"
            and local_status in {"absent", "empty_owned"}):
        if root == "only_fixture" and remote == "empty":
            plan = "remote_cleanup_candidate"
        elif root == "blank" and remote == "unknown":
            plan = "remote_absence_candidate"
    return sync, root, remote, local_status, plan

def confirmation():
    fd = os.open("/dev/tty", os.O_RDWR | os.O_NOCTTY)
    with contextlib.ExitStack() as stack:
        stack.callback(os.close, fd)
        if not os.isatty(fd):
            return None
        termios.tcgetattr(fd)

        def wrap(mode):
            child = os.dup(fd)
            try:
                stream = os.fdopen(child, mode, encoding="utf-8", buffering=1)
            except (OSError, ValueError, UnicodeError):
                os.close(child)
                raise
            return stack.enter_context(stream)

        inp, out = wrap("r"), wrap("w")
        out.write(
            "READ-ONLY inspection of the PREVIOUS unfinished disposable "
            "fixture, no writes or cleanup.\n"
            "Use ONLY the already authenticated MEGA throwaway account.\n"
            "Type DIAGNOSE_DISPOSABLE_FIXTURE: "
        )
        out.flush()
        if inp.readline(64).strip() != "DIAGNOSE_DISPOSABLE_FIXTURE":
            return None
        with warnings.catch_warnings():
            warnings.simplefilter("error", getpass.GetPassWarning)
            email = getpass.getpass("Throwaway MEGA email (not logged): ",
                                    stream=out)
        if B["classify_disposable_email"](email) is not None:
            return None
        return email.encode("ascii")

def inspect(runner, account_check, journal, uid):
    """Injected runner supports ONLY whoami, sync columns and ls paths."""
    def read(*cmd):
        return F["strict_read"](runner, *cmd)
    # Recheck the same session before EVERY vendor observation.
    if not account_check():
        return None
    sy = read(*F["TWO"])
    if not account_check():
        return None
    rt = read("ls", "/")
    if not account_check():
        return None
    rem = read("ls", journal["remote"])
    if not account_check():
        return None
    return categorize(sy, rt, rem, journal, uid)

def main():
    if os.geteuid() == 0 or os.geteuid() != os.getuid():
        result("dedicated_user_required")
        return 20
    try:
        user = pwd.getpwuid(os.geteuid())
        uid = user.pw_uid
        home = Path(user.pw_dir)
        runtime = Path(os.environ.get("XDG_RUNTIME_DIR", ""))
        if (user.pw_name != F["USER"] or
                not re.fullmatch(r"/[A-Za-z0-9_/-]+", str(home)) or
                not B["private_dir"](home, uid) or
                runtime != Path("/run/user") / str(uid) or
                not B["private_dir"](runtime, uid)):
            result("dedicated_user_required")
            return 20
        lock = home / (F["JOURNAL"] + ".lock")
        # A prior fixture should already have created its lock; read-only
        # inspection does not create/mutate this file or its journal.
        lock_fd = os.open(lock, os.O_RDONLY | os.O_NOFOLLOW)
        with contextlib.closing(os.fdopen(lock_fd, "rb")) as held:
            st = os.fstat(held.fileno())
            if (not stat.S_ISREG(st.st_mode) or st.st_uid != uid or
                    st.st_mode & 0o177):
                result("journal_untrusted")
                return 21
            try:
                fcntl.flock(held.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                result("another_fixture_active")
                return 21
            journal_path = home / F["JOURNAL"]
            if journal_path.is_symlink():
                result("journal_untrusted")
                return 21
            journal = F["load_journal"](journal_path, home, uid)
            if journal is None:
                result("journal_untrusted")
                return 21
            stage = journal["stage"]
            allowed = B["BOUNDARY"]["allowed_binary"]
            pair = [allowed(name) for name in
                    ("mega-version", "mega-cmd-server", "mega-exec")]
            if (not all(pair) or
                    not all(map(B["trusted_program"], pair)) or
                    not B["PRIVATE"]["verify_private_lib_mount"](pair[:2]) or
                    not B["CAT"]["package_executor_owned"](pair[:2],
                                                           pair[2])):
                result("preflight_unavailable", stage=stage)
                return 21
            executable, server = pair[2][0], pair[1][1]
            servers = B["existing_server"](server, uid)
            if len(servers) != 1:
                result("preflight_unavailable", stage=stage)
                return 21
            try:
                expected = confirmation()
            except (OSError, EOFError, ValueError, UnicodeError,
                    getpass.GetPassWarning):
                expected = None
            if expected is None:
                result("terminal_confirmation_unavailable",
                       stage=stage, server=True)
                return 20
            env = {
                "HOME": str(home), "USER": F["USER"], "LOGNAME": F["USER"],
                "XDG_RUNTIME_DIR": str(runtime),
                "PATH": str(executable.parent) + ":/usr/bin:/bin",
                "LANG": "C.UTF-8", "LC_ALL": "C.UTF-8",
            }
            def runner(argv):
                assert argv[0] in {"whoami", "sync", "ls"}
                if argv[0] == "sync":
                    assert tuple(argv) == F["TWO"]
                if argv[0] == "ls":
                    assert len(argv) == 2 and argv[1] in {
                        "/", journal["remote"]}
                return B["bounded_read"]([str(executable), *argv], env)
            def match():
                return F["verify_identity"](runner, expected, servers, server,
                                            uid)
            if not match():
                result("account_identity_unverified", stage=stage, server=True)
                return 21
            observations = inspect(runner, match, journal, uid)
            if observations is None:
                result("inspection_unavailable", stage=stage, server=True)
                return 21
            result("inspection_complete", stage=stage, sync=observations[0],
                   root=observations[1], remote=observations[2],
                   local=observations[3], plan=observations[4],
                   server=True, identity=True)
            return 0
    except (OSError, ValueError, TypeError, KeyError, UnicodeError,
            RuntimeError, AssertionError):
        result("inspection_unavailable")
        return 21

def self_test():
    assert "remote_cleanup_candidate" in PLANS
    assert "remote_absence_candidate" in PLANS
    assert B["classify_disposable_email"]("fixture@example.invalid") is None
    print("PASS MegaQML fixture recovery inspection pure self-test")

if __name__ == "__main__":
    if sys.argv[1:] == ["--self-test"]:
        self_test()
    elif sys.argv[1:] == ["--diagnose-only"]:
        sys.exit(main())
    else:
        result("explicit_diagnostic_ack_required")
        sys.exit(20)
