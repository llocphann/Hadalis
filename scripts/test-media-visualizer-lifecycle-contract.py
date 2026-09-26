#!/usr/bin/env python3
"""Regression contract for media visualizer and EQ CAVA ownership."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
failures: list[str] = []


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def check(condition: bool, message: str) -> None:
    if not condition:
        failures.append(message)


def main() -> None:
    popup = read("modules/mediaControls/BarMediaPopup.qml")
    equalizer = read("modules/mediaControls/EqualizerPanel.qml")
    player = read("modules/mediaControls/PlayerControl.qml")
    bar_player = read("modules/mediaControls/BarMediaPlayerItem.qml")
    lock_player = read("modules/lock/LockMediaWidget.qml")
    dash = read("modules/dashboard/DashMedia.qml")
    compact = read("modules/sidebarRight/CompactMediaPlayer.qml")
    cava = read("modules/common/widgets/CavaProcess.qml")
    cava_service = read("services/deferred/CavaService.qml")
    cava_config = read("scripts/cava/generate_config.sh")
    wave = read("modules/common/widgets/WaveVisualizer.qml")
    desktop_widget = read("modules/background/widgets/mediaControls/MediaControlsWidget.qml")
    preset_paths = [
        "modules/mediaControls/presets/FullPlayer.qml",
        "modules/mediaControls/presets/LyricsPlayer.qml",
        "modules/mediaControls/presets/CompactPlayer.qml",
        "modules/mediaControls/presets/MinimalPlayer.qml",
        "modules/mediaControls/presets/ClassicPlayer.qml",
        "modules/mediaControls/presets/AlbumArtPlayer.qml",
        "modules/mediaControls/presets/VisualizerPlayer.qml",
        "modules/mediaControls/presets/LyricsSplitPlayer.qml",
        "modules/mediaControls/presets/ExpandingLyricsPlayer.qml",
    ]

    check(
        "readonly property bool presentationActive: root.QsWindow.window?.visible ?? false" in popup,
        "Bar media DSP lifecycle must be gated by the actual presentation window",
    )
    check(
        "CavaProcess {" not in popup
        and "id: cavaProcess" not in popup
        and "visualizerActive" not in popup,
        "BarMediaPopup must not keep a second decorative CAVA consumer above EQ DSP",
    )
    check(
        "visualizerPoints: []" in popup
        and "showVisualizer: false" in popup,
        "BarMediaPopup must suppress PlayerControl's decorative wave while EQ DSP owns CAVA",
    )
    check(
        "CavaProcess {" not in dash
        and "WaveVisualizer {" not in dash
        and "visualizerPoints: []" in dash
        and "showVisualizer: false" in dash,
        "Dashboard Media must leave live CAVA visualization to EqualizerPanel only",
    )
    check(
        "CavaProcess {" not in compact
        and "WaveVisualizer {" not in compact
        and "compactMediaCava" not in compact,
        "Compact right Sidebar Media must not run or render duplicate CAVA",
    )
    check(
        "CavaProcess {" in equalizer
        and "id: eqCava" in equalizer
        and "active: root.active" in equalizer
        and "sampleCount: 64" in equalizer,
        "EqualizerPanel must subscribe to the shared CAVA service while presented",
    )
    check(
        "const spectrum = eqCava.points ?? []" in equalizer
        and "Number(eqCava.normalizationCeiling)" in equalizer
        and "model: EqualizerService.dspBands" in equalizer
        and "property real eqLightningHighlight: 0.0" in equalizer
        and "property real eqPresetSweepProgress: -0.12" in equalizer
        and "function strokeSampledTrace(stroke, capture)" in equalizer
        and "const sweepTail = 0.22" in equalizer,
        "EqualizerPanel must merge live CAVA bars with the electric DSP response connector",
    )
    check(
        equalizer.count("Slider {") == 1
        and "id: lightningCanvas" not in equalizer
        and "ctx.bezierCurveTo(" not in equalizer,
        "EqualizerPanel must keep one integrated DSP node layer and no detached/smooth connector",
    )
    check(
        'text: "Live"' in equalizer
        and "RowLayout {" in equalizer
        and "Layout.alignment: Qt.AlignVCenter" in equalizer
        and "verticalAlignment: Text.AlignVCenter" in equalizer,
        "EqualizerPanel Live badge dot and label must share one vertical centerline",
    )
    check(
        "_playerCache" not in popup
        and "cacheInvalidateTimer" not in popup
        and "if (root.activePlayer && !result.includes(root.activePlayer))" in popup,
        "BarMediaPopup must render only live MPRIS objects and must not retain destroyed-player cache entries",
    )
    media_controls = read("modules/mediaControls/MediaControls.qml")
    check(
        "cavaProcess.normalizationCeiling" in media_controls
        and "visualizerMaxValue: root.visualizerMaxValue" in media_controls,
        "Global MediaControls must share the adaptive CAVA normalization contract",
    )
    check(
        "WaveVisualizer {" in player
        and "points: root.visualizerPoints" in player
        and "property bool showVisualizer: true" in player
        and "visible: root.showVisualizer" in player
        and "live: root.showVisualizer && root.effectiveIsPlaying" in player,
        "PlayerControl must preserve the optional CAVA -> WaveVisualizer route for non-EQ owners",
    )
    check(
        "readonly property bool presentationActive: root.visible" in player
        and "root.QsWindow.window?.visible ?? false" in player
        and "running: root.presentationActive" in player
        and "triggeredOnStart: true" in player,
        "PlayerControl position polling must sleep with its presentation window and prime on reopen",
    )
    check(
        "readonly property bool presentationActive: root.visible" in bar_player
        and "root.QsWindow.window?.visible ?? false" in bar_player
        and "running: root.presentationActive" in bar_player
        and "triggeredOnStart: true" in bar_player,
        "BarMediaPlayerItem position polling must sleep while not presented",
    )
    check(
        "readonly property bool presentationActive: GlobalStates.screenLocked" in lock_player
        and "root.QsWindow.window?.visible ?? false" in lock_player
        and "active: root.presentationActive && root.hasPlayer" in lock_player
        and "running: root.presentationActive" in lock_player
        and "triggeredOnStart: true" in lock_player,
        "Lock media CAVA and position polling must sleep outside the presented lock screen",
    )
    check(
        "maxVisualizerValue: Math.max(1, root.visualizerMaxValue)" in player
        and "maxVisualizerValue: 1000" not in player,
        "PlayerControl must scale the wave against the adaptive signal ceiling instead of a fixed 1000",
    )
    check(
        "item.positionUpdatesActive = Qt.binding(() =>" in desktop_widget
        and "root.visible && root.powerActive" in desktop_widget,
        "Desktop media widget must gate preset position polling by its power lifecycle",
    )
    for preset_path in preset_paths:
        preset = read(preset_path)
        check(
            "property bool positionUpdatesActive: true" in preset
            and "positionUpdatesActive: root.positionUpdatesActive" in preset,
            f"{preset_path} must forward explicit position update lifecycle to PlayerBase",
        )
    check(
        "Repeater {" in wave
        and "processedBars" in wave
        and "distFromCenter" in wave
        and "edgeFactor" in wave,
        "WaveVisualizer must render the Serpantinum-inspired equalizer bar field",
    )
    check(
        "Canvas {" not in wave and "layer.effect" not in wave,
        "Media equalizer must not depend on Canvas/layer-effect rendering",
    )
    check(
        "ServiceLease {" in cava
        and "acquire: count => CavaService.subscribe(count)" in cava,
        "CavaProcess must acquire its shared subscription through ServiceLease",
    )
    check(
        "release: token => CavaService.unsubscribe(token)" in cava
        and "update: (token, count) =>" in cava,
        "CavaProcess must release and resize the exact held subscription",
    )
    check(
        "id: dataWatchdog" in cava_service
        and "configRestart.restart()" in cava_service
        and "dataWatchdog.restart()" in cava_service,
        "Shared CAVA service must recover when a running source stops emitting valid frames",
    )
    check(
        "ascii_max_range = 1000" in cava_config
        and "bar_delimiter = 59" in cava_config,
        "Generated raw CAVA config must pin the same ASCII range/delimiter contract as the visualizer parser",
    )

    if failures:
        print("Media visualizer lifecycle contract regression(s):")
        for failure in failures:
            print(f"  - {failure}")
        raise SystemExit(1)

    print("Media visualizer lifecycle contract: OK")


if __name__ == "__main__":
    main()
