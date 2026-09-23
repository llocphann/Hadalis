#!/usr/bin/env python3
"""Pure parser tests for the Runtime Diagnostics kernel sampler."""

from __future__ import annotations

import importlib.util
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SAMPLER = ROOT / "scripts" / "runtime-diagnostics-sampler.py"

spec = importlib.util.spec_from_file_location("runtime_diagnostics_sampler", SAMPLER)
if spec is None or spec.loader is None:
    raise SystemExit("FAIL: could not load runtime diagnostics sampler")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

memory = module.parse_kib_fields(
    """Rss:                8192 kB
Pss:                4096 kB
Pss_Anon:           2048 kB
Pss_File:           1024 kB
Swap:                512 kB
SwapPss:             256 kB
Ignored:              99 kB
"""
)
assert memory == {
    "Rss": 8192,
    "Pss": 4096,
    "Pss_Anon": 2048,
    "Pss_File": 1024,
    "Swap": 512,
    "SwapPss": 256,
}, memory

drm = module.parse_drm_fdinfo(
    """pos:\t0
flags:\t02400002
drm-client-id:\t7
drm-engine-render:\t400000000 ns
drm-engine-copy:\t100000000 ns
drm-resident-vram0:\t64 MiB
drm-shared-vram0:\t1024 KiB
"""
)
assert drm is not None
assert drm["clientId"] == "7"
assert drm["enginesNs"] == {
    "render": 400_000_000,
    "copy": 100_000_000,
}, drm
assert drm["memoryKiB"]["resident-vram0"] == 64 * 1024, drm
assert drm["memoryKiB"]["shared-vram0"] == 1024, drm

assert module.parse_drm_fdinfo("pos:\t0\nflags:\t0\n") is None
assert module._rate(300, 100, 2.0) == 100.0
assert module._rate(100, 300, 2.0) is None
assert module._rate(100, 100, 0.0) is None

# PID identity uses /proc/<pid>/stat starttime so a recycled PID with the same
# comm cannot create a false CPU spike.
original_read_text = module._read_text
try:
    stat_tail = ["S"] + ["0"] * 18 + ["4242"] + ["0"] * 4
    module._read_text = lambda _path: (
        "123 (worker (nested)) " + " ".join(stat_tail)
    )
    assert module.read_process_start_ticks(123) == 4242
finally:
    module._read_text = original_read_text

# /proc/stat guest counters are already included in user/nice and must not be
# counted twice when deriving total CPU time.
original_read_text = module._read_text
try:
    module._read_text = lambda _path: (
        "cpu 100 0 50 850 0 0 0 0 20 10\n"
        "cpu0 50 0 25 425 0 0 0 0 10 5\n"
    )
    ticks = module.read_system_cpu_ticks()
finally:
    module._read_text = original_read_text
assert ticks["cpu"] == (1000, 850), ticks
assert ticks["cpu0"] == (500, 425), ticks

# Provenance vocabulary is part of the product truth model. Kernel/process
# values must never be confused with attributed or experimental target metrics.
source = SAMPLER.read_text(encoding="utf-8")
for token in (
    '"scope": "system"',
    '"scope": "shell-process"',
    '"confidence": "kernel"',
    '"method": "proc-stat"',
    '"method": "proc-meminfo"',
    '"method": "schedstat"',
    '"method": "smaps-rollup"',
    '"method": "proc-io"',
    '"method": "proc-net-dev"',
    '"method": "drm-fdinfo"',
):
    if token not in source:
        raise AssertionError(f"missing sampler provenance token: {token}")

print("ok - Runtime Diagnostics sampler parsers and provenance")
