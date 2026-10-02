#!/usr/bin/env python3
"""OWNER-LOCAL ONLY. Read-only disposable MEGAcmd Sync *shape* observation.

No login/setup/mutations/real output display. Requires a pre-existing
dedicated Unix user, its own pre-running server and throwaway MEGA login.
Only boolean/finite diagnostics leave this process; stdout/stderr stay RAM.
"""
import contextlib
import getpass
import os
from pathlib import Path
import pwd
import re
import runpy
import selectors
import signal
import stat
import termios
import subprocess
import sys
import time
import warnings

HERE = Path(__file__).resolve().parent
CAT = runpy.run_path(str(HERE / "megaqml-phase3b-offline-help-catalog.py"),
                     run_name="disposable_read_import")
BOUNDARY = CAT["BOUNDARY"]
PRIVATE = CAT["PRIVATE"]

EXPECTED_USER = "megaqml-disposable"
MAX_STDOUT = 16 * 1024
MAX_STDERR = 4 * 1024
DEADLINE_SEC = 12
SERVER_NAME = "mega-cmd-server"
IDENTITY = re.compile(
    rb"(?<![A-Za-z0-9_.+-])([A-Za-z0-9_.%+-]{1,64}@[A-Za-z0-9.-]{1,190}\.[A-Za-z]{2,32})(?![A-Za-z0-9_.+-])"
)
OPAQUE_ID = re.compile(rb"[A-Za-z0-9_-]{8,16}\Z")
RUN_STATES = {b"Pending", b"Loading", b"Running", b"Suspended", b"Disabled"}
STATUSES = {b"NONE", b"Synced", b"Pending", b"Syncing", b"Processing"}

def summary(reason, *, server=False, identity=False, rows=False):
    # Fixed public vocabulary. Never append exception text or private bytes.
    allowed = {
        "explicit_acknowledgment_required", "dedicated_os_user_required",
        "untrusted_home_or_runtime", "missing_or_untrusted_vendor",
        "private_library_gate_failed", "executor_package_mismatch",
        "disposable_server_not_running", "ambiguous_private_server",
        "server_changed_during_probe", "tty_required",
        "operator_confirmation_mismatch", "disposable_email_format_invalid",
        "disposable_email_empty", "disposable_email_surrounding_whitespace",
        "disposable_email_non_ascii", "tty_confirmation_unavailable",
        "whoami_timeout",
        "whoami_output_capped", "whoami_failed_or_ambiguous",
        "account_identity_mismatch", "sync_timeout", "sync_output_capped",
        "sync_failed_or_diagnostic", "sync_header_or_row_invalid",
        "sync_header_only_not_qualified", "sync_no_snapshot_unqualified",
        "sync_source_blank_line_candidate_unqualified",
        "sync_unexpected_header_unqualified", "sync_shape_observed_unqualified",
        "supervisor_error", "selftest_pass",
    }
    assert reason in allowed
    return ("MEGAQML_DISPOSABLE_READ_RESULT\n"
            f"REASON={reason}\n"
            f"ISOLATED_SERVER_MATCH={'true' if server else 'false'}\n"
            f"DISPOSABLE_ACCOUNT_MATCH={'true' if identity else 'false'}\n"
            f"NONEMPTY_SYNC_SCALARS={'true' if rows else 'false'}\n"
            "VENDOR_PROBE_SCOPE=WHOAMI_THEN_SYNC_READ_ONLY\n"
            "RAW_PRIVATE_OUTPUT_PUBLISHED=NO\n"
            "PHASE3B=UNQUALIFIED")

def private_dir(path, uid, *, root=None):
    try:
        if not path.is_absolute() or path.is_symlink():
            return False
        st = path.lstat()
        if not stat.S_ISDIR(st.st_mode) or st.st_uid != uid:
            return False
        if st.st_mode & 0o077:
            return False
        if root is not None and path != root and not path.is_relative_to(root):
            return False
        return True
    except (OSError, ValueError):
        return False

def trusted_program(pair):
    try:
        if pair is None:
            return False
        raw, resolved = pair
        for p in (raw, resolved):
            if not p.is_absolute() or not p.is_file():
                return False
            st = p.stat()
            if st.st_uid != 0 or st.st_mode & 0o022 or not st.st_mode & 0o111:
                return False
        for p in (raw.parent, resolved.parent):
            st = p.stat()
            if st.st_uid != 0 or st.st_mode & 0o022:
                return False
        return True
    except (OSError, RuntimeError, ValueError):
        return False

