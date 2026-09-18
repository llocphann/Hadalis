#!/usr/bin/env python3
"""Regression contract for the bar media CAVA/WaveVisualizer lifecycle."""
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
    player = read("modules/mediaControls/PlayerControl.qml")
    cava = read("modules/common/widgets/CavaProcess.qml")

    check(
        "readonly property bool presentationActive: root.QsWindow.window?.visible ?? false" in popup,
        "Bar media visualizer must be gated by the actual presentation window",
    )
    check(
        "readonly property bool visualizerActive: root.presentationActive" in popup,
        "CAVA activation must depend on presentationActive rather than Item.visible alone",
    )
    check(
        "active: root.visualizerActive" in popup,
        "BarMediaPopup must drive CavaProcess from the lifecycle-gated active state",
    )
    check(
        "visualizerPoints: root.visualizerPoints" in popup,
        "BarMediaPopup must forward CAVA points into PlayerControl",
    )
    check(
        "cavaProcess.normalizationCeiling" in popup
        and "visualizerMaxValue: root.visualizerMaxValue" in popup,
        "BarMediaPopup must forward the shared adaptive CAVA normalization ceiling",
    )
    media_controls = read("modules/mediaControls/MediaControls.qml")
    check(
        "cavaProcess.normalizationCeiling" in media_controls
        and "visualizerMaxValue: root.visualizerMaxValue" in media_controls,
        "Global MediaControls must share the adaptive CAVA normalization contract",
    )
    check(
        "WaveVisualizer {" in player and "points: root.visualizerPoints" in player,
        "PlayerControl must keep the CAVA -> WaveVisualizer data route",
    )
    check(
        "maxVisualizerValue: Math.max(1, root.visualizerMaxValue)" in player
        and "maxVisualizerValue: 1000" not in player,
        "PlayerControl must scale the wave against the adaptive signal ceiling instead of a fixed 1000",
    )
    check(
        "CavaService.subscribe(root.sampleCount)" in cava,
        "CavaProcess must subscribe while active",
    )
    check(
        "CavaService.unsubscribe(root._subscriptionId)" in cava,
        "CavaProcess must unsubscribe when presentation activity drops",
    )

    if failures:
        print("Media visualizer lifecycle contract regression(s):")
        for failure in failures:
            print(f"  - {failure}")
        raise SystemExit(1)

    print("Media visualizer lifecycle contract: OK")


if __name__ == "__main__":
    main()
