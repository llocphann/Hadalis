#!/usr/bin/env python3
"""Static guard and inert parser checks for the explicit nested-Niri probe."""
import ast
from pathlib import Path
import runpy

root = Path(__file__).resolve().parents[1]
script = (root / "scripts/wull-manual-nested-niri.py").read_text()
ast.parse(script)
assert 'background-color "#000000"' in script
assert 'backdrop-color "#000000"' in script
for must in (
    'sys.argv[1:] != ["--acknowledge-nested-niri"]',
    'env.pop("NIRI_SOCKET", None)',
    '"NIRI_CONFIG": str(config)',
    '"WAYLAND_DISPLAY": host_display',
    '"NIRI_SOCKET": nested_ipc',
    'path != host_ipc',
    'start_new_session=True',
    'os.killpg(proc.pid, signal.SIGTERM)',
    'git("merge", "--ff-only", remote)',
    '"native_pointer_passthrough": "not_run"',
    'result["host_output_count_unchanged"]',
    '"host_user_config_read_or_changed": False',
):
    assert must in script, must
namespace = runpy.run_path(
    str(root / "scripts/wull-manual-nested-niri.py"),
    run_name="wull_nested_test_only"
)
parse = namespace["startup_identity"]
sample = (
    "2026-10-01 INFO listening on Wayland socket: wayland-4\n"
    "2026-10-01 INFO IPC listening on: /run/user/1234/niri.wayland-4.42.sock\n"
)
assert parse(sample) == (
    "wayland-4", "/run/user/1234/niri.wayland-4.42.sock"
)
assert parse("unrelated log") == (None, None)
assert not namespace["alive_ipc"]("/tmp/nonexistent-wull-test.sock")
print("WULL_NESTED_NIRI_CONTRACT_PASS")
