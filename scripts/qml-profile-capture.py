#!/usr/bin/env python3
"""Capture an opt-in Qt QML profile and persist Hadalis owner attribution.

The normal shell never enables QML debugging. This worker temporarily stops the
managed shell, launches Quickshell with its explicit local QML debugger port,
attaches qmlprofiler, records a bounded trace, flushes it, and restores the
service. It is safe to
launch from Quickshell because inir.service intentionally uses KillMode=process.
"""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import selectors
import shutil
import socket
import subprocess
import sys
import time
from typing import TextIO

ROOT = Path(__file__).resolve().parents[1]
NATIVE_DISPATCH = ROOT / "scripts" / "native-dispatch"
DEFAULT_STATE_DIR = Path(
    os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local" / "state"))
) / "inir" / "qml-profiles"
PROFILE_FEATURES = "javascript,memory,creating,binding,handlingsignal"


def command_exists(name: str) -> str:
    value = shutil.which(name)
    if value:
        return value
    raise RuntimeError(f"required command not found: {name}")


def runtime_environment() -> dict[str, str]:
    env = os.environ.copy()
    runtime_dir = Path(env.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}"))
    if not env.get("WAYLAND_DISPLAY"):
        candidates = sorted(runtime_dir.glob("wayland-[0-9]*"))
        if candidates:
            env["WAYLAND_DISPLAY"] = candidates[0].name
    if not env.get("NIRI_SOCKET"):
        candidates = sorted(runtime_dir.glob("niri.wayland-*.sock"))
        if candidates:
            env["NIRI_SOCKET"] = str(candidates[0])
        elif (runtime_dir / "niri" / "socket").exists():
            env["NIRI_SOCKET"] = str(runtime_dir / "niri" / "socket")
    return env


def reserve_debug_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        sock.bind(("127.0.0.1", 0))
        return int(sock.getsockname()[1])


def wait_for_debug_listener(
    port: int,
    proc: subprocess.Popen[bytes],
    timeout: float,
) -> None:
    port_hex = f"{port:04X}"
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if proc.poll() is not None:
            raise RuntimeError(
                f"Quickshell profiler instance exited early ({proc.returncode})"
            )
        for table in (Path("/proc/net/tcp"), Path("/proc/net/tcp6")):
            try:
                lines = table.read_text(encoding="ascii").splitlines()[1:]
            except OSError:
                continue
            for line in lines:
                fields = line.split()
                if len(fields) < 4 or fields[3] != "0A":
                    continue
                local = fields[1].rsplit(":", 1)
                if len(local) == 2 and local[1].upper() == port_hex:
                    return
        time.sleep(0.05)
    raise RuntimeError(
        f"Quickshell QML debugger did not listen on localhost:{port}"
    )


def service_active() -> bool:
    if shutil.which("systemctl") is None:
        return False
    return subprocess.run(
        ["systemctl", "--user", "is-active", "--quiet", "inir.service"],
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    ).returncode == 0


