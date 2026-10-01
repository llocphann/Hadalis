#!/usr/bin/env python3
"""Private stdio relay for REAL production Wull click-delivery evidence.

Not a mock backend: the exact private inir-companiond release executable
remains the only Rust daemon. Relay passes JSON lines unchanged and records
ONLY bounded event/ack markers outside the checkout for a future isolated
nested-Niri pointer test. Never enable this in normal production.
"""
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import threading
import time


MAX_LINE = 8192
MAX_TRACE_EVENTS = 1024


def require_isolated_session():
    env = os.environ
    if env.get("WULL_PRIVATE_POINTER_SESSION") != "isolated-nested-only":
        raise RuntimeError("private_nested_pointer_session_not_authorized")
    nested_display = env.get("WAYLAND_DISPLAY", "")
    host_display = env.get("WULL_PARENT_WAYLAND_DISPLAY", "")
    nested_socket = env.get("NIRI_SOCKET", "")
    host_socket = env.get("WULL_PARENT_NIRI_SOCKET", "")
    if (not nested_display or not host_display
            or nested_display == host_display
            or not nested_socket or not host_socket
            or nested_socket == host_socket):
        raise RuntimeError("nested_wayland_or_niri_identity_unproven")
    executable = Path(env.get("WULL_PRIVATE_POINTER_BINARY", ""))
    trace = Path(env.get("WULL_PRIVATE_POINTER_TRACE", ""))
    if not executable.is_absolute() or not executable.is_file():
        raise RuntimeError("private_exact_binary_unavailable")
    if not trace.is_absolute() or trace.exists() or not trace.parent.is_dir():
        raise RuntimeError("private_trace_path_unavailable")
    checkout = Path(__file__).resolve().parents[3]
    if trace == checkout or checkout in trace.parents:
        raise RuntimeError("private_pointer_trace_inside_checkout")
    return executable, trace


def main():
    if len(sys.argv) != 1:
        raise RuntimeError("relay_does_not_accept_command_arguments")
    os.umask(0o077)
    binary, trace_path = require_isolated_session()
    lock = threading.Lock()
    seen = [0]
    errors = []
    child = None

    with trace_path.open("x", encoding="utf-8") as trace:
        def marker(kind, **values):
            with lock:
                if seen[0] >= MAX_TRACE_EVENTS:
                    return
                payload = {"kind": kind, "when_monotonic": time.monotonic()}
                payload.update(values)
                trace.write(json.dumps(payload, separators=(",", ":")) + "\n")
                trace.flush()
                seen[0] += 1

        def handle_signal(number, _frame):
            raise SystemExit(128 + number)

        signal.signal(signal.SIGTERM, handle_signal)
        signal.signal(signal.SIGINT, handle_signal)
        try:
            child = subprocess.Popen(
                [str(binary)], stdin=subprocess.PIPE,
                stdout=subprocess.PIPE, stderr=sys.stderr,
                close_fds=True, start_new_session=False,
            )

            def downstream():
                try:
                    while True:
                        line = child.stdout.readline(MAX_LINE + 1)
                        if not line:
                            return
                        if len(line) > MAX_LINE or not line.endswith(b"\n"):
                            errors.append("daemon_oversized_or_partial_reply")
                            return
                        sys.stdout.buffer.write(line)
                        sys.stdout.buffer.flush()
                        try:
                            value = json.loads(line)
                        except (ValueError, UnicodeDecodeError):
                            continue
                        if (isinstance(value, dict) and value.get("v") == 1
                                and value.get("type") == "state"
                                and value.get("mood") == "happy"
                                and value.get("pulse", 0) >= 0.7):
                            marker("rust_happy_pulse_ack")
                except (OSError, ValueError):
                    errors.append("daemon_output_unavailable")

            reader = threading.Thread(target=downstream, daemon=True)
            reader.start()
            while True:
                line = sys.stdin.buffer.readline(MAX_LINE + 1)
                if not line:
                    break
                if len(line) > MAX_LINE or not line.endswith(b"\n"):
                    errors.append("bridge_oversized_or_partial_input")
                    break
                try:
                    value = json.loads(line)
                except (ValueError, UnicodeDecodeError):
                    value = None
                if (isinstance(value, dict)
                        and value.get("v") == 1
                        and value.get("type") == "event"
                        and value.get("event") == "click"):
                    marker("real_bridge_click_received")
                child.stdin.write(line)
                child.stdin.flush()
            if child.stdin and not child.stdin.closed:
                child.stdin.close()
            try:
                child.wait(timeout=5)
            except subprocess.TimeoutExpired:
                child.terminate()
                child.wait(timeout=3)
            reader.join(timeout=2)
        finally:
            if child is not None and child.poll() is None:
                child.terminate()
                try:
                    child.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    child.kill()
                    child.wait(timeout=3)
        if errors:
            raise RuntimeError(errors[0])


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, OSError, ValueError, BrokenPipeError) as error:
        print("WULL_PRIVATE_RELAY_STOP:", error, file=sys.stderr)
        sys.exit(1)
