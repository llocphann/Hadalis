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
nix_package = read("nix/package.nix")
debian_installer = read("sdata/dist-debian/install-deps.sh")
fedora_installer = read("sdata/dist-fedora/install-deps.sh")

def require(text: str, token: str, message: str) -> None:
    if token not in text:
        raise SystemExit(f"colorpicker contract failed: {message}")

require(picker, "command -v hyprpicker",
        "installed hyprpicker must remain usable on Niri")
require(picker, "args=(--format=hex --no-fancy)",
        "hyprpicker output must stay script-safe")
require(picker, "args+=(--autocopy)",
        "normal picker requests must preserve clipboard copy")
require(picker, "for command_name in grim slurp magick; do",
        "generic picker fallback must remain available without hyprpicker")
require(picker, 'geometry="$(slurp -p)"',
        "fallback must still select a pixel through slurp")
require(picker, 'grim -g "$geometry"',
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
    require(text, "\n  imagemagick\n",
            f"{source} must ship the generic color-picker backend")
    require(text, "'hyprpicker: enhanced Wayland color picker with magnifier'",
            f"{source} must advertise the optional enhanced picker")
    if "'imagemagick: image conversion helpers'" in text:
        raise SystemExit(
            f"colorpicker contract failed: {source} must not leave the required fallback backend optional"
        )

require(packages_doc, "| `hyprpicker` | Preferred Wayland color picker with magnifier",
        "package docs must explain the preferred picker and fallback boundary")

require(nix_package, '++ optionalTop "hyprpicker"',
        "Nix runtime must retain the preferred picker when nixpkgs provides it")
require(fedora_installer, '[hyprpicker]="hyprpicker"',
        "Fedora missing-dependency repair must know the preferred picker package")
require(fedora_installer, "FEDORA_SCREENCAPTURE_PKGS=(\n  grim\n  slurp\n  hyprpicker",
        "Fedora default screen-capture install must include the preferred picker")
require(debian_installer, "DEBIAN_SCREENCAPTURE_PKGS+=(hyprpicker)",
        "Debian must install the preferred picker when the distro package exists")
require(debian_installer, "https://github.com/hyprwm/hyprpicker.git",
        "Debian must retain a best-effort source path when no package exists")

require(debian_installer, 'HYPRPICKER_BUILD_DIR="/tmp/hyprpicker-build-${BASHPID}"',
        "Debian hyprpicker source builds must use a per-process temporary directory")
require(debian_installer, 'HYPRUTILS_BUILD_DIR="/tmp/hyprutils-build-${BASHPID}"',
        "Debian hyprutils source builds must use a per-process temporary directory")

print("colorpicker Niri compatibility contract: ok")
