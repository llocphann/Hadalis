#!/usr/bin/env python3
"""Regression contract for unified media controls, CAVA and sidebar edge reveal."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def require(source: str, token: str, message: str) -> None:
    if token not in source:
        raise SystemExit(message)


def forbid(source: str, token: str, message: str) -> None:
    if token in source:
        raise SystemExit(message)


sidebar = read("modules/sidebar/SidebarHost.qml")
mpris = read("services/MprisController.qml")
local_service = read("services/LocalMusic.qml")
local_view = read("modules/sidebarLeft/LocalMusicView.qml")
player = read("modules/mediaControls/PlayerControl.qml")
compact = read("modules/sidebarRight/CompactMediaPlayer.qml")
dash = read("modules/dashboard/DashMedia.qml")
control_panel = read("modules/controlPanel/MediaSection.qml")
left_widget = read("modules/sidebarLeft/widgets/MediaPlayerWidget.qml")

for token in (
    "readonly property int screenEdgeHoverWidth:",
    "Config.options?.appearance?.screenEdge?.width ?? 10",
    "readonly property int edgeOpenWidth: Math.max(",
    "screenEdgeHoverWidth,",
):
    require(sidebar, token, f"Sidebar Screen Edge hover contract missing: {token}")

for token in (
    "function loopSupportedForPlayer(player): bool",
    "function cycleLoopForPlayer(player): bool",
    "function shuffleSupportedForPlayer(player): bool",
    "function toggleShuffleForPlayer(player): bool",
):
    require(mpris, token, f"Player-scoped media option contract missing: {token}")

for token in (
    "property var playbackAdapter: null",
    "readonly property bool effectiveShuffleSupported:",
    "readonly property bool effectiveRepeatSupported:",
    'text: "shuffle"',
    'text: root.effectiveRepeatOne ? "repeat_one" : "repeat"',
    "WaveVisualizer {",
):
    require(player, token, f"PlayerControl unified media contract missing: {token}")

for token in (
    "property int resumeIndex: -1",
    'if (!playing && mpdState === "stop")',
    '_sendMpd("play", [index])',
    'function stop(): void {',
):
    require(local_service, token, f"LocalMusic stop/resume contract missing: {token}")

for token in (
    "id: localMusicPlayerAdapter",
    "playbackAdapter: localMusicPlayerAdapter",
    "visible: LocalMusic.hasCurrentTrack",
    "active: root.visible && LocalMusic.playing",
    'tip: Translation.tr("Play selection")',
    'tip: Translation.tr("Add to queue")',
    "configuration: StyledSlider.Configuration.XS",
    "Layout.preferredWidth: 100",
):
    require(local_view, token, f"LocalMusic UI recovery contract missing: {token}")
forbid(
    local_view,
    'symbol: LocalMusic.shuffleMode ? "shuffle_on" : "shuffle"',
    "LocalMusic must not duplicate Shuffle below PlayerControl.",
)
forbid(
    local_view,
    "symbol: LocalMusic.repeatMode === 1",
    "LocalMusic must not duplicate Repeat below PlayerControl.",
)

for source, name, lifecycle in (
    (compact, "Compact right sidebar", "GlobalStates.sidebarRightOpen"),
    (dash, "Dashboard", "root.presentationActive"),
):
    require(source, "CavaProcess {", f"{name} must own a lifecycle-gated CAVA subscription.")
    require(source, "WaveVisualizer {", f"{name} must render CAVA in its media surface.")
    require(source, lifecycle, f"{name} CAVA must follow its presentation lifecycle.")

for source, name in (
    (dash, "Dashboard"),
    (control_panel, "Control Panel"),
    (left_widget, "Left Sidebar widget"),
):
    require(source, "toggleShuffleForPlayer", f"{name} media must expose Shuffle.")
    require(source, "cycleLoopForPlayer", f"{name} media must expose Repeat.")

print("Unified media controls/CAVA + sidebar edge reveal contract: OK")
