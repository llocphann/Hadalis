#!/usr/bin/env python3
"""Regression contract for centralized GameMode state directory ownership."""

from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
GAME = ROOT / "services/GameMode.qml"
DIRECTORIES = ROOT / "modules/common/Directories.qml"


def main() -> int:
    game = GAME.read_text(encoding="utf-8")
    directories = DIRECTORIES.read_text(encoding="utf-8")

    if 'readonly property string _stateFile: Directories.stateUserPath + "/gamemode_active"' not in game:
        raise AssertionError("GameMode must use the canonical XDG-aware stateUserPath")
    if 'Quickshell.env("HOME") + "/.local/state/quickshell/user/gamemode_active"' in game:
        raise AssertionError("GameMode must not restore a hard-coded HOME state path")

    completed = re.search(
        r"Component\.onCompleted: \{(?P<body>.*?)\n    \}\n\n    Timer \{\n        id: initTimer",
        game,
        flags=re.S,
    )
    if not completed:
        raise AssertionError("could not isolate GameMode startup block")
    if "execDetached" in completed.group("body"):
        raise AssertionError("GameMode startup must not spawn its own state-directory helper")

    if 'root.stateUserPath,' not in directories:
        raise AssertionError("Directories must continue preparing stateUserPath centrally")

    # Manual writes retain a defensive mkdir fallback for runtime deletion or
    # directory-preparation failure; only the unconditional startup spawn is retired.
    # Paths travel as positional arguments so XDG_STATE_HOME may safely contain spaces.
    if '"mkdir -p -- \\\"$1\\\" && printf' not in game:
        raise AssertionError("GameMode state writes must retain directory self-healing")
    if '"_",\n            Directories.stateUserPath,' not in game:
        raise AssertionError("GameMode state writes must pass stateUserPath as an argument")
    if 'root._stateFile\n        ]' not in game:
        raise AssertionError("GameMode state writes must pass the state file as an argument")

    # Fullscreen detection must follow the visual tile/backdrop size. A fixed-size
    # client can remain smaller than the compositor-owned fullscreen backdrop, so
    # window_size alone is not an authoritative fullscreen signal.
    for token, message in (
        ("const tileSize = window.layout?.tile_size",
         "GameMode must inspect niri's visual tile size for fullscreen"),
        ("const fullscreenSize = tileSize && tileSize.length >= 2 ? tileSize : windowSize",
         "GameMode must prefer tile_size while retaining the compatibility fallback"),
        ("Math.abs(fullscreenSize[0] - output.logical.width)",
         "fullscreen width detection must use the visual fullscreen size"),
        ("Math.abs(fullscreenSize[1] - output.logical.height)",
         "fullscreen height detection must use the visual fullscreen size"),
    ):
        if token not in game:
            raise AssertionError(message)

    # A fullscreen-sized window that remains on an active workspace after focus
    # moves away must not keep the Bar or GameMode hidden. Niri reports the
    # actually presented window through workspace.active_window_id.
    for token, message in (
        ("function isWindowPresentedOnActiveWorkspace(window, workspace): bool",
         "GameMode must centralize active-workspace presentation checks"),
        ("const activeWindowId = workspace.active_window_id",
         "fullscreen presentation must follow workspace.active_window_id"),
        ("return activeWindowId !== null && window.id === activeWindowId",
         "background or explicitly unfocused fullscreen windows must not count as presented"),
        ("return window.is_focused === true",
         "GameMode needs a startup fallback before active_window_id arrives"),
        ("if (isWindowPresentedOnActiveWorkspace(window, ws)) return true",
         "visible fullscreen detection must ignore background windows"),
        ("if (!isWindowPresentedOnActiveWorkspace(w, ws)) continue",
         "per-output fullscreen gating must ignore background windows"),
        ("function onWorkspacesChanged()",
         "workspace activation must trigger a fullscreen-state refresh"),
    ):
        if token not in game:
            raise AssertionError(message)

    print("gamemode state lifecycle contract: ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
