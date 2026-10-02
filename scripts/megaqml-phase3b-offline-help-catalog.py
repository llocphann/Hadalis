#!/usr/bin/env python3
"""One opt-in no-account/no-network isolated MEGAcmd version + HELP CATALOG check.

This is NOT help/parser or server-identity qualification. Never publishes or
prints host paths, installed version digits, raw stdout/stderr, or log content.
"""
import json
import os
from pathlib import Path
import runpy
import stat
import subprocess
import sys

HERE = Path(__file__).resolve().parent
BOUNDARY = runpy.run_path(str(HERE / "megaqml-manual-disposable-version-probe.py"),
                          run_name="help_boundary_import")
PRIVATE = runpy.run_path(str(HERE / "megaqml-phase3b-private-lib-mount.py"),
                         run_name="help_private_import")
COMMANDS = ("version", "df", "sync", "transfers")
REASONS = frozenset({
    "explicit_acknowledgment_required", "do_not_run_as_root",
    "missing_host_dependency", "vendor_binary_mismatch",
    "private_lib_mount_validation_failed", "executor_not_package_owned",
    "sandbox_setup_unavailable", "sandbox_process_unavailable",
    "bounded_timeout", "bounded_output_cap", "sandbox_supervisor_error",
    "sandbox_supervisor_output_invalid", "version_command_failed",
    "version_unrecognized", "version_ambiguous", "help_command_failed",
    "help_catalog_output_limit", "help_catalog_unrecognized",
    "help_catalog_partial", "help_catalog_observed",
})

def summary(reason, version=False, commands=None):
    assert reason in REASONS and type(version) is bool
    if commands is None:
        commands = {name: False for name in COMMANDS}
    assert set(commands) == set(COMMANDS)
    assert all(type(v) is bool for v in commands.values())
    state = ("CATALOG_OBSERVED_OFFLINE" if reason == "help_catalog_observed"
             else "CATALOG_PARTIAL_OFFLINE" if reason == "help_catalog_partial"
             else "UNQUALIFIED" if reason in {
                 "version_command_failed", "version_unrecognized",
                 "version_ambiguous", "help_command_failed",
                 "help_catalog_output_limit", "help_catalog_unrecognized",
                 "sandbox_supervisor_error", "sandbox_supervisor_output_invalid",
                 "bounded_timeout", "bounded_output_cap"}
             else "BLOCKED")
    return json.dumps({
        "phase": "megaqml_phase3b_offline_help_catalog",
        "state": state, "reason": reason,
        "version_line_consistent": version, "commands": commands,
        "network_available": False, "account_used": False,
        "server_identity_qualified": False,
        "help_parsers_qualified": False, "live_capabilities_unlocked": False,
    }, sort_keys=True, separators=(",", ":"))

def package_executor_owned(pair, executor):
    """Match executor path to SAME read-only pacman record as vendor pair."""
    tags = PRIVATE["LAYOUT"]["STATIC"]["path_tags"](pair)
    root = Path("/var/lib/pacman/local")
    raw, resolved = executor
    try:
        for p in (raw, resolved, raw.parent, resolved.parent):
            st = p.stat()
            if st.st_uid != 0 or st.st_mode & 0o022:
                return False
        if raw.parent != pair[0][0].parent or resolved.parent != pair[0][1].parent:
            return False
        allowed = {raw.as_posix().lstrip("/"), resolved.as_posix().lstrip("/")}
        allowed |= {name + "/" for name in allowed}
        for entry in sorted(root.iterdir()):
            if (entry.is_symlink() or not entry.is_dir()
                    or not any(entry.name.startswith(n + "-")
                               for n in PRIVATE["LAYOUT"]["STATIC"]["PKGS"])):
                continue
            desc = PRIVATE["LAYOUT"]["STATIC"]["safe_read"](entry / "desc")
            files = PRIVATE["LAYOUT"]["STATIC"]["safe_read"](entry / "files")
            if not desc or not files:
                continue
            meta = PRIVATE["LAYOUT"]["STATIC"]["fields"](desc)
            if (meta.get("%NAME%") not in PRIVATE["LAYOUT"]["STATIC"]["PKGS"]
                    or not PRIVATE["LAYOUT"]["STATIC"]["package_version"](
                        meta.get("%VERSION%"))):
                continue
            names = {line.lstrip("/") for line in files.splitlines()
                     if line and not line.startswith("%")}
            if all(tag & names for tag in tags) and (
                    raw.as_posix().lstrip("/") in names
                    and resolved.as_posix().lstrip("/") in names):
                return True
    except (OSError, RuntimeError):
        return False
    return False

