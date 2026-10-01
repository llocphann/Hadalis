#!/usr/bin/env python3
"""Inert real-stdio relay smoke using a deterministic private FAKE backend.

Only this test uses a fake backend. The eventual nested production pointer
runner must use an exact-source, privately built REAL inir-companiond.
No compositor, pointer injection, or live desktop is used by this contract.
"""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
RELAY = ROOT / "scripts/wull-fixtures/pointer-underlay/companion-relay.py"
source = RELAY.read_text()
for required in (
    'WULL_PRIVATE_POINTER_SESSION',
    'isolated-nested-only',
    'nested_wayland_or_niri_identity_unproven',
    'private_pointer_trace_inside_checkout',
    'subprocess.Popen(',
    'stdin=subprocess.PIPE',
    'stdout=subprocess.PIPE',
    'real_bridge_click_received',
    'rust_happy_pulse_ack',
    'child.terminate()',
):
    assert required in source, required

with tempfile.TemporaryDirectory(prefix="wull-private-relay-contract-") as name:
    folder = Path(name)
    fake = folder / "fake_companion.py"
    fake.write_text(
        "#!/usr/bin/env python3\n"
        "import json,sys\n"
        "print(json.dumps({'v':1,'seq':1,'type':'state',"
        "'visibility':'hidden','mood':'calm','pulse':0}),flush=True)\n"
        "for line in sys.stdin:\n"
        " obj=json.loads(line)\n"
        " if obj.get('event')=='click':\n"
        "  print(json.dumps({'v':1,'seq':2,'type':'state',"
        "'visibility':'present','mood':'happy','pulse':0.8}),flush=True)\n",
        encoding="utf-8"
    )
    fake.chmod(0o700)
    trace = folder / "relay.private.jsonl"
    env = dict(os.environ)
    env.update({
        "WULL_PRIVATE_POINTER_SESSION": "isolated-nested-only",
        "WULL_PARENT_WAYLAND_DISPLAY": "wayland-parent",
        "WULL_PARENT_NIRI_SOCKET": "/tmp/wull-test-parent-ipc",
        "WAYLAND_DISPLAY": "wayland-nested",
        "NIRI_SOCKET": "/tmp/wull-test-nested-ipc",
        "WULL_PRIVATE_POINTER_BINARY": str(fake),
        "WULL_PRIVATE_POINTER_TRACE": str(trace),
        "WULL_PRIVATE_POINTER_CHECKOUT": str(ROOT),
    })
    event = b'{"v":1,"seq":1,"type":"event","event":"click"}\n'
    executed = subprocess.run(
        [sys.executable, str(RELAY)], input=event,
        capture_output=True, env=env, timeout=8
    )
    assert executed.returncode == 0, executed.stderr.decode(errors="replace")
    messages = [json.loads(line) for line in executed.stdout.splitlines()]
    assert len(messages) == 2
    assert messages[0]["type"] == "state"
    assert messages[1]["mood"] == "happy"
    assert messages[1]["pulse"] == .8
    private = [json.loads(line) for line in trace.read_text().splitlines()]
    kinds = [entry["kind"] for entry in private]
    assert kinds.count("real_bridge_click_received") == 1, kinds
    assert kinds.count("rust_happy_pulse_ack") == 1, kinds
    assert kinds.count("rust_present") == 1, kinds
    assert all("when_monotonic" in entry for entry in private)
    env["WULL_PRIVATE_POINTER_TRACE"] = str(folder / "rejected.jsonl")
    env["WAYLAND_DISPLAY"] = env["WULL_PARENT_WAYLAND_DISPLAY"]
    refused = subprocess.run(
        [sys.executable, str(RELAY)], input=event,
        capture_output=True, env=env, timeout=4
    )
    assert refused.returncode != 0
    assert b"nested_wayland_or_niri_identity_unproven" in refused.stderr
    assert not (folder / "rejected.jsonl").exists()
    env["WAYLAND_DISPLAY"] = "wayland-nested"
    env["WULL_PRIVATE_POINTER_CHECKOUT"] = ""
    missing_checkout = subprocess.run(
        [sys.executable, str(RELAY)], input=event,
        capture_output=True, env=env, timeout=4
    )
    assert missing_checkout.returncode != 0
    assert b"private_checkout_identity_unavailable" in missing_checkout.stderr
    assert not (folder / "rejected.jsonl").exists()
print("WULL_PRIVATE_RELAY_INERT_CONTRACT_PASS")
