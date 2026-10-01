#!/usr/bin/env python3
"""Static safety and provenance contract for the opt-in production layer probe."""
import ast
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
runner = (ROOT / "scripts/wull-manual-production-layer.py").read_text()
fixture = (ROOT / "scripts/wull-fixtures/production-layer/shell.qml").read_text()
ast.parse(runner)
for marker in (
    'sys.argv[1:] != ["--acknowledge-temporary-layer"]',
    'preflight_reason = "abyss_perimeter_already_running"',
    '"INIR_COMPANIOND": str(binary)',
    '"XDG_CONFIG_HOME": str(xdg / "config")',
    'env["CARGO_TARGET_DIR"] = str(private / "cargo-target")',
    '"enabledPanels"] = []',
    'shutil.copyfile(FIXTURE, shell / "shell.qml")',
    'os.killpg(proc.pid, signal.SIGTERM)',
    '"native_input_passthrough_acceptance": "not_run"',
    '"canonical_validation": "not_run"',
    "Private state directory must be outside the repo",
):
    assert marker in runner, marker
assert 'AbyssPerimeter { }' in fixture
assert 'WULL_PRODUCTION_FIXTURE_READY' in fixture
assert '"wullProof.qml"' not in runner
print("WULL_PRODUCTION_LAYER_CONTRACT_PASS")
