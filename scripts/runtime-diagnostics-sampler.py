#!/usr/bin/env python3
"""On-demand kernel sampler for Hadalis Runtime Diagnostics.

This process is started only by the main Quickshell process while a Diagnostics
lease is active. It emits one JSON object per line and never invents per-QML
resource attribution.
"""

from __future__ import annotations

import argparse
import json
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


def read_system_cpu_ticks() -> dict[str, tuple[int, int]]:
    text = _read_text(Path("/proc/stat"))
    result: dict[str, tuple[int, int]] = {}
    for line in text.splitlines():
        fields = line.split()
        if not fields or not re.fullmatch(r"cpu(?:\d+)?", fields[0]):
            continue
        if len(fields) < 5:
            continue
        try:
            values = [int(value) for value in fields[1:]]
        except ValueError:
            continue
        # guest/guest_nice are already included in user/nice on Linux.
        # Excluding them avoids double-counting CPU time under virtualization.
        total = sum(values[:8])
        idle = values[3] + (values[4] if len(values) > 4 else 0)
        result[fields[0]] = (total, idle)
    return result


def read_load_average() -> list[float]:
    text = _read_text(Path("/proc/loadavg")).strip()
    fields = text.split()
    values: list[float] = []
    for raw in fields[:3]:
        try:
            values.append(float(raw))
        except ValueError:
            break
    return values


def read_uptime_seconds() -> float | None:
    text = _read_text(Path("/proc/uptime")).strip()
    if not text:
        return None
    try:
        return max(0.0, float(text.split()[0]))
    except (ValueError, IndexError):
        return None


def _cpu_percent_from_ticks(
    current: tuple[int, int] | None,
    previous: tuple[int, int] | list[int] | None,
) -> float | None:
    if current is None or previous is None or len(previous) != 2:
        return None
    total_delta = current[0] - int(previous[0])
    idle_delta = current[1] - int(previous[1])
    if total_delta <= 0 or idle_delta < 0:
        return None
    return max(0.0, min(100.0, (1.0 - idle_delta / total_delta) * 100.0))


def read_system_memory() -> dict[str, Any]:
    text = _read_text(Path("/proc/meminfo"))
    values: dict[str, int] = {}
    for key in ("MemTotal", "MemAvailable", "SwapTotal", "SwapFree"):
        match = re.search(rf"^{key}:\s+(\d+)\s+kB\s*$", text, re.MULTILINE)
        if match:
            values[key] = int(match.group(1))

    mem_total = values.get("MemTotal")
    mem_available = values.get("MemAvailable")
    swap_total = values.get("SwapTotal")
    swap_free = values.get("SwapFree")
    mem_used = (
        max(0, mem_total - mem_available)
        if mem_total is not None and mem_available is not None
        else None
    )
    swap_used = (
        max(0, swap_total - swap_free)
        if swap_total is not None and swap_free is not None
        else None
    )
    return {
        "scope": "system",
        "method": "proc-meminfo",
        "confidence": "kernel",
        "valuesKiB": {
            "MemTotal": mem_total,
            "MemAvailable": mem_available,
            "MemUsed": mem_used,
            "SwapTotal": swap_total,
            "SwapFree": swap_free,
            "SwapUsed": swap_used,
        },
    }


def read_sched_runtime_ns(pid: int) -> int | None:
    # /proc/<pid>/schedstat covers only the thread represented by <pid>.
    # Sum task schedstat counters so multithreaded Quickshell/helpers report
    # process CPU rather than main-thread CPU.
    task_dir = Path("/proc") / str(pid) / "task"
    total = 0
    found = False
    try:
        tasks = list(task_dir.iterdir())
    except OSError:
        tasks = []

    for task in tasks:
        text = _read_text(task / "schedstat").strip()
        if not text:
            continue
        try:
            total += int(text.split()[0])
            found = True
        except (ValueError, IndexError):
            continue

    if found:
        return total

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


def read_process_status(pid: int) -> dict[str, int]:
    text = _read_text(Path("/proc") / str(pid) / "status")
    values: dict[str, int] = {}
    for key, out_key in (("VmRSS", "Rss"), ("VmSwap", "Swap")):
        match = re.search(rf"^{key}:\s+(\d+)\s+kB\s*$", text, re.MULTILINE)
        if match:
            values[out_key] = int(match.group(1))
    return values