def service_action(action: str) -> None:
    subprocess.run(
        ["systemctl", "--user", action, "inir.service"],
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def wait_for_text(
    proc: subprocess.Popen[str],
    stream: TextIO,
    needle: str,
    timeout: float,
) -> list[str]:
    selector = selectors.DefaultSelector()
    selector.register(stream, selectors.EVENT_READ)
    lines: list[str] = []
    deadline = time.monotonic() + timeout
    try:
        while time.monotonic() < deadline:
            if proc.poll() is not None:
                remainder = stream.read()
                if remainder:
                    lines.extend(remainder.splitlines())
                raise RuntimeError(
                    "qmlprofiler exited before connecting: "
                    + " | ".join(lines[-8:])
                )
            for key, _ in selector.select(timeout=0.2):
                line = key.fileobj.readline()
                if not line:
                    continue
                lines.append(line.rstrip())
                if needle in line:
                    return lines
    finally:
        selector.close()
    raise RuntimeError(
        f"timed out waiting for qmlprofiler marker {needle!r}: "
        + " | ".join(lines[-8:])
    )


def wait_for_trace(path: Path, proc: subprocess.Popen[str], timeout: float) -> None:
    deadline = time.monotonic() + timeout
    previous_size = -1
    stable_polls = 0
    while time.monotonic() < deadline:
        if proc.poll() is not None and not path.exists():
            raise RuntimeError("qmlprofiler exited before writing the trace")
        try:
            size = path.stat().st_size
        except FileNotFoundError:
            size = 0
        if size > 256 and size == previous_size:
            stable_polls += 1
            if stable_polls >= 3:
                return
        else:
            stable_polls = 0
        previous_size = size
        time.sleep(0.15)
    raise RuntimeError(f"qmlprofiler did not flush a usable trace to {path}")


def capture(root: Path, duration: float, state_dir: Path) -> tuple[Path, Path]:
    qmlprofiler = command_exists("qmlprofiler")
    qs = shutil.which("qs") or shutil.which("quickshell")
    if not qs:
        raise RuntimeError("required command not found: qs/quickshell")
    if not NATIVE_DISPATCH.is_file():
        raise RuntimeError(f"native dispatcher not found: {NATIVE_DISPATCH}")
    preflight = subprocess.run(
        [str(NATIVE_DISPATCH), "qml-profile", "--help"],
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
        text=True,
    )
    if preflight.returncode != 0:
        raise RuntimeError(
            "inir-native qml-profile is unavailable; update/rebuild the native "
            "runtime before deep profiling"
        )

    state_dir.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%d-%H%M%S")
    trace = state_dir / f"trace-{stamp}.qtd"
    summary = state_dir / f"profile-{stamp}.json"
    latest = state_dir / "latest.json"

    was_service_active = service_active()
    profiler: subprocess.Popen[str] | None = None
    profile_shell: subprocess.Popen[bytes] | None = None
    shell_log = None
    try:
        if was_service_active:
            service_action("stop")
            time.sleep(0.35)

        debug_port = reserve_debug_port()
        shell_log = (state_dir / f"shell-{stamp}.log").open("wb")
        profile_shell = subprocess.Popen(
            [
                qs,
                "-n",
                "-p",
                str(root),
                "--debug",
                str(debug_port),
                "--waitfordebug",
            ],
            stdin=subprocess.DEVNULL,
            stdout=shell_log,
            stderr=subprocess.STDOUT,
            env=runtime_environment(),
        )
        wait_for_debug_listener(debug_port, profile_shell, timeout=12.0)

        command = [
            qmlprofiler,
            "--interactive",
            "--record",
            "off",
            "--include",
            PROFILE_FEATURES,
            "--attach",
            "127.0.0.1",
            "--port",
            str(debug_port),
        ]
        profiler = subprocess.Popen(
            command,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
            env=runtime_environment(),
        )
        assert profiler.stdin is not None
        assert profiler.stdout is not None

        wait_for_text(profiler, profiler.stdout, "Connected to", timeout=12.0)
        profiler.stdin.write("r\n")
        profiler.stdin.flush()
        time.sleep(max(1.0, duration))

        profiler.stdin.write(f"f {trace}\n")
        profiler.stdin.flush()
        wait_for_trace(trace, profiler, timeout=12.0)

        profiler.stdin.write("q\n")
        profiler.stdin.flush()
        try:
            profiler.wait(timeout=5.0)
        except subprocess.TimeoutExpired:
            profiler.terminate()
            profiler.wait(timeout=3.0)

        result = subprocess.run(
            [
                str(NATIVE_DISPATCH),
                "qml-profile",
                "--trace",
                str(trace),
                "--root",
                str(root),
            ],
            check=True,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
        payload = json.loads(result.stdout)
        payload["capture"] = {
            "durationSeconds": duration,
            "features": PROFILE_FEATURES.split(","),
            "capturedAtMs": int(time.time() * 1000),
        }
        encoded = json.dumps(payload, ensure_ascii=False, separators=(",", ":"))
        summary.write_text(encoded + "\n", encoding="utf-8")
        temp_latest = latest.with_suffix(".json.tmp")
        temp_latest.write_text(encoded + "\n", encoding="utf-8")
        os.replace(temp_latest, latest)
        return trace, summary
    finally:
        if profiler is not None and profiler.poll() is None:
            profiler.terminate()
            try:
                profiler.wait(timeout=2.0)
            except subprocess.TimeoutExpired:
                profiler.kill()
        if profile_shell is not None and profile_shell.poll() is None:
            profile_shell.terminate()
            try:
                profile_shell.wait(timeout=3.0)
            except subprocess.TimeoutExpired:
                profile_shell.kill()
        if shell_log is not None:
            shell_log.close()
        if was_service_active:
            try:
                service_action("restart")
            except subprocess.CalledProcessError as error:
                print(
                    f"WARNING: failed to restore inir.service: {error}",
                    file=sys.stderr,
                )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Capture a bounded QML Profiler trace and aggregate Hadalis "
            "component/module/service work."
        )
    )
    parser.add_argument(
        "--root",
        type=Path,
        default=ROOT,
        help="Hadalis/Quickshell config root (default: repository/runtime root)",
    )
    parser.add_argument(
        "--duration",
        type=float,
        default=5.0,
        help="recording window in seconds (1-30, default: 5)",
    )
    parser.add_argument(
        "--state-dir",
        type=Path,
        default=DEFAULT_STATE_DIR,
        help="trace/summary output directory",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    duration = min(30.0, max(1.0, float(args.duration)))
    root = args.root.expanduser().resolve()
    if not (root / "shell.qml").is_file():
        print(f"Hadalis root does not contain shell.qml: {root}", file=sys.stderr)
        return 64
    try:
        trace, summary = capture(root, duration, args.state_dir.expanduser())
    except (RuntimeError, OSError, subprocess.CalledProcessError, json.JSONDecodeError) as error:
        print(f"QML profile capture failed: {error}", file=sys.stderr)
        return 1
    print(json.dumps({
        "ok": True,
        "trace": str(trace),
        "summary": str(summary),
        "latest": str(args.state_dir.expanduser() / "latest.json"),
    }))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
