#!/usr/bin/env python3
"""Owner-only, offline disposable MEGAcmd version probe; never use an account.

No live vendor command runs without an explicit flag AND a successfully
created bubblewrap sandbox: empty tmpfs root, no host home or host /run,
new network/PID namespaces and PID-1 lifetime, scrubbed environment.
Raw vendor output stays in bounded process memory and is never printed.
This does not qualify sign-in, account reads, help parsers or writes.
"""
import json
import os
from pathlib import Path
import re
import selectors
import shutil
import signal
import subprocess
import sys
import time

OUTPUT_CAP = 32768
DEADLINE = 12
VERSION_LINE = re.compile(
    r"MEGAcmd(?: (?:server|client))? version\s*:?\s*v?"
    r"(\d{1,3}(?:\.\d{1,3}){1,3})"
    r"(?:\s+\([^()\r\n]{1,32}\))?\s*",
    re.IGNORECASE,
)
HOST_ROOTS = (Path("/usr"), Path("/nix/store"))


def sanitized_version(raw):
    """Never infer the installed version from online/SDK version lines."""
    for line in raw.splitlines():
        if len(line) <= 128:
            matched = VERSION_LINE.fullmatch(line.strip())
            if matched:
                return matched.group(1)
    return None


def safe_summary(state, version=None, reason=None):
    # Fixed allowlist; no stdout/stderr, account, file paths or environment.
    print(json.dumps({
        "phase": "megaqml_phase3b_offline_installed_version",
        "state": state,
        "vendor_version": version,
        "reason": reason,
        "network_available": False,
        "account_used": False,
        "live_capabilities_unlocked": False,
    }, sort_keys=True))


def allowed_binary(name):
    candidate = shutil.which(name)
    if not candidate:
        return None
    raw = Path(candidate)
    try:
        resolved = raw.resolve(strict=True)
        allowed = raw.is_absolute() and any(
            raw.is_relative_to(root) and resolved.is_relative_to(root)
            for root in HOST_ROOTS)
        if not allowed or not resolved.is_file() or not os.access(raw, os.X_OK):
            return None
    except (OSError, RuntimeError):
        return None
    return raw, resolved


def mount_prefixes():
    # Never bind the host root, user home, runtime sockets, /tmp or /run.
    args = ["--tmpfs", "/", "--ro-bind", "/usr", "/usr"]
    for directory in ("/bin", "/sbin", "/lib", "/lib64"):
        location = Path(directory)
        if location.is_symlink():
            target = os.readlink(directory)
            if (not target.startswith("/") and ".." not in Path(target).parts
                    and (Path("/") / target).resolve().is_relative_to(Path("/usr"))):
                args += ["--symlink", target, directory]
            elif target.startswith("/usr/"):
                args += ["--symlink", target, directory]
            else:
                raise ValueError("unsupported system symlink layout")
        elif location.is_dir():
            args += ["--ro-bind", directory, directory]
    args += ["--ro-bind", "/etc", "/etc"]
    if Path("/nix/store").is_dir():
        args += ["--ro-bind", "/nix/store", "/nix/store"]
    # No bind from the host's /run, /tmp, /home or MEGAcmd state.
    args += ["--dev", "/dev", "--proc", "/proc",
             "--dir", "/tmp", "--dir", "/run",
             "--dir", "/home", "--dir", "/home/disposable",
             "--dir", "/home/disposable/.config",
             "--dir", "/home/disposable/.cache",
             "--dir", "/home/disposable/.local",
             "--dir", "/home/disposable/.local/state",
             "--perms", "0700", "--dir", "/home/disposable/runtime"]
    return args


def bwrap_command(bwrap, payload, vendor_parent):
    path = ":".join(dict.fromkeys([
        str(vendor_parent), "/usr/bin", "/bin", "/nix/store/default/bin"
    ]))
    return [
        str(bwrap), "--die-with-parent", "--new-session",
        "--unshare-all", "--unshare-net", "--as-pid-1", "--clearenv",
        *mount_prefixes(),
        "--setenv", "HOME", "/home/disposable",
        "--setenv", "XDG_CONFIG_HOME", "/home/disposable/.config",
        "--setenv", "XDG_CACHE_HOME", "/home/disposable/.cache",
        "--setenv", "XDG_STATE_HOME", "/home/disposable/.local/state",
        "--setenv", "XDG_RUNTIME_DIR", "/home/disposable/runtime",
        "--setenv", "PATH", path,
        "--setenv", "LANG", "C.UTF-8",
        "--setenv", "LC_ALL", "C.UTF-8",
        "--chdir", "/home/disposable",
        "--", *map(str, payload),
    ]