def existing_server(exe, uid):
    # No auto-start and no inference based only on a socket filename.
    # An independently running server owned by this dedicated user
    # must already exist and resolve to the vetted package executable.
    found = []
    try:
        for entry in os.scandir("/proc"):
            if not entry.name.isdecimal():
                continue
            try:
                status = (Path(entry.path) / "status").read_bytes()[:8192]
                m = re.search(rb"^Uid:\s*(\d+)\s", status, re.M)
                if m is None or int(m.group(1)) != uid:
                    continue
                child = Path(os.readlink(Path(entry.path) / "exe"))
                if child == exe:
                    found.append(int(entry.name))
            except (PermissionError, ProcessLookupError, FileNotFoundError, OSError):
                continue
        return found
    except OSError:
        return []

def bounded_read(argv, env):
    """Two capped pipes; kill *only the client process group* on timeout.
    In particular do not kill or restart the pre-existing server.
    """
    proc = subprocess.Popen(
        argv, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
        stderr=subprocess.PIPE, env=env, close_fds=True,
        start_new_session=True,
    )
    sel = selectors.DefaultSelector()
    data = {proc.stdout.fileno(): bytearray(), proc.stderr.fileno(): bytearray()}
    caps = {proc.stdout.fileno(): MAX_STDOUT, proc.stderr.fileno(): MAX_STDERR}
    for f in (proc.stdout, proc.stderr):
        os.set_blocking(f.fileno(), False)
        sel.register(f, selectors.EVENT_READ)
    stop = time.monotonic() + DEADLINE_SEC
    error = None
    try:
        while sel.get_map() or proc.poll() is None:
            if time.monotonic() >= stop:
                error = "timeout"
                break
            for key, _ in sel.select(timeout=0.05):
                try:
                    part = os.read(key.fileobj.fileno(), 2048)
                except BlockingIOError:
                    continue
                if not part:
                    sel.unregister(key.fileobj)
                else:
                    fd = key.fileobj.fileno()
                    data[fd].extend(part)
                    if len(data[fd]) > caps[fd]:
                        error = "output_capped"
                        break
            if error:
                break
        if error is not None and proc.poll() is None:
            try:
                os.killpg(proc.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
        status = proc.wait(timeout=2)
        if error:
            return None, b"", b"", error
        return status, bytes(data[proc.stdout.fileno()]), bytes(data[proc.stderr.fileno()]), None
    finally:
        sel.close()
        for pipe in (proc.stdout, proc.stderr):
            pipe.close()
        if proc.poll() is None:
            try:
                os.killpg(proc.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            proc.wait(timeout=2)

def parse_snapshot(raw):
    # This is source-shaped syntax only: it never proves data provenance,
    # an empty account or release parity with an installed MEGAcmd binary.
    # Upstream MEGAcmd printSyncList() omits the header if syncList.size()==0;
    # ColumnDisplayer's selected-column branch then emits one blank newline.
    # This exact byte shape is a *candidate*, not an empty-state acceptance.
    if raw == b"\n":
        return "source_blank_line_candidate"
    if len(raw) > MAX_STDOUT or not raw.endswith(b"\n"):
        return "invalid"
    try:
        lines = raw.decode("ascii").encode("ascii").split(b"\n")
    except UnicodeError:
        return "invalid"
    lines.pop()  # exactly one terminal newline; empty extra rows still reject
    lines = [line[:-1] if line.endswith(b"\r") else line for line in lines]
    if not lines or lines.pop(0) != b"ID|RUN_STATE|STATUS":
        return "invalid"
    if not lines:
        return "header_only"
    if len(lines) > 1024:
        return "invalid"
    ids = set()
    for row in lines:
        if not row or b"\r" in row or any(b < 32 or b == 127 for b in row):
            return "invalid"
        fields = row.split(b"|")
        if len(fields) != 3:
            return "invalid"
        ident, state, status = fields
        if (not OPAQUE_ID.fullmatch(ident) or ident in ids
                or state not in RUN_STATES or status not in STATUSES):
            return "invalid"
        ids.add(ident)
    return "nonempty_shape"

def classify_disposable_email(value):
    # Fixed finite diagnostics only: never print input/length or normalize
    # into a *different* expected account identity.
    if not value:
        return "disposable_email_empty"
    if value != value.strip():
        return "disposable_email_surrounding_whitespace"
    if not value.isascii():
        return "disposable_email_non_ascii"
    if len(value) > 254 or not IDENTITY.fullmatch(value.encode("ascii")):
        return "disposable_email_format_invalid"
    return None

def tty_confirmation():
    # This is deliberately distinct from the previous failed r+ text open:
    # low-level O_NOCTTY already succeeded on the owner's dedicated local
    # session. Independent read/write wrappers avoid buffered random access
    # to an inherently non-seekable terminal.
    #
    # The identity is held in process memory only: never stdout, env or argv.
    try:
        with contextlib.ExitStack() as stack:
            fd = os.open("/dev/tty", os.O_RDWR | os.O_NOCTTY)
            stack.callback(os.close, fd)
            if not os.isatty(fd):
                return "tty_confirmation_unavailable", None
            termios.tcgetattr(fd)

            def wrap(mode):
                child = os.dup(fd)
                try:
                    stream = os.fdopen(child, mode, encoding="utf-8",
                                       buffering=1)
                except (OSError, ValueError, UnicodeError):
                    os.close(child)
                    raise
                return stack.enter_context(stream)

            tty_in = wrap("r")
            tty_out = wrap("w")
            tty_out.write(
                "ONLY in a dedicated disposable OS account, pre-authenticated "
                "to a disposable MEGA account, never a personal account.\n"
                "This will invoke read-only mega-exec whoami then sync; "
                "the vendor server may access the network.\n"
                "Type READ_DISPOSABLE_ONLY to proceed: "
            )
            tty_out.flush()
            # Refuse to run any vendor query without an exact bounded opt-in.
            if tty_in.readline(64).strip() != "READ_DISPOSABLE_ONLY":
                return "operator_confirmation_mismatch", None

            # If getpass cannot disable terminal echo, fail closed rather
            # than falling back to reading and echoing private account data.
            with warnings.catch_warnings():
                warnings.simplefilter("error", getpass.GetPassWarning)
                expected = getpass.getpass(
                    "Disposable MEGA email (not logged): ",
                    stream=tty_out,
                )
            reason = classify_disposable_email(expected)
            if reason is not None:
                return reason, None
            return None, expected.encode("ascii")
    except (OSError, EOFError, UnicodeError, ValueError,
            getpass.GetPassWarning):
        return "tty_confirmation_unavailable", None

def self_test():
    assert parse_snapshot(
        b"ID|RUN_STATE|STATUS\nAbcDef12_-x|Running|Synced\n"
    ) == "nonempty_shape"
    assert parse_snapshot(b"\n") == "source_blank_line_candidate"
    assert parse_snapshot(b"\n\n") == "invalid"
    assert parse_snapshot(b"UNEXPECTED\n") == "invalid"
    for value in [
        b"ID|RUN_STATE|STATUS\n",
        b"ID|RUN_STATE|STATUS\nAbcDef12_-x|UNKNOWN|Synced\n",
        b"ID|RUN_STATE|STATUS\nAbcDef12_-x|Running|Synced|EXTRA\n",
        b"ID|RUN_STATE|STATUS\nAbcDef12_-x|Running|Synced\n"
        b"AbcDef12_-x|Disabled|Pending\n",
        b"ID|RUN_STATE|STATUS\nAbcDef12_-x|Running|Synced",
        b"ID|RUN_STATE|STATUS\nPRIVATE/SECRET|Running|Synced\n",
    ]:
        if value.endswith(b"STATUS\n"):
            assert parse_snapshot(value) == "header_only"
        else:
            assert parse_snapshot(value) == "invalid"
    # A syntactically valid fake marker is NOT an identity guarantee.
    assert parse_snapshot(
        b"ID|RUN_STATE|STATUS\nPRIVATE_SECRET|Pending|NONE\n"
    ) == "nonempty_shape"
    assert not private_dir(Path("/nonexistent/disposable"), 100000)
    assert not trusted_program(None)
    assert existing_server(Path("/nonexistent/mega-cmd-server"), -1) == []
    print(summary("selftest_pass"))

def main():
    if sys.argv[1:] == ["--self-test"]:
        self_test()
        return 0
    if sys.argv[1:] != ["--read-disposable-session-only"]:
        print(summary("explicit_acknowledgment_required"))
        return 20

    if os.geteuid() == 0:
        print(summary("dedicated_os_user_required"))
        return 20
    try:
        account = pwd.getpwuid(os.geteuid())
        if (account.pw_name != EXPECTED_USER
                or account.pw_uid != os.getuid()
                or account.pw_dir in ("/", "/home", "/root")):
            print(summary("dedicated_os_user_required"))
            return 20
        home = Path(account.pw_dir)
        runtime = Path(os.environ.get("XDG_RUNTIME_DIR", ""))
        if (not private_dir(home, account.pw_uid)
                or not private_dir(runtime, account.pw_uid)
                or runtime != Path(f"/run/user/{account.pw_uid}")):
            print(summary("untrusted_home_or_runtime"))
            return 20

        allowed = BOUNDARY["allowed_binary"]
        version = allowed("mega-version")
        server = allowed(SERVER_NAME)
        executor = allowed("mega-exec")
        if (not all([version, server, executor])
                or not all(map(trusted_program, (version, server, executor)))
                or any(p[0].parent != version[0].parent
                       or p[1].parent != version[1].parent
                       for p in (server, executor))):
            print(summary("missing_or_untrusted_vendor"))
            return 20
        pair = [version, server]
        if not PRIVATE["verify_private_lib_mount"](pair):
            print(summary("private_library_gate_failed"))
            return 20
        if not CAT["package_executor_owned"](pair, executor):
            print(summary("executor_package_mismatch"))
            return 20

        servers = existing_server(server[1], account.pw_uid)
        if len(servers) != 1:
            reason = ("disposable_server_not_running" if not servers
                      else "ambiguous_private_server")
            print(summary(reason))
            return 20

        try:
            with open("/dev/tty", "rb"):
                pass
        except OSError:
            print(summary("tty_required", server=True))
            return 20
        reason, expected = tty_confirmation()
        if reason is not None:
            print(summary(reason, server=True))
            return 20

        # No inherited host session overrides, proxy credentials, debug
        # flags or shell startup files. No startup if the private server
        # is absent; re-verify exact private PID before the Sync query.
        env = {
            "HOME": str(home), "USER": EXPECTED_USER,
            "LOGNAME": EXPECTED_USER,
            "XDG_RUNTIME_DIR": str(runtime),
            "PATH": str(executor[0].parent) + ":/usr/bin:/bin",
            "LANG": "C.UTF-8", "LC_ALL": "C.UTF-8",
        }
        rc, out, err, error = bounded_read(
            [str(executor[0]), "whoami"], env
        )
        if error:
            print(summary("whoami_" + error, server=True))
            return 21
        if rc != 0 or err:
            print(summary("whoami_failed_or_ambiguous", server=True))
            return 21
        identities = set(IDENTITY.findall(out))
        if len(identities) != 1:
            print(summary("whoami_failed_or_ambiguous", server=True))
            return 21
        if expected not in identities:
            print(summary("account_identity_mismatch", server=True))
            return 21
        # whoami may have exited zero while the background server changed.
        if existing_server(server[1], account.pw_uid) != servers:
            print(summary("server_changed_during_probe", server=True,
                          identity=True))
            return 21

        rc, out, err, error = bounded_read(
            [
                str(executor[0]), "sync",
                "--output-cols=ID,RUN_STATE,STATUS",
                "--col-separator=|",
            ],
            env,
        )
        if error:
            print(summary("sync_" + error, server=True, identity=True))
            return 21
        if rc != 0 or err:
            print(summary("sync_failed_or_diagnostic", server=True,
                          identity=True))
            return 21
        if existing_server(server[1], account.pw_uid) != servers:
            print(summary("server_changed_during_probe", server=True,
                          identity=True))
            return 21
        # Zero-byte stdout is NOT proof of an empty cloud account.
        if not out:
            print(summary("sync_no_snapshot_unqualified", server=True,
                          identity=True))
            return 21
        result = parse_snapshot(out)
        if result == "header_only":
            print(summary("sync_header_only_not_qualified", server=True,
                          identity=True))
            return 21
        if result == "source_blank_line_candidate":
            print(summary("sync_source_blank_line_candidate_unqualified",
                          server=True, identity=True))
            return 21
        # Distinguish a bounded, complete but unknown header from malformed
        # rows without ever reporting or logging its actual contents.
        if result != "nonempty_shape":
            expected_header = (b"ID|RUN_STATE|STATUS\n",
                               b"ID|RUN_STATE|STATUS\r\n")
            reason = ("sync_header_or_row_invalid"
                      if out.startswith(expected_header)
                      else "sync_unexpected_header_unqualified")
            print(summary(reason, server=True, identity=True))
            return 21
        print(summary("sync_shape_observed_unqualified", server=True,
                      identity=True, rows=True))
        return 0
    except (OSError, RuntimeError, ValueError, KeyError,
            subprocess.TimeoutExpired):
        print(summary("supervisor_error"))
        return 21

if __name__ == "__main__":
    sys.exit(main())
