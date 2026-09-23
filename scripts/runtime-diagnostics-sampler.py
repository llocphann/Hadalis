#!/usr/bin/env python3
"""On-demand kernel sampler for Hadalis Runtime Diagnostics.

This process is started only by the main Quickshell process while a Diagnostics
lease is active. It emits one JSON object per line and never invents per-QML
resource attribution.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import signal
import time
from pathlib import Path
from typing import Any

_STOP = False
_KIB_FIELDS = (
    "Rss",
    "Pss",
    "Pss_Anon",
    "Pss_File",
    "Pss_Shmem",
    "Private_Clean",
    "Private_Dirty",
    "Shared_Clean",
    "Shared_Dirty",
    "Swap",
    "SwapPss",
)


def _stop(_signum: int, _frame: Any) -> None:
    global _STOP
    _STOP = True


def _read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return ""


def parse_kib_fields(text: str) -> dict[str, int]:
    values: dict[str, int] = {}
    for line in text.splitlines():
        match = re.match(r"^([A-Za-z_]+):\s+(\d+)\s+kB\s*$", line)
        if not match:
            continue
        key = match.group(1)
        if key in _KIB_FIELDS:
            values[key] = int(match.group(2))
    return values


def read_memory(pid: int) -> dict[str, Any]:
    proc = Path("/proc") / str(pid)
    rollup = parse_kib_fields(_read_text(proc / "smaps_rollup"))
    if rollup:
        return {
            "scope": "shell-process",
            "method": "smaps-rollup",
            "confidence": "kernel",
            "valuesKiB": rollup,
        }

    status = _read_text(proc / "status")
    fallback: dict[str, int] = {}
    for key, out_key in (("VmRSS", "Rss"), ("VmSwap", "Swap")):
        match = re.search(rf"^{key}:\s+(\d+)\s+kB\s*$", status, re.MULTILINE)
        if match:
            fallback[out_key] = int(match.group(1))
    return {
        "scope": "shell-process",
        "method": "proc-status",
        "confidence": "kernel",
        "valuesKiB": fallback,
    }


def read_sched_runtime_ns(pid: int) -> int | None:
    text = _read_text(Path("/proc") / str(pid) / "schedstat").strip()
    if not text:
        return None
    try:
        return int(text.split()[0])
    except (ValueError, IndexError):
        return None


def read_io(pid: int) -> dict[str, int]:
    result: dict[str, int] = {}
    text = _read_text(Path("/proc") / str(pid) / "io")
    for line in text.splitlines():
        if ":" not in line:
            continue
        key, value = line.split(":", 1)
        key = key.strip()
        if key not in {"read_bytes", "write_bytes", "rchar", "wchar", "syscr", "syscw"}:
            continue
        try:
            result[key] = int(value.strip())
        except ValueError:
            continue
    return result


def read_network() -> dict[str, dict[str, int]]:
    interfaces: dict[str, dict[str, int]] = {}
    text = _read_text(Path("/proc/net/dev"))
    for line in text.splitlines()[2:]:
        if ":" not in line:
            continue
        name, payload = line.split(":", 1)
        fields = payload.split()
        if len(fields) < 16:
            continue
        try:
            interfaces[name.strip()] = {
                "rxBytes": int(fields[0]),
                "txBytes": int(fields[8]),
            }
        except ValueError:
            continue
    return interfaces


def _to_kib(value: int, unit: str) -> int:
    normalized = unit.strip().lower()
    if normalized in {"kb", "kib"}:
        return value
    if normalized in {"mb", "mib"}:
        return value * 1024
    if normalized in {"gb", "gib"}:
        return value * 1024 * 1024
    if normalized in {"b", "bytes", "byte"}:
        return value // 1024
    return value


def parse_drm_fdinfo(text: str) -> dict[str, Any] | None:
    client_match = re.search(r"^drm-client-id:\s*(\S+)\s*$", text, re.MULTILINE)
    if not client_match:
        return None

    engines: dict[str, int] = {}
    memory: dict[str, int] = {}
    for line in text.splitlines():
        engine = re.match(r"^drm-engine-([^:]+):\s*(\d+)\s*ns\s*$", line)
        if engine:
            engines[engine.group(1)] = int(engine.group(2))
            continue

        mem = re.match(
            r"^drm-(memory|total|shared|resident|active|purgeable)-([^:]+):"
            r"\s*(\d+)\s*([A-Za-z]+)?\s*$",
            line,
        )
        if mem:
            key = f"{mem.group(1)}-{mem.group(2)}"
            memory[key] = _to_kib(int(mem.group(3)), mem.group(4) or "KiB")

    return {
        "clientId": client_match.group(1),
        "enginesNs": engines,
        "memoryKiB": memory,
    }


def read_drm(pid: int) -> dict[str, Any]:
    fdinfo_dir = Path("/proc") / str(pid) / "fdinfo"
    clients: dict[str, dict[str, dict[str, int]]] = {}
    try:
        paths = list(fdinfo_dir.iterdir())
    except OSError:
        paths = []

    for path in paths:
        parsed = parse_drm_fdinfo(_read_text(path))
        if not parsed:
            continue
        client_id = str(parsed["clientId"])
        current = clients.setdefault(
            client_id, {"enginesNs": {}, "memoryKiB": {}}
        )
        # The same DRM client counters can appear on multiple FDs. Keep the
        # maximum per field rather than summing duplicate snapshots.
        for key, value in parsed["enginesNs"].items():
            current["enginesNs"][key] = max(
                current["enginesNs"].get(key, 0), int(value)
            )
        for key, value in parsed["memoryKiB"].items():
            current["memoryKiB"][key] = max(
                current["memoryKiB"].get(key, 0), int(value)
            )

    engines: dict[str, int] = {}
    memory: dict[str, int] = {}
    for client in clients.values():
        for key, value in client["enginesNs"].items():
            engines[key] = engines.get(key, 0) + value
        for key, value in client["memoryKiB"].items():
            memory[key] = memory.get(key, 0) + value

    return {
        "available": bool(clients),
        "clientCount": len(clients),
        "enginesNs": engines,
        "memoryKiB": memory,
    }


def _rate(current: int, previous: int | None, elapsed_s: float) -> float | None:
    if previous is None or elapsed_s <= 0 or current < previous:
        return None
    return (current - previous) / elapsed_s


def sample(pid: int, previous: dict[str, Any] | None) -> tuple[dict[str, Any], dict[str, Any]]:
    now_ns = time.monotonic_ns()
    now_ms = int(time.time() * 1000)
    proc_dir = Path("/proc") / str(pid)
    if not proc_dir.exists():
        raise ProcessLookupError(pid)

    runtime_ns = read_sched_runtime_ns(pid)
    io_now = read_io(pid)
    net_now = read_network()
    drm_now = read_drm(pid)
    previous = previous or {}
    prev_ns = previous.get("monotonicNs")
    elapsed_ns = now_ns - prev_ns if isinstance(prev_ns, int) else 0
    elapsed_s = elapsed_ns / 1_000_000_000 if elapsed_ns > 0 else 0.0

    previous_runtime = previous.get("runtimeNs")
    cpu_percent = None
    if (
        runtime_ns is not None
        and isinstance(previous_runtime, int)
        and elapsed_ns > 0
        and runtime_ns >= previous_runtime
    ):
        cpu_percent = (runtime_ns - previous_runtime) / elapsed_ns * 100.0

    prev_io = previous.get("io", {})
    io_rates = {
        "readBytesPerSec": _rate(
            io_now.get("read_bytes", 0), prev_io.get("read_bytes"), elapsed_s
        ),
        "writeBytesPerSec": _rate(
            io_now.get("write_bytes", 0), prev_io.get("write_bytes"), elapsed_s
        ),
    }

    prev_net = previous.get("network", {})
    network_interfaces: dict[str, dict[str, Any]] = {}
    aggregate_rx = 0
    aggregate_tx = 0
    aggregate_rx_rate = 0.0
    aggregate_tx_rate = 0.0
    aggregate_has_rate = False
    for name, counters in sorted(net_now.items()):
        old = prev_net.get(name, {})
        rx_rate = _rate(counters["rxBytes"], old.get("rxBytes"), elapsed_s)
        tx_rate = _rate(counters["txBytes"], old.get("txBytes"), elapsed_s)
        network_interfaces[name] = {
            **counters,
            "rxBytesPerSec": rx_rate,
            "txBytesPerSec": tx_rate,
        }
        if name != "lo":
            aggregate_rx += counters["rxBytes"]
            aggregate_tx += counters["txBytes"]
            if rx_rate is not None:
                aggregate_rx_rate += rx_rate
                aggregate_has_rate = True
            if tx_rate is not None:
                aggregate_tx_rate += tx_rate
                aggregate_has_rate = True

    prev_drm = previous.get("drm", {})
    prev_engines = prev_drm.get("enginesNs", {})
    engine_busy: dict[str, float | None] = {}
    for name, counter in drm_now["enginesNs"].items():
        old = prev_engines.get(name)
        engine_busy[name] = (
            None
            if not isinstance(old, int) or elapsed_ns <= 0 or counter < old
            else (counter - old) / elapsed_ns * 100.0
        )

    payload = {
        "atMs": now_ms,
        "shell": {
            "pid": pid,
            "cpu": {
                "scope": "shell-process",
                "method": "schedstat",
                "confidence": "kernel",
                "percent": cpu_percent,
            },
            "memory": read_memory(pid),
            "io": {
                "scope": "shell-process",
                "method": "proc-io",
                "confidence": "kernel",
                "counters": io_now,
                "rates": io_rates,
            },
            "gpu": {
                "scope": "shell-process",
                "method": "drm-fdinfo",
                "confidence": "kernel",
                "available": drm_now["available"],
                "clientCount": drm_now["clientCount"],
                "engineBusyPercent": engine_busy,
                "memoryKiB": drm_now["memoryKiB"],
            },
        },
        "network": {
            "scope": "system",
            "method": "proc-net-dev",
            "confidence": "kernel",
            "interfaces": network_interfaces,
            "aggregateNonLoopback": {
                "rxBytes": aggregate_rx,
                "txBytes": aggregate_tx,
                "rxBytesPerSec": aggregate_rx_rate if aggregate_has_rate else None,
                "txBytesPerSec": aggregate_tx_rate if aggregate_has_rate else None,
            },
        },
    }

    state = {
        "monotonicNs": now_ns,
        "runtimeNs": runtime_ns,
        "io": io_now,
        "network": net_now,
        "drm": drm_now,
    }
    return payload, state


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--pid", type=int, required=True)
    parser.add_argument("--interval-ms", type=int, default=1000)
    args = parser.parse_args()

    if args.pid <= 0:
        parser.error("--pid must be positive")
    interval_s = max(0.25, min(10.0, args.interval_ms / 1000.0))

    signal.signal(signal.SIGTERM, _stop)
    signal.signal(signal.SIGINT, _stop)

    previous: dict[str, Any] | None = None
    while not _STOP:
        started = time.monotonic()
        try:
            payload, previous = sample(args.pid, previous)
        except ProcessLookupError:
            print(
                json.dumps(
                    {
                        "error": "shell-process-gone",
                        "pid": args.pid,
                        "atMs": int(time.time() * 1000),
                    },
                    separators=(",", ":"),
                ),
                flush=True,
            )
            return 2
        except Exception as error:  # fail soft; next sample may recover
            print(
                json.dumps(
                    {
                        "error": "sample-failed",
                        "detail": str(error),
                        "pid": args.pid,
                        "atMs": int(time.time() * 1000),
                    },
                    separators=(",", ":"),
                ),
                flush=True,
            )
        else:
            print(json.dumps(payload, separators=(",", ":")), flush=True)

        remaining = interval_s - (time.monotonic() - started)
        if remaining > 0:
            time.sleep(remaining)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
