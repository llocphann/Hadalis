#!/usr/bin/env python3
"""Isolated diagnostics value and lifecycle parity.

A temporary Python target process allocates stable memory and owns a child.
Both samplers observe the same /proc target. A second short-lived target checks
that each backend emits shell-process-gone and exits with code 2.
"""

from __future__ import annotations

import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import time
from typing import Any

REPO = Path(__file__).resolve().parents[2]
PYTHON_SAMPLER = REPO / "scripts" / "runtime-diagnostics-sampler.py"


def sampler_argv(kind: str, rust: Path, pid: int) -> list[str]:
    if kind == "python":
        return [
            sys.executable,
            str(PYTHON_SAMPLER),
            "--pid",
            str(pid),
            "--interval-ms",
            "250",
        ]
    return [str(rust), "diagnostics", "--pid", str(pid), "--interval-ms", "250"]


def parse_lines(raw: str) -> list[dict[str, Any]]:
    result = []
    for line in raw.splitlines():
        line = line.strip()
        if line:
            result.append(json.loads(line))
    return result


def stop_sampler(proc: subprocess.Popen[str]) -> tuple[int, list[dict[str, Any]], str]:
    proc.send_signal(signal.SIGTERM)
    out, err = proc.communicate(timeout=4)
    return proc.returncode, parse_lines(out), err


def value_at(value: dict[str, Any], *keys: str) -> Any:
    current: Any = value
    for key in keys:
        if not isinstance(current, dict):
            return None
        current = current.get(key)
    return current


def close_enough(left: int, right: int, floor_kib: int = 4096, fraction: float = 0.20) -> bool:
    allowance = max(floor_kib, int(max(abs(left), abs(right)) * fraction))
    return abs(left - right) <= allowance


def compare_value_samples(py: dict[str, Any], rs: dict[str, Any], pid: int, child_pid: int) -> None:
    if value_at(py, "shell", "pid") != pid or value_at(rs, "shell", "pid") != pid:
        raise AssertionError("sampler shell pid does not match fixture target")

    for name, sample in (("python", py), ("rust", rs)):
        children = value_at(sample, "shell", "children")
        if not isinstance(children, list) or child_pid not in {
            row.get("pid") for row in children if isinstance(row, dict)
        }:
            raise AssertionError(f"{name} sampler did not report fixture child {child_pid}")
        mem_total = value_at(sample, "system", "memory", "valuesKiB", "MemTotal")
        if not isinstance(mem_total, int) or mem_total <= 0:
            raise AssertionError(f"{name} sampler has invalid MemTotal: {mem_total!r}")
        rss = value_at(sample, "shell", "memory", "valuesKiB", "Rss")
        if not isinstance(rss, int) or rss < 16 * 1024:
            raise AssertionError(f"{name} sampler has implausible fixture RSS: {rss!r}")

    for field in ("Rss", "Pss"):
        pval = value_at(py, "shell", "memory", "valuesKiB", field)
        rval = value_at(rs, "shell", "memory", "valuesKiB", field)
        if isinstance(pval, int) and isinstance(rval, int) and not close_enough(pval, rval):
            raise AssertionError(
                f"shell {field} differs beyond tolerance: python={pval} rust={rval}"
            )

    py_uptime = value_at(py, "system", "uptimeSeconds")
    rs_uptime = value_at(rs, "system", "uptimeSeconds")
    if isinstance(py_uptime, (int, float)) and isinstance(rs_uptime, (int, float)):
        if abs(float(py_uptime) - float(rs_uptime)) > 2.0:
            raise AssertionError(
                f"uptime samples unexpectedly far apart: python={py_uptime} rust={rs_uptime}"
            )

    py_cpu = value_at(py, "shell", "cpu", "percent")
    rs_cpu = value_at(rs, "shell", "cpu", "percent")
    for name, cpu in (("python", py_cpu), ("rust", rs_cpu)):
        if cpu is not None and not (0.0 <= float(cpu) <= 100.0):
            raise AssertionError(f"{name} CPU percent out of range: {cpu!r}")


def kill_pid(pid: int) -> None:
    try:
        os.kill(pid, signal.SIGTERM)
    except ProcessLookupError:
        pass


def value_parity(rust: Path) -> None:
    fixture = (
        "import subprocess,time\n"
        "blob=bytearray(24*1024*1024)\n"
        "for i in range(0,len(blob),4096): blob[i]=1\n"
        "child=subprocess.Popen(['sleep','10'])\n"
        "print(child.pid, flush=True)\n"
        "time.sleep(10)\n"
    )
    target = subprocess.Popen(
        [sys.executable, "-c", fixture],
        stdout=subprocess.PIPE,
        text=True,
    )
    assert target.stdout is not None
    child_pid = int(target.stdout.readline().strip())
    samplers = {
        kind: subprocess.Popen(
            sampler_argv(kind, rust, target.pid),
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        for kind in ("python", "rust")
    }
    try:
        time.sleep(1.15)
        captured = {kind: stop_sampler(proc) for kind, proc in samplers.items()}
        samples: dict[str, list[dict[str, Any]]] = {}
        for kind, (code, rows, err) in captured.items():
            if code != 0:
                raise AssertionError(f"{kind} sampler stop rc={code} stderr={err!r}")
            good = [row for row in rows if "error" not in row]
            if len(good) < 2:
                raise AssertionError(f"{kind} sampler emitted only {len(good)} value samples")
            samples[kind] = good
        compare_value_samples(samples["python"][-1], samples["rust"][-1], target.pid, child_pid)
    finally:
        for proc in samplers.values():
            if proc.poll() is None:
                proc.kill()
        if target.poll() is None:
            target.terminate()
        try:
            target.wait(timeout=2)
        except subprocess.TimeoutExpired:
            target.kill()
        kill_pid(child_pid)

    print("PASS diagnostics: stable memory/child/value parity")


def lifecycle_parity(rust: Path) -> None:
    target = subprocess.Popen(["sleep", "1.2"])
    samplers = {
        kind: subprocess.Popen(
            sampler_argv(kind, rust, target.pid),
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        for kind in ("python", "rust")
    }
    target.wait(timeout=3)
    for kind, proc in samplers.items():
        out, err = proc.communicate(timeout=5)
        rows = parse_lines(out)
        if proc.returncode != 2:
            raise AssertionError(f"{kind} sampler lifecycle rc={proc.returncode} stderr={err!r}")
        if not any("shell" in row for row in rows):
            raise AssertionError(f"{kind} sampler emitted no live sample before target exit")
        if not rows or rows[-1].get("error") != "shell-process-gone":
            raise AssertionError(f"{kind} sampler did not end with shell-process-gone: {rows[-1:]!r}")
        if rows[-1].get("pid") != target.pid:
            raise AssertionError(f"{kind} sampler lifecycle pid mismatch")

    print("PASS diagnostics: target-gone lifecycle parity")


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: check-diagnostics-parity.py /path/to/inir-native", file=sys.stderr)
        return 64
    rust = Path(sys.argv[1]).resolve()
    if not rust.is_file():
        print(f"Rust binary not found: {rust}", file=sys.stderr)
        return 2
    value_parity(rust)
    lifecycle_parity(rust)
    print("PASS: diagnostics value and lifecycle parity use isolated fixture processes")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
