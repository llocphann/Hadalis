#!/usr/bin/env python3
"""Guard the configurable horizontal Bar Media width contract."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def require(source: str, token: str, message: str) -> None:
    if token not in source:
        raise SystemExit(message)


def main() -> None:
    media = read("modules/bar/Media.qml")
    config = read("modules/common/Config.qml")
    settings = read("modules/settings/BarConfig.qml")
    defaults = json.loads(read("defaults/config.json"))

    require(media, "Config.options?.bar?.media?.width ?? 180",
            "Bar Media must consume the persisted width setting.")
    require(media, "Math.max(120, Math.min(320, configured))",
            "Bar Media width must stay inside the supported runtime range.")

    # Short titles are centered in the available label lane; overflowing titles
    # switch to leading alignment so the marquee has a deterministic origin.
    for token in (
        "mediaInset: Math.max(2, Math.round(4 * Appearance.sizes.barModuleScale))",
        "mediaTextGap: Math.max(4, Math.round(7 * Appearance.sizes.barModuleScale))",
        "anchors.leftMargin: root.mediaInset",
        "anchors.rightMargin: root.mediaInset",
        "Layout.minimumWidth: 0",
        "font.pixelSize: Math.max(11, Math.round(Appearance.font.pixelSize.small * Appearance.sizes.barModuleScale))",
        "titleScroller.resetMarquee()",
        "onWidthChanged: resetMarquee()",
        "onOverflowingChanged: resetMarquee()",
        "Component.onCompleted: {",
        "if (!_marqueeReady) return",
    ):
        require(media, token, f"Bar Media label alignment contract missing: {token}")

    require(" ".join(media.split()),
            "horizontalAlignment: titleScroller.overflowing ? Text.AlignLeft : Text.AlignHCenter",
            "Bar Media title alignment must remain centered until the marquee overflows.")

    require(config, "property JsonObject media: JsonObject {",
            "Typed Bar config lost the media subsection.")
    require(config, "property int width: 180",
            "Typed Bar config lost the compact Media width default.")

    require(settings, 'text: Translation.tr("Media width (px)")',
            "Bar Settings lost the Media width control.")
    require(settings, 'Config.setNestedValue("bar.media.width", value)',
            "Bar Settings no longer persists Media width.")
    require(settings, "from: 120",
            "Bar Settings Media width minimum drifted.")
    require(settings, "to: 320",
            "Bar Settings Media width maximum drifted.")

    if defaults.get("bar", {}).get("media", {}).get("width") != 180:
        raise SystemExit("defaults/config.json lost bar.media.width = 180")

    print("Bar Media width contract: OK")


if __name__ == "__main__":
    main()
