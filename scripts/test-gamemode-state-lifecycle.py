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

    # A fullscreen-sized window that remains on an active workspace after focus
    # moves away must not keep the Bar or GameMode hidden. Niri reports the
    # actually presented window through workspace.active_window_id.
    for token, message in (
        ("function isWindowPresentedOnActiveWorkspace(window, workspace): bool",
         "GameMode must centralize active-workspace presentation checks"),
        ("const activeWindowId = workspace.active_window_id",
         "fullscreen presentation must follow workspace.active_window_id"),
        ("return window.id === activeWindowId",
         "background fullscreen windows must not count as presented"),
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
