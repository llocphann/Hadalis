#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
picker = (ROOT / "scripts/colorpicker.sh").read_text(encoding="utf-8")

def require(token: str, message: str) -> None:
    if token not in picker:
        raise SystemExit(f"colorpicker contract failed: {message}")

require("for command_name in grim slurp magick; do",
        "generic picker fallback must remain available without hyprpicker")
require('geometry="$(slurp -p)"',
        "fallback must still select a pixel through slurp")
require('grim -g "$geometry"',
        "fallback must still sample the selected pixel")

for forbidden in ("Quickshell.Hyprland", "CompositorService.isHyprland", "hyprctl", "hyprpicker"):
    if forbidden in picker:
        raise SystemExit(
            f"colorpicker contract failed: compositor backend returned: {forbidden}"
        )

print("colorpicker Niri compatibility contract: ok")
