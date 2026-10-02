#!/usr/bin/env python3
"""Owner-only, offline vendor startup classification INSIDE a disposable sandbox.

Never attach to a host server, share the host HOME/runtime, enable network,
collect credentials, reveal logs or qualify cloud features. The only
vendor call is sandboxed mega-version -l after a nonvendor smoke probe.
"""
import json
from pathlib import Path
import runpy
import sys

BASE = Path(__file__).with_name("megaqml-manual-disposable-version-probe.py")
BOUNDARY = runpy.run_path(str(BASE), run_name="megaqml_boundary_import")
# No host inspection unless the separately authorized new CLI flag is used.
PRIVATE = runpy.run_path(str(Path(__file__).with_name(
    "megaqml-phase3b-private-lib-mount.py")), run_name="private_lib_import")

# Executed as /usr/bin/python3 -I -S -c ... *inside* bwrap PID namespace.
# No host files other than readonly system binaries are mounted.
INNER = r'''
import json, os, selectors, signal, subprocess, sys, time

CATEGORIES = {
 "sandbox_server_log_absent",
 "sandbox_server_log_library_missing",
 "sandbox_server_log_socket_failure",
 "sandbox_server_log_permission_failure",
 "sandbox_server_log_network_event",
 "sandbox_server_log_other",
 "sandbox_client_library_missing",
 "sandbox_client_socket_failure",
 "sandbox_client_server_launch_failed",
 "sandbox_client_server_handshake_failed",
 "sandbox_client_output_limited",
 "sandbox_supervisor_error",
}
def classify(raw):
    s = raw.decode("utf-8", "replace").lower()
    if ("error while loading shared libraries" in s
            or "cannot open shared object file" in s):
        return "sandbox_server_log_library_missing"
    if ("failed to create folder for unix socket" in s
            or "error creating runtime directory for socket file" in s
            or "could not get runtime folder for socket path" in s):
        return "sandbox_server_log_socket_failure"
    if any(x in s for x in ("permission denied", "operation not permitted",
                            "filesystem is read-only", "read-only file system")):
        return "sandbox_server_log_permission_failure"
    if any(x in s for x in ("network is unreachable", "network unreachable",
                            "could not resolve host", "host not found",
                            "name or service not known", "couldn't connect to api")):
        return "sandbox_server_log_network_event"
    return "sandbox_server_log_other"

def classify_client(raw):
    """Fixed fallback only when the private sandbox server log is absent."""
    s = raw.decode("utf-8", "replace").lower()
    if ("error while loading shared libraries" in s
            or "cannot open shared object file" in s):
        return "sandbox_client_library_missing"
    if ("error creating runtime directory for socket file" in s
            or "could not get runtime folder for socket path" in s):
        return "sandbox_client_socket_failure"
    if ("couln't initiate megacmd server" in s
            or "couldn't initiate megacmd server" in s
            or "megacmd server exit with code" in s):
        return "sandbox_client_server_launch_failed"
    if ("unable to connect to service" in s
            or "please ensure mega-cmd-server is running" in s
            or "megacmd server is not responding" in s):
        return "sandbox_client_server_handshake_failed"
    return "sandbox_server_log_absent"

def select_category(chunks, captured, output_limited):
    # The vendor can create empty stdout/stderr redirects before logging.
    # Prefer bounded nonempty sandbox-owned logs, including the main log.
    server_text = b"\n".join(part for part in chunks if part.strip())
    if server_text:
        return classify(server_text)
    if output_limited:
        return "sandbox_client_output_limited"
    return classify_client(b"\n".join(captured.values()))

def diagnostic(version):
    p = subprocess.Popen([version, "-l"], stdin=subprocess.DEVNULL,
                         stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                         close_fds=True, start_new_session=True)
    stream = selectors.DefaultSelector()
    for name, pipe in (("stdout", p.stdout), ("stderr", p.stderr)):
        os.set_blocking(pipe.fileno(), False)
        stream.register(pipe, selectors.EVENT_READ, name)
    captured = {"stdout": bytearray(), "stderr": bytearray()}
    until = time.monotonic() + 8.5
    timeout = False
    output_limited = False
    try:
        while stream.get_map() or p.poll() is None:
            if time.monotonic() >= until:
                timeout = True
                break
            for ready, _ in stream.select(timeout=.10):
                part = os.read(ready.fileobj.fileno(), 1024)
                if not part:
                    stream.unregister(ready.fileobj)
                else:
                    captured[ready.data].extend(part)
                    if sum(map(len, captured.values())) > 8192:
                        output_limited = True
                        break
            if timeout or output_limited:
                break
    finally:
        if p.poll() is None:
            try:
                os.killpg(p.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
        p.wait(timeout=1.0)
        stream.close()
        p.stdout.close()
        p.stderr.close()
    # The log can only be from this tmpfs HOME in the isolated namespace.
    # A child server may have setsid()'d; when this PID-1 exits, the
    # namespace tears down all remaining sandbox processes.
    chunks = []
    found = False
    for suffix in (".err", ".out", ""):
        log = "/home/disposable/.megaCmd/megacmdserver.log" + suffix
        try:
            with open(log, "rb") as handle:
                chunks.append(handle.read(4096))
                found = True
        except (FileNotFoundError, PermissionError, OSError):
            pass
    category = select_category(chunks, captured, output_limited)
    # No raw vendor client output or ephemeral server log may escape.
    return {"category": category, "client_timed_out": timeout,
            "server_log_present": found}

def main():
    try:
        if sys.argv[1:] == ["--self-test"]:
            assert classify(b"error while loading shared libraries") == "sandbox_server_log_library_missing"
            assert classify(b"failed to create folder for unix socket") == "sandbox_server_log_socket_failure"
            assert classify(b"permission denied") == "sandbox_server_log_permission_failure"
            assert classify(b"network is unreachable") == "sandbox_server_log_network_event"
            assert classify(b"PRIVATE_FAKE_CANARY") == "sandbox_server_log_other"
            assert classify_client(b"error while loading shared libraries: FAKE") == "sandbox_client_library_missing"
            assert classify_client(b"error creating runtime directory for socket file") == "sandbox_client_socket_failure"
            assert classify_client(b"Couln't initiate MEGAcmd server") == "sandbox_client_server_launch_failed"
            assert classify_client(b"Unable to connect to service: fake") == "sandbox_client_server_handshake_failed"
            assert classify_client(b"PRIVATE_FAKE_CANARY") == "sandbox_server_log_absent"
            fake_client = {"stdout": bytearray(), "stderr": bytearray(b"Unable to connect to service")}
            assert select_category([b"", b"", b"network is unreachable"], fake_client, False) == "sandbox_server_log_network_event"
            assert select_category([b"", b""], fake_client, False) == "sandbox_client_server_handshake_failed"
            assert select_category([b"", b""], fake_client, True) == "sandbox_client_output_limited"
            print(json.dumps({"category": "sandbox_server_log_other",
                              "client_timed_out": False,
                              "server_log_present": False}))
            return
        if len(sys.argv) != 2 or sys.argv[1] != "/usr/bin/mega-version":
            # Caller supplies only a previously verified, readonly system
            # path; accept /usr/lib, /usr/local/bin and Nix-store layouts too.
            if (len(sys.argv) != 2
                    or not sys.argv[1].startswith(("/usr/", "/nix/store/"))
                    or not sys.argv[1].endswith("/mega-version")):
                raise ValueError("unknown binary")
        result = diagnostic(sys.argv[1])
        assert result["category"] in CATEGORIES
        print(json.dumps(result, sort_keys=True))
    except BaseException:
        # Deliberately never emit a Python traceback, paths, diagnostics.
        print(json.dumps({"category": "sandbox_supervisor_error",
                          "client_timed_out": False,
                          "server_log_present": False}))
main()
'''

