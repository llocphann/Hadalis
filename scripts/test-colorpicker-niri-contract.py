#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")

picker = read("scripts/colorpicker.sh")
screencapture = read("sdata/dist-arch/inir-screencapture/PKGBUILD")
tracker = read("sdata/dist-arch/inir-deps/PKGBUILD")
arch_shell = read("distro/arch/inir-shell/PKGBUILD")
arch_shell_git = read("distro/arch/inir-shell-git/PKGBUILD")
arch_meta = read("distro/arch/inir-meta/PKGBUILD")
packages_doc = read("docs/PACKAGES.md")

def require(token: str, message: str) -> None:
    if token not in picker:
        raise SystemExit(f"colorpicker contract failed: {message}")

require("command -v hyprpicker",
        "installed hyprpicker must remain usable on Niri")
require("args=(--format=hex --no-fancy)",
        "hyprpicker output must stay script-safe")
require("args+=(--autocopy)",
        "normal picker requests must preserve clipboard copy")
require("for command_name in grim slurp magick; do",
        "generic picker fallback must remain available without hyprpicker")
require('geometry="$(slurp -p)"',
        "fallback must still select a pixel through slurp")
require('grim -g "$geometry"',
        "fallback must still sample the selected pixel")

for forbidden in ("Quickshell.Hyprland", "CompositorService.isHyprland", "hyprctl"):
    if forbidden in picker:
        raise SystemExit(
            f"colorpicker contract failed: compositor backend returned: {forbidden}"
        )

for source, text in (
    ("inir-screencapture", screencapture),
    ("inir-deps", tracker),
    ("inir-meta", arch_meta),
):
    require(text, "\n  hyprpicker\n",
            f"{source} must retain the preferred picker on full/default Arch installs")

for source, text in (("inir-shell", arch_shell), ("inir-shell-git", arch_shell_git)):
    require(text, "'hyprpicker: enhanced Wayland color picker with magnifier'",
            f"{source} must advertise the optional enhanced picker")

require(packages_doc, "| `hyprpicker` | Preferred Wayland color picker with magnifier",
        "package docs must explain the preferred picker and fallback boundary")

print("colorpicker Niri compatibility contract: ok")
