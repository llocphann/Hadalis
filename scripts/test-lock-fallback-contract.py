#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LOCK = (ROOT / "modules/lock/Lock.qml").read_text(encoding="utf-8")
NIX_PACKAGE = (ROOT / "nix/package.nix").read_text(encoding="utf-8")
ARCH_PACKAGE = (ROOT / "distro/arch/inir-shell/PKGBUILD").read_text(encoding="utf-8")
ARCH_GIT_PACKAGE = (ROOT / "distro/arch/inir-shell-git/PKGBUILD").read_text(encoding="utf-8")

def require(token: str, message: str) -> None:
    if token not in LOCK:
        raise SystemExit(f"lock fallback contract failed: {message}")

require("function useFallbackLock(): void", "fallback function is missing")
require("command -v swaylock >/dev/null 2>&1 && exec swaylock -f -c 1a1a2e",
        "swaylock must remain the first external fallback")
require("command -v hyprlock >/dev/null 2>&1 && exec hyprlock",
        "hyprlock must remain a valid secondary Niri-compatible fallback")
require("Install swaylock or hyprlock as fallback",
        "fallback failure message must describe both supported external lockers")

if '++ optionalTop "swaylock"' not in NIX_PACKAGE:
    raise SystemExit(
        "lock fallback contract failed: Nix runtime must ship swaylock for clean installs"
    )
for source, package in (
    ("inir-shell", ARCH_PACKAGE),
    ("inir-shell-git", ARCH_GIT_PACKAGE),
):
    if "  swaylock" not in package:
        raise SystemExit(
            f"lock fallback contract failed: {source} must ship swaylock for clean installs"
        )

for forbidden in (
    "Quickshell.Hyprland",
    "CompositorService.isHyprland",
    "hyprctl",
):
    if forbidden in LOCK:
        raise SystemExit(
            f"lock fallback contract failed: compositor backend residue returned: {forbidden}"
        )

print("lock fallback contract: ok")
