#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LOCK = (ROOT / "modules/lock/Lock.qml").read_text(encoding="utf-8")

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
