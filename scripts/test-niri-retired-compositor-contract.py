#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def require(text: str, token: str, message: str) -> None:
    if token not in text:
        raise SystemExit(f"niri compositor retirement contract failed: {message}")


def forbid(text: str, token: str, message: str) -> None:
    if token in text:
        raise SystemExit(f"niri compositor retirement contract failed: {message}")


def main() -> None:
    retired_paths = (
        "services/HyprlandData.qml",
        "services/deferred/HyprlandXkb.qml",
        "services/deferred/HyprlandKeybinds.qml",
        "services/Hyprsunset.qml",
        "modules/overview/OverviewWidget.qml",
        "modules/sidebar/SidebarEdgeConnectors.qml",
        "modules/bar/HyprlandXkbIndicator.qml",
    )
    for rel in retired_paths:
        if (ROOT / rel).exists():
            raise SystemExit(
                f"niri compositor retirement contract failed: retired runtime returned: {rel}"
            )

    forbidden_qml_tokens = (
        "import Quickshell.Hyprland",
        "CompositorService.isHyprland",
        "HyprlandData",
        "HyprlandXkb",
        "HyprlandKeybinds",
        "Hyprsunset",
        "HyprlandXkbIndicator",
        "OverviewWidget",
        "SidebarEdgeConnectors",
        "hyprctl",
    )
    for base in (ROOT / "modules", ROOT / "services"):
        for path in base.rglob("*.qml"):
            source = path.read_text(encoding="utf-8")
            for token in forbidden_qml_tokens:
                if token in source:
                    rel = path.relative_to(ROOT)
                    raise SystemExit(
                        "niri compositor retirement contract failed: "
                        f"{rel} retains retired compositor token {token!r}"
                    )

    bar_status = read("modules/bar/BarStatusIndicators.qml")
    bar_qmldir = read("modules/bar/qmldir")
    require(
        bar_status,
        "KeyboardStatusIndicator {",
        "Bar keyboard state must use the Niri-compatible replacement indicator",
    )
    require(
        bar_qmldir,
        "KeyboardStatusIndicator 1.0 KeyboardStatusIndicator.qml",
        "replacement keyboard indicator must remain registered",
    )

    night_light = read("services/NightLight.qml")
    require(
        night_light,
        '"/usr/bin/wlsunset"',
        "Night Light must retain its Niri backend",
    )

    widget_sdk = read("defaults/widgets/WIDGET-SDK.md")
    forbid(
        widget_sdk,
        "CompositorService.isHyprland",
        "widget SDK must not advertise the retired Hyprland capability flag",
    )

    color_picker = read("scripts/colorpicker.sh")
    for token in ("slurp -p", 'grim -g "$geometry"', "magick ppm:-"):
        require(
            color_picker,
            token,
            f"color picker Niri replacement is incomplete: {token}",
        )

    region_finder = read("scripts/images/find_regions.py")
    forbid(
        region_finder,
        "--hyprctl",
        "content-region detector must not expose retired Hyprland-shaped CLI mode",
    )
    require(
        region_finder,
        '"at": [r[',
        "content-region detector must emit region positions through the {at,size} contract",
    )
    require(
        region_finder,
        '"size": [r[',
        "content-region detector must emit region dimensions through the {at,size} contract",
    )

    ipc = read("scripts/lib/ipc-registry.sh")
    ipc_contracts = (
        '[controlPanel]="toggle close open"',
        '[osk]="toggle close open"',
        '[overlay]="toggle"',
        '[session]="toggle close open"',
        '[cheatsheet]="toggle close open"',
        '[mediaControls]="toggle close open"',
        '[sidebarLeft]="toggle close open expand compact status detach attach"',
        '[sidebarRight]="toggle close open"',
        '[dashboard]="toggle close open"',
        '[osdVolume]="trigger hide toggle"',
        '[wallpaperSelector]="toggle open close openLauncher toggleOnMonitor random status"',
        '[coverflowSelector]="toggle open close"',
        '[overview]="toggle close open toggleReleaseInterrupt superPress superRelease clipboardToggle actionOpen"',
    )
    for token in ipc_contracts:
        require(ipc, token, f"removed GlobalShortcut lost IPC replacement: {token}")

    binds = read("defaults/niri/config.d/70-binds.kdl")
    for token in (
        'Super+G { spawn "inir" "overlay" "toggle"; }',
        'Mod+Space repeat=false { spawn "inir" "overview" "toggle"; }',
        'Ctrl+Alt+T { spawn "inir" "wallpaperSelector" "toggle"; }',
        'Mod+Slash { spawn "inir" "cheatsheet" "toggle"; }',
        'Mod+Shift+Q { spawn "inir" "session" "toggle"; }',
    ):
        require(binds, token, f"default Niri bind lost shell replacement: {token}")

    daemon = read("scripts/daemon/inir_super_overview_daemon.py")
    for token in (
        "super_down_devices = set()",
        "notify_shell_super_state(True)",
        "notify_shell_super_state(False)",
        'run_inir_command("ipc", "overview", function)',
    ):
        require(daemon, token, f"Super hold bridge is incomplete: {token}")

    shell = read("shell.qml")
    require(shell, "function superPress(): void {", "shell IPC lost Super press")
    require(shell, "GlobalStates.superDown = true", "Super press must set shared state")
    require(shell, "function superRelease(): void {", "shell IPC lost Super release")
    require(shell, "GlobalStates.superDown = false", "Super release must clear shared state")

    lock = read("modules/lock/Lock.qml")
    require(
        lock,
        "command -v swaylock",
        "Niri external lock fallback must retain swaylock",
    )
    # hyprlock is intentionally allowed here: it is an ext-session-lock client
    # that works on Niri, not a restored Hyprland compositor backend.
    forbid(
        lock,
        "Quickshell.Hyprland",
        "lock fallback must not restore compositor-specific integration",
    )
    forbid(
        lock,
        "hyprctl",
        "lock fallback must not restore compositor-specific commands",
    )

    print("niri compositor retirement contract: ok")


if __name__ == "__main__":
    main()