INNER = r'''
import json, os, re, selectors, signal, subprocess, sys, time
CMDS = ("version", "df", "sync", "transfers")
VERSION = re.compile(
    r"MEGAcmd(?: (?:server|client))? version\s*:?\s*v?"
    r"(\d{1,3}(?:\.\d{1,3}){1,3})"
    r"(?:\s*:\s*code\s+\d{1,10})?"
    r"(?:\s+\(64 bits\))?\s*", re.IGNORECASE)

def version_ok(raw):
    found = set()
    for line in raw.decode("utf-8", "replace").splitlines():
        if len(line) <= 128:
            m = VERSION.fullmatch(line.strip())
            if m: found.add(m.group(1))
    if len(found) > 1: return "version_ambiguous"
    return "ok" if found else "version_unrecognized"

def catalog(raw):
    # Only a line-leading command name, not an incidental substring, counts.
    items = dict.fromkeys(CMDS, False)
    if len(raw) > 16384:
        return items, "help_catalog_output_limit"
    for line in raw.decode("utf-8", "replace").splitlines():
        m = re.match(r"^\s{0,12}(version|df|sync|transfers)(?=\s|:|$)", line,
                     re.IGNORECASE)
        if m: items[m.group(1).lower()] = True
    return items, ("help_catalog_observed" if all(items.values())
                   else "help_catalog_partial" if any(items.values())
                   else "help_catalog_unrecognized")

def bounded(argv, deadline):
    p = subprocess.Popen(argv, stdin=subprocess.DEVNULL,
                         stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                         start_new_session=True, close_fds=True)
    selector = selectors.DefaultSelector()
    for pipe in (p.stdout, p.stderr):
        os.set_blocking(pipe.fileno(), False)
        selector.register(pipe, selectors.EVENT_READ)
    chunks = {p.stdout.fileno(): bytearray(), p.stderr.fileno(): bytearray()}
    reason = None
    try:
        while selector.get_map() or p.poll() is None:
            if time.monotonic() >= deadline:
                reason = "bounded_timeout"
                break
            for item, _ in selector.select(timeout=0.06):
                payload = os.read(item.fileobj.fileno(), 1024)
                if not payload:
                    selector.unregister(item.fileobj)
                else:
                    chunks[item.fileobj.fileno()].extend(payload)
                    if sum(map(len, chunks.values())) > 16384:
                        reason = "bounded_output_cap"
                        break
            if reason: break
        if reason:
            if p.poll() is None:
                try: os.killpg(p.pid, signal.SIGKILL)
                except ProcessLookupError: pass
            p.wait(timeout=1)
            return None, b"", reason
        rc = p.wait(timeout=1)
        return rc, bytes(chunks[p.stdout.fileno()]), None
    finally:
        selector.close()
        for pipe in (p.stdout, p.stderr): pipe.close()
        if p.poll() is None:
            try: os.killpg(p.pid, signal.SIGKILL)
            except ProcessLookupError: pass
            p.wait(timeout=1)

def emit(reason, version=False, commands=None):
    assert reason in {
        "version_command_failed", "version_unrecognized", "version_ambiguous",
        "help_command_failed", "help_catalog_output_limit",
        "help_catalog_unrecognized", "help_catalog_partial",
        "help_catalog_observed", "bounded_timeout", "bounded_output_cap",
        "sandbox_supervisor_error"}
    if commands is None: commands = dict.fromkeys(CMDS, False)
    print(json.dumps({"reason":reason,"version_line_consistent":version,
                      "commands":commands}, sort_keys=True))

def main():
    try:
        if sys.argv[1:] == ["--self-test"]:
            assert version_ok(b"MEGAcmd version: 1.2.3.4: code 123\n") == "ok"
            assert version_ok(b"MEGA SDK version: 4.5.6\n") == "version_unrecognized"
            assert version_ok(b"MEGAcmd version: 1.2.3\nMEGAcmd version: 1.2.4\n") == "version_ambiguous"
            good = b"  version  a\n  df  b\n sync  c\n transfers  d\n"
            assert catalog(good)[1] == "help_catalog_observed"
            assert catalog(b"download version b\n")[1] == "help_catalog_unrecognized"
            assert catalog(b" sync  c\n")[1] == "help_catalog_partial"
            emit("help_catalog_observed", True, dict.fromkeys(CMDS, True))
            return
        if len(sys.argv) != 2 or not (
                sys.argv[1].startswith(("/usr/", "/nix/store/"))
                and sys.argv[1].endswith("/mega-exec")):
            raise ValueError("unapproved executor")
        exe = sys.argv[1]
        deadline = time.monotonic() + 8.5
        # BOTH commands execute inside the SAME fresh disconnected sandbox.
        rc, version, reason = bounded([exe, "version", "-l"], deadline)
        if reason:
            emit(reason); return
        if rc != 0:
            emit("version_command_failed"); return
        category = version_ok(version)
        if category != "ok":
            emit(category); return
        rc, help_text, reason = bounded([exe, "help", "-f"], deadline)
        if reason:
            emit(reason, True); return
        if rc != 0:
            emit("help_command_failed", True); return
        observed, kind = catalog(help_text)
        emit(kind, True, observed)
    except BaseException:
        emit("sandbox_supervisor_error")
main()
'''

