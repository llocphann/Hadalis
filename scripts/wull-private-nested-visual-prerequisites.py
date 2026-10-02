#!/usr/bin/env python3
"""Read-only prerequisite inventory for NEXT opt-in isolated Niri visual gate.

Does not launch compositor, screenshot, Rust, Qt, pointer, or Git commands.
Names/paths of the current host compositor are never printed.
"""
import os
from pathlib import Path
import shutil
import stat

REQUIRED_BINARIES = ("niri", "qs_or_quickshell", "dbus-run-session",
                     "cargo", "grim")


def prerequisites(lookup, env, is_socket):
    status = {}
    for key in REQUIRED_BINARIES:
        if key == "qs_or_quickshell":
            status[key] = bool(lookup("qs") or lookup("quickshell"))
        else:
            status[key] = bool(lookup(key))
    runtime = env.get("XDG_RUNTIME_DIR", "")
    display = env.get("WAYLAND_DISPLAY", "")
    niri = env.get("NIRI_SOCKET", "")
    # Never perform a screenshot before a second, independent NESTED
    # endpoint identity has been proved by a future dedicated coordinator.
    status["host_wayland_socket"] = bool(
        runtime and display and "/" not in display and
        display != "." and display != ".." and
        is_socket(str(Path(runtime) / display)))
    status["host_niri_ipc_socket"] = bool(niri and
                                          Path(niri).is_absolute() and
                                          is_socket(niri))
    status["capture_phase_ready"] = all(status.values())
    return status


def real_socket(path):
    try:
        return stat.S_ISSOCK(Path(path).stat().st_mode)
    except (OSError, ValueError):
        return False


def main():
    status = prerequisites(shutil.which, os.environ, real_socket)
    for key in REQUIRED_BINARIES:
        print("VISUAL_PREREQ_" + key.upper().replace("-", "_") +
              "=" + ("YES" if status[key] else "NO"))
    print("VISUAL_PREREQ_HOST_WAYLAND_SOCKET=" +
          ("YES" if status["host_wayland_socket"] else "NO"))
    print("VISUAL_PREREQ_HOST_NIRI_IPC_SOCKET=" +
          ("YES" if status["host_niri_ipc_socket"] else "NO"))
    print("NESTED_COMPOSITOR_STARTED=NO")
    print("SCREENSHOT_ATTEMPTED=NO")
    print("LIVE_PANEL_VISUAL_ACCEPTANCE=NOT_TESTED")
    print("NESTED_VISUAL_PREREQUISITES=" +
          ("READY_FOR_SEPARATE_REVIEW" if status["capture_phase_ready"]
           else "MISSING_OR_UNVERIFIED"))


if __name__ == "__main__":
    main()