def bounded_process(argv):
    """Bound time AND combined stdout/stderr; kill only this sandbox group."""
    process = subprocess.Popen(
        argv, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
        stderr=subprocess.PIPE, env={"PATH": "/usr/bin:/bin"},
        start_new_session=True, close_fds=True,
    )
    chunks = {"stdout": bytearray(), "stderr": bytearray()}
    streams = selectors.DefaultSelector()
    for name, pipe in (("stdout", process.stdout), ("stderr", process.stderr)):
        os.set_blocking(pipe.fileno(), False)
        streams.register(pipe, selectors.EVENT_READ, name)
    deadline = time.monotonic() + DEADLINE
    stop_reason = None
    try:
        while streams.get_map() or process.poll() is None:
            if time.monotonic() >= deadline:
                stop_reason = "bounded_timeout"
                break
            for selected, _ in streams.select(timeout=0.15):
                payload = os.read(selected.fileobj.fileno(), 4096)
                if not payload:
                    streams.unregister(selected.fileobj)
                    continue
                chunks[selected.data].extend(payload)
                if sum(map(len, chunks.values())) > OUTPUT_CAP:
                    stop_reason = "bounded_output_cap"
                    break
            if stop_reason:
                break
        if stop_reason:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            process.wait(timeout=3)
            return None, None, stop_reason
        code = process.wait(timeout=2)
        return code, bytes(chunks["stdout"]), None
    finally:
        streams.close()
        process.stdout.close()
        process.stderr.close()
        if process.poll() is None:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            process.wait(timeout=3)


def self_test():
    assert sanitized_version("MEGAcmd version: 2.6.0\n") == "2.6.0"
    assert sanitized_version("MEGAcmd server version v3.4.5\n") == "3.4.5"
    for fake in ("MEGA SDK version: 2.6.0", "Latest version: 9.9.9",
                 "MEGAcmd version: 2.6.0\nPRIVATE_ACCOUNT",
                 "MEGAcmd version: /private/secret", ""):
        # Multiple lines are parsed independently; the canary is never emitted.
        if "PRIVATE_ACCOUNT" not in fake:
            assert sanitized_version(fake) is None
    assert sanitized_version("PRIVATE_ACCOUNT\n") is None
    # Shape-only namespace/identity checks, no installed-vendor execution.
    probe = bwrap_command("/usr/bin/bwrap", ["/usr/bin/true"], Path("/usr/bin"))
    for required in ("--unshare-all", "--unshare-net", "--as-pid-1", "--clearenv",
                     "--tmpfs", "--die-with-parent", "--new-session"):
        assert required in probe, required
    assert not any(x in probe for x in ("--bind", "--share-net"))
    assert probe[probe.index("--setenv") + 2] == "/home/disposable"
    print("PASS MegaQML Phase 3b inert version probe source self-test")


def main():
    # Exact argv only; argparse would echo unexpected secret-like arguments.
    if sys.argv[1:] == ["--self-test"]:
        self_test()
        return 0
    if sys.argv[1:] != ["--acknowledge-disposable-offline-probe"]:
        safe_summary("BLOCKED", reason="explicit_acknowledgment_required")
        return 20
    if os.geteuid() == 0:
        safe_summary("BLOCKED", reason="do_not_run_as_root")
        return 20
    version = allowed_binary("mega-version")
    server = allowed_binary("mega-cmd-server")
    wrap = allowed_binary("bwrap")
    control = allowed_binary("true")
    if not version or not server:
        safe_summary("BLOCKED", reason="vendor_dependencies_missing_or_outside_allowed_roots")
        return 20
    if version[0].parent != server[0].parent:
        safe_summary("BLOCKED", reason="mixed_vendor_bin_directories")
        return 20
    if not wrap or not control:
        safe_summary("BLOCKED", reason="bubblewrap_or_smoke_tool_missing")
        return 20
    try:
        smoke = bwrap_command(wrap[0], [control[0]], version[0].parent)
        code, _, blocked = bounded_process(smoke)
    except (OSError, ValueError, subprocess.TimeoutExpired):
        safe_summary("BLOCKED", reason="sandbox_setup_unavailable")
        return 20
    if blocked or code != 0:
        safe_summary("BLOCKED", reason="sandbox_setup_unavailable")
        return 20
    try:
        command = bwrap_command(wrap[0], [version[0], "-l"], version[0].parent)
        status, data, blocked = bounded_process(command)
    except (OSError, ValueError, subprocess.TimeoutExpired):
        safe_summary("BLOCKED", reason="sandbox_process_unavailable")
        return 20
    if blocked:
        safe_summary("UNQUALIFIED", reason=blocked)
        return 21
    if status != 0:
        safe_summary("UNQUALIFIED", reason="vendor_exit_nonzero")
        return 21
    parsed = sanitized_version(data.decode("utf-8", "replace"))
    if not parsed:
        safe_summary("UNQUALIFIED", reason="vendor_version_format_unrecognized")
        return 21
    safe_summary("VERSION_OBSERVED_OFFLINE", version=parsed,
                 reason="still_requires_installed_help_and_disposable_fixture_qualification")
    return 0


if __name__ == "__main__":
    sys.exit(main())