def read_process_command(pid: int) -> str:
    # Keep diagnostics safe for display/IPC: command lines can contain secrets.
    # /proc/<pid>/comm is enough to identify the executable without copying argv.
    comm = " ".join(
        _read_text(Path("/proc") / str(pid) / "comm").strip().split()
    )
    return comm or f"pid-{pid}"


def read_process_start_ticks(pid: int) -> int | None:
    # Field 22 is starttime. Split after the final ')' because comm itself may
    # contain spaces or parentheses.
    text = _read_text(Path("/proc") / str(pid) / "stat").strip()
    closing = text.rfind(")")
    if closing < 0:
        return None
    fields = text[closing + 1:].split()
    if len(fields) <= 19:
        return None
    try:
        return int(fields[19])
    except ValueError:
        return None


def read_process_children(pid: int) -> list[int]:
    # A child can be forked by any thread in a process. Reading only
    # task/<tgid>/children misses helpers spawned by worker threads.
    task_dir = Path("/proc") / str(pid) / "task"
    try:
        tasks = list(task_dir.iterdir())
    except OSError:
        tasks = []

    children: set[int] = set()
    for task in tasks:
        text = _read_text(task / "children").strip()
        if not text:
            continue
        for raw in text.split():
            try:
                child = int(raw)
            except ValueError:
                continue
            if child > 0:
                children.add(child)
    return sorted(children)


def read_descendants(pid: int) -> list[tuple[int, int]]:
    result: list[tuple[int, int]] = []
    queue = [pid]
    seen = {pid}
    while queue:
        parent = queue.pop(0)
        for child in read_process_children(parent):
            if child in seen:
                continue
            seen.add(child)
            result.append((child, parent))
            queue.append(child)
    return result


