#!/usr/bin/env python3
"""Inert synthetic tests for the read-only existing-layer Niri observer."""
from pathlib import Path
import runpy

root = Path(__file__).resolve().parents[1]
source = (root / "scripts/wull-manual-existing-layer.py").read_text()
for required in (
    'sys.argv[1:] != ["--observe-current-session"]',
    'niri_json(binary, "outputs")',
    'niri_json(binary, "layers")',
    '"user_configuration": "not_read_or_modified"',
    '"existing_running_shell_source": "unverified"',
    '"pointer_input_mask": "not_observable_via_niri_ipc"',
):
    assert required in source, required
assert "subprocess.Popen(" not in source
assert "os.kill(" not in source
fn = runpy.run_path(str(root / "scripts/wull-manual-existing-layer.py"),
                    run_name="wull_test_only")["evaluate"]
outputs = {
    "DP-1": {"logical": {"width": 1920}},
    "DP-2": {"logical": {"width": 1080}},
    "HDMI-OFF": {"logical": None},
}
def layer(output, keyboard="None", namespace="hadalis:abyss-perimeter"):
    return {"namespace": namespace, "output": output,
            "keyboard_interactivity": keyboard, "layer": "Top"}
expected = fn(outputs, [layer("DP-1"), layer("DP-2", "OnDemand"),
                        layer("DP-1", namespace="unrelated")])
assert expected["active_output_count"] == 2
assert expected["observed_production_layer_count"] == 2
assert expected["outputs_with_exactly_one_layer"] == 2
assert expected["observed_keyboard_mode_counts"]["ondemand"] == 1
duplicate = fn(outputs, [layer("DP-1"), layer("DP-1"), layer("DP-2")])
assert duplicate["outputs_with_duplicate_layers"] == 1
missing = fn(outputs, [layer("DP-1")])
assert missing["outputs_missing_layer"] == 1
orphan = fn(outputs, [layer("DP-1"), layer("DP-2"),
                       layer("HDMI-OFF")])
assert orphan["layers_on_unrecognized_or_inactive_outputs"] == 1
focus = fn(outputs, [layer("DP-1", "Exclusive"), layer("DP-2", "Unknown")])
assert focus["observed_keyboard_mode_counts"]["exclusive"] == 1
assert focus["observed_keyboard_mode_counts"]["unknown"] == 1
print("WULL_EXISTING_LAYER_CONTRACT_PASS")
