#!/usr/bin/env python3
"""Inert safety and /proc parsing tests for private Wull idle measurement."""
import ast
from pathlib import Path
import runpy

root = Path(__file__).resolve().parents[1]
path = root / "scripts/wull-manual-idle-resource.py"
source = path.read_text()
ast.parse(source)
for required in (
    'sys.argv[1:] != ["--acknowledge-idle-measurement"]',
    '"CARGO_TARGET_DIR"] = str(private / "cargo-target")',
    '"native/Cargo.toml"', '"inir-companiond"',
    'proc.stdin.write(b\'{"v":1,"seq":1,"type":"event","event":"show"}',
    'proc.stdin.write(b\'{"v":1,"seq":2,"type":"event","event":"hide"}',
    'result["sample_count"] = len(samples)',
    'result["unrequested_hidden_stdout_reads"] = unsolicited',
    'result["rss_growth_kib"] <= 4096',
    'result["idle_cpu_seconds"] <= 0.5',
    '"production_qml_cpu_memory": "not_measured"',
    '"live_visual_and_input_acceptance": "not_run"',
    'private.mkdir(mode=0o700',
    'os.killpg(proc.pid, signal.SIGTERM)',
):
    assert required in source, required
fn = runpy.run_path(str(path), run_name="wull_idle_test_only")["parse_ticks"]
assert fn("123 (companion) " + " ".join(
    ["S"] + ["0"] * 10 + ["18", "7", "0"]
)) == 25
assert fn("123 (space ) daemon) " + " ".join(
    ["S"] + ["0"] * 10 + ["18", "7", "0"]
)) == 25
try:
    fn("bad input")
except ValueError:
    pass
else:
    raise AssertionError("invalid proc stat must fail closed")
print("WULL_IDLE_RESOURCE_CONTRACT_PASS")