CATEGORIES = frozenset({
    "sandbox_server_log_absent",
    "sandbox_server_log_library_missing",
    "sandbox_server_log_socket_failure",
    "sandbox_server_log_permission_failure",
    "sandbox_server_log_network_event",
    "sandbox_server_log_other",
    "sandbox_client_library_missing",
    "sandbox_client_socket_failure",
    "sandbox_client_server_launch_failed",
    "sandbox_client_server_handshake_failed",
    "sandbox_client_output_limited",
    "sandbox_supervisor_error",
})


def safe_summary(reason, has_log=False, client_timed_out=False):
    assert reason in CATEGORIES or reason in {
        "sandbox_setup_unavailable", "sandbox_process_unavailable",
        "bounded_timeout", "bounded_output_cap", "missing_host_dependency",
        "mixed_vendor_bin_directories", "sandbox_supervisor_output_invalid",
        "do_not_run_as_root", "private_lib_mount_validation_failed",
    }
    return json.dumps({
        "phase": "megaqml_phase3b_offline_startup_diagnostic",
        "state": "UNQUALIFIED",
        "reason": reason,
        "sandbox_log_present": has_log is True,
        "sandbox_client_timed_out": client_timed_out is True,
        "network_available": False,
        "account_used": False,
        "server_version_qualified": False,
        "live_capabilities_unlocked": False,
    }, sort_keys=True)