def accept_inner(raw):
    try:
        obj = json.loads(raw.decode("utf-8"))
        if (type(obj) is not dict
                or set(obj) != {"reason", "version_line_consistent", "commands"}
                or obj["reason"] not in REASONS
                or type(obj["version_line_consistent"]) is not bool
                or type(obj["commands"]) is not dict
                or set(obj["commands"]) != set(COMMANDS)
                or not all(type(v) is bool for v in obj["commands"].values())):
            return None
        reason = obj["reason"]
        ver = obj["version_line_consistent"]
        cmds = obj["commands"]
        if reason in {"help_catalog_observed", "help_catalog_partial",
                      "help_catalog_unrecognized"} and not ver:
            return None
        if reason == "help_catalog_observed" and not all(cmds.values()):
            return None
        if reason == "help_catalog_partial" and (
                not any(cmds.values()) or all(cmds.values())):
            return None
        if reason == "help_catalog_unrecognized" and any(cmds.values()):
            return None
        if reason in {"version_command_failed", "version_unrecognized",
                      "version_ambiguous"} and (ver or any(cmds.values())):
            return None
        if reason in {"help_command_failed", "help_catalog_output_limit"} and (
                not ver or any(cmds.values())):
            return None
        if reason in {"bounded_timeout", "bounded_output_cap"} and any(
                cmds.values()):
            return None
        if reason == "sandbox_supervisor_error" and (ver or any(cmds.values())):
            return None
        return obj
    except (UnicodeDecodeError, ValueError, TypeError):
        return None

def self_test():
    p = subprocess.run([sys.executable, "-I", "-S", "-c", INNER, "--self-test"],
                       capture_output=True, stdin=subprocess.DEVNULL,
                       timeout=4, check=True)
    obj = accept_inner(p.stdout)
    assert obj and obj["reason"] == "help_catalog_observed"
    assert accept_inner(b'{"reason":"help_catalog_observed","version_line_consistent":true,"commands":{"version":true,"df":true,"sync":true,"transfers":true},"raw":"PRIVATE"}') is None
    assert accept_inner(b"PRIVATE_ACCOUNT_CANARY") is None
    print("PASS MegaQML isolated help-catalog inert self-test")

def main():
    if sys.argv[1:] == ["--self-test"]:
        self_test()
        return 0
    if sys.argv[1:] != ["--acknowledge-disposable-offline-help-catalog"]:
        print(summary("explicit_acknowledgment_required"));return 20
    if os.geteuid() == 0:
        print(summary("do_not_run_as_root"));return 20
    allowed = BOUNDARY["allowed_binary"]
    version, server, exe, wrap, python, true = (
        allowed("mega-version"), allowed("mega-cmd-server"),
        allowed("mega-exec"), allowed("bwrap"), allowed("python3"),
        allowed("true"))
    if not all((version, server, exe, wrap, python, true)):
        print(summary("missing_host_dependency"));return 20
    if (version[0].parent != server[0].parent
            or version[1].parent != server[1].parent):
        print(summary("vendor_binary_mismatch"));return 20
    try:
        if not PRIVATE["verify_private_lib_mount"](
                [(version[0], version[1]), (server[0], server[1])]):
            print(summary("private_lib_mount_validation_failed"));return 20
        if not package_executor_owned(
                [(version[0], version[1]), (server[0], server[1])], exe):
            print(summary("executor_not_package_owned"));return 20
        sandbox = BOUNDARY["bwrap_command"]
        bounded = BOUNDARY["bounded_process"]
        def command(payload):
            return sandbox(wrap[0], payload, version[0].parent,
                           private_megacmd_lib=True)
        code, _, _, blocked = bounded(command([true[0]]))
        if blocked or code != 0:
            print(summary("sandbox_setup_unavailable"));return 20
        code, output, _, blocked = bounded(
            command([python[0], "-I", "-S", "-c", INNER, str(exe[0])]))
    except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired):
        print(summary("sandbox_process_unavailable"));return 20
    if blocked:
        print(summary(blocked));return 21
    if code != 0:
        print(summary("sandbox_supervisor_error"));return 21
    obj = accept_inner(output)
    if obj is None:
        print(summary("sandbox_supervisor_output_invalid"));return 21
    print(summary(obj["reason"],obj["version_line_consistent"],obj["commands"]))
    return 0 if obj["reason"] == "help_catalog_observed" else 21

if __name__ == "__main__":
    sys.exit(main())