def sample_children(
    shell_pid: int,
    previous: dict[str, Any],
    elapsed_ns: int,
) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    next_state: dict[str, Any] = {}
    previous_children = previous.get("children", {})
    if not isinstance(previous_children, dict):
        previous_children = {}

    for child_pid, parent_pid in read_descendants(shell_pid):
        proc_dir = Path("/proc") / str(child_pid)
        if not proc_dir.exists():
            continue
        command = read_process_command(child_pid)
        start_ticks = read_process_start_ticks(child_pid)
        runtime_ns = read_sched_runtime_ns(child_pid)
        old = previous_children.get(str(child_pid), {})
        cpu = None
        if (
            runtime_ns is not None
            and elapsed_ns > 0
            and isinstance(old, dict)
            and old.get("command") == command
            and old.get("startTicks") == start_ticks
            and start_ticks is not None
            and isinstance(old.get("runtimeNs"), int)
            and runtime_ns >= old["runtimeNs"]
        ):
            cpu = (runtime_ns - old["runtimeNs"]) / elapsed_ns * 100.0

        memory = read_process_status(child_pid)
        rows.append(
            {
                "pid": child_pid,
                "parentPid": parent_pid,
                "command": command,
                "cpu": {
                    "scope": "child-process",
                    "method": "schedstat",
                    "confidence": "kernel",
                    "percent": cpu,
                },
                "memory": {
                    "scope": "child-process",
                    "method": "proc-status",
                    "confidence": "kernel",
                    "valuesKiB": memory,
                },
            }
        )
        next_state[str(child_pid)] = {
            "runtimeNs": runtime_ns,
            "command": command,
            "startTicks": start_ticks,
        }

    rows.sort(
        key=lambda row: (
            -(row["cpu"]["percent"] or 0.0),
            -row["memory"]["valuesKiB"].get("Rss", 0),
            row["pid"],
        )
    )
    return rows, next_state


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
    system_cpu_now = read_system_cpu_ticks()
    load_average = read_load_average()
    uptime_seconds = read_uptime_seconds()
    io_now = read_io(pid)
    net_now = read_network()
    previous = previous or {}

    slow_previous = previous.get("slow", {})
    if not isinstance(slow_previous, dict):
        slow_previous = {}
    slow_at_ns = slow_previous.get("atNs")
    slow_elapsed_ns = (
        now_ns - slow_at_ns if isinstance(slow_at_ns, int) else 0
    )
    refresh_slow = (
        not isinstance(slow_at_ns, int)
        or slow_elapsed_ns >= 2_000_000_000
    )
    if refresh_slow:
        memory_now = read_memory(pid)
        drm_now = read_drm(pid)
    else:
        memory_now = slow_previous.get("memory")
        drm_now = slow_previous.get("drm")
        if not isinstance(memory_now, dict):
            memory_now = read_memory(pid)
        if not isinstance(drm_now, dict):
            drm_now = read_drm(pid)
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

    previous_system_cpu = previous.get("systemCpu", {})
    if not isinstance(previous_system_cpu, dict):
        previous_system_cpu = {}
    system_cpu_percent = _cpu_percent_from_ticks(
        system_cpu_now.get("cpu"), previous_system_cpu.get("cpu")
    )
    core_cpu_percent: list[float | None] = []
    core_names = sorted(
        (name for name in system_cpu_now if name != "cpu"),
        key=lambda name: int(name[3:]) if name[3:].isdigit() else name,
    )
    for name in core_names:
        core_cpu_percent.append(
            _cpu_percent_from_ticks(
                system_cpu_now.get(name), previous_system_cpu.get(name)
            )
        )

    child_rows, child_state = sample_children(pid, previous, elapsed_ns)

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
    aggregate_interface_count = 0
    aggregate_has_rx_rate = True
    aggregate_has_tx_rate = True
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
            aggregate_interface_count += 1
            aggregate_rx += counters["rxBytes"]
            aggregate_tx += counters["txBytes"]
            if rx_rate is None:
                aggregate_has_rx_rate = False
            else:
                aggregate_rx_rate += rx_rate
            if tx_rate is None:
                aggregate_has_tx_rate = False
            else:
                aggregate_tx_rate += tx_rate

    if refresh_slow:
        prev_drm = slow_previous.get("drm", {})
        if not isinstance(prev_drm, dict):
            prev_drm = {}
        prev_engines = prev_drm.get("enginesNs", {})
        if not isinstance(prev_engines, dict):
            prev_engines = {}
        engine_busy: dict[str, float | None] = {}
        for name, counter in drm_now["enginesNs"].items():
            old = prev_engines.get(name)
            engine_busy[name] = (
                None
                if (
                    not isinstance(old, int)
                    or slow_elapsed_ns <= 0
                    or counter < old
                )
                else (counter - old) / slow_elapsed_ns * 100.0
            )
        slow_state = {
            "atNs": now_ns,
            "memory": memory_now,
            "drm": drm_now,
            "engineBusy": engine_busy,
        }
    else:
        cached_busy = slow_previous.get("engineBusy", {})
        engine_busy = (
            cached_busy if isinstance(cached_busy, dict) else {}
        )
        slow_state = slow_previous

    payload = {
        "atMs": now_ms,
        "system": {
            "cpu": {
                "scope": "system",
                "method": "proc-stat",
                "confidence": "kernel",
                "percent": system_cpu_percent,
                "coresPercent": core_cpu_percent,
                "coreNames": core_names,
                "loadAverage": load_average,
            },
            "memory": read_system_memory(),
            "uptimeSeconds": uptime_seconds,
        },
        "shell": {
            "pid": pid,
            "cpu": {
                "scope": "shell-process",
                "method": "schedstat",
                "confidence": "kernel",
                "percent": cpu_percent,
            },
            "memory": memory_now,
            "io": {
                "scope": "shell-process",
                "method": "proc-io",
                "confidence": "kernel",
                "counters": io_now,
                "rates": io_rates,
            },
            "children": child_rows,
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
                "rxBytesPerSec": (
                    aggregate_rx_rate
                    if aggregate_interface_count > 0
                    and aggregate_has_rx_rate
                    else None
                ),
                "txBytesPerSec": (
                    aggregate_tx_rate
                    if aggregate_interface_count > 0
                    and aggregate_has_tx_rate
                    else None
                ),
            },
        },
    }

    state = {
        "monotonicNs": now_ns,
        "runtimeNs": runtime_ns,
        "systemCpu": {
            name: list(ticks) for name, ticks in system_cpu_now.items()
        },
        "io": io_now,
        "network": net_now,
        "slow": slow_state,
        "children": child_state,
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

    target_start_ticks = read_process_start_ticks(args.pid)
    if target_start_ticks is None:
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

    previous: dict[str, Any] | None = None
    while not _STOP:
        started = time.monotonic()
        try:
            if read_process_start_ticks(args.pid) != target_start_ticks:
                raise ProcessLookupError(args.pid)
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