def accept_inner(raw):
    try:
        # Strip nothing but protocol whitespace; fail closed on extra lines.
        value = json.loads(raw.decode("utf-8"))
        if (type(value) is not dict
                or set(value) != {"category", "client_timed_out",
                                  "server_log_present"}
                or value["category"] not in CATEGORIES
                or type(value["client_timed_out"]) is not bool
                or type(value["server_log_present"]) is not bool):
            return None
        return value
    except (UnicodeDecodeError, ValueError, TypeError):
        return None


def self_test():
    # The nested Python self-test is safe and runs without any vendor.
    import subprocess
    x = subprocess.run([sys.executable, "-I", "-S", "-c", INNER, "--self-test"],
                       stdin=subprocess.DEVNULL, capture_output=True,
                       timeout=4, check=True)
    assert accept_inner(x.stdout) == {
        "category": "sandbox_server_log_other",
        "client_timed_out": False, "server_log_present": False}
    assert accept_inner(b'{"category":"sandbox_server_log_other","server_log_present":true,"client_timed_out":false,"secret":"private"}') is None
    assert accept_inner(b"PRIVATE_ACCOUNT_CANARY") is None
    summary = safe_summary("sandbox_server_log_absent")
    assert "PRIVATE_ACCOUNT_CANARY" not in summary
    print("PASS Phase3b disposable startup diagnostic inert self-test")


def main():
    if sys.argv[1:] == ["--self-test"]:
        self_test()
        return 0
    private_libraries = sys.argv[1:] == ["--acknowledge-isolated-offline-private-libs-test"]
    if not private_libraries and sys.argv[1:] != ["--acknowledge-isolated-offline-startup-diagnostic"]:
        print(safe_summary("missing_host_dependency"))
        return 20
    if __import__("os").geteuid() == 0:
        print(safe_summary("do_not_run_as_root"))
        return 20
    allow = BOUNDARY["allowed_binary"]
    ver, server, python, bwrap, true = (
        allow("mega-version"), allow("mega-cmd-server"), allow("python3"),
        allow("bwrap"), allow("true"))
    if not all((ver, server, python, bwrap, true)):
        print(safe_summary("missing_host_dependency"))
        return 20
    if (ver[0].parent != server[0].parent
            or ver[1].parent != server[1].parent):
        print(safe_summary("mixed_vendor_bin_directories"))
        return 20
    # The original flag uses the unchanged sandbox. The new, separately
    # authorized flag alone can opt into the verified private read-only mount.
    if private_libraries:
        try:
            pair = [(ver[0], ver[1]), (server[0], server[1])]
            approved = PRIVATE["verify_private_lib_mount"](pair)
        except (OSError, ValueError, RuntimeError):
            approved = False
        if not approved:
            print(safe_summary("private_lib_mount_validation_failed"))
            return 20
    sandbox = BOUNDARY["bwrap_command"]
    bounded = BOUNDARY["bounded_process"]
    def command(payload):
        if private_libraries:
            return sandbox(bwrap[0], payload, ver[0].parent,
                           private_megacmd_lib=True)
        return sandbox(bwrap[0], payload, ver[0].parent)
    try:
        rc, _, _, blocked = bounded(
            command([true[0]]))
        if blocked or rc != 0:
            print(safe_summary("sandbox_setup_unavailable"))
            return 20
        rc, output, _, blocked = bounded(
            command([python[0], "-I", "-S", "-c", INNER, str(ver[0])]))
    except (OSError, ValueError, __import__("subprocess").TimeoutExpired):
        print(safe_summary("sandbox_process_unavailable"))
        return 20
    if blocked:
        print(safe_summary(blocked))
        return 21
    if rc != 0:
        print(safe_summary("sandbox_supervisor_error"))
        return 21
    event = accept_inner(output)
    if event is None:
        print(safe_summary("sandbox_supervisor_output_invalid"))
        return 21
    print(safe_summary(event["category"], event["server_log_present"],
                       event["client_timed_out"]))
    # This is an explanation-only diagnostic, NEVER qualification.
    return 21


if __name__ == "__main__":
    sys.exit(main())
