#!/usr/bin/env python3
"""Regression contract for the compact Weather/Calendar hover composition."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "modules" / "bar" / "weather" / "WeatherPopupContent.qml"
CARD = ROOT / "modules" / "bar" / "weather" / "WeatherCard.qml"


def main() -> None:
    source = SOURCE.read_text(encoding="utf-8")
    card = CARD.read_text(encoding="utf-8")

    required = (
        "columns: root.compact ? 1 : 3",
        "(Weather.data?.hourly ?? []).slice(0, 8)",
        "implicitHeight: composition.implicitHeight",
        "readonly property real panelHeight: 270",
        "anchors.topMargin: -12",
        "anchors.bottomMargin: 0",
        "anchors.verticalCenterOffset: 0",
        "readonly property real radiusX: Math.max(122, (width - 84) / 2)",
        "readonly property real radiusY: Math.max(82, (height - 104) / 2)",
        "width: 52",
        "height: 64",
        'text: Qt.formatDate(root.now, "dddd, MMM d")',
        'text: Translation.tr("Last refresh: %1").arg(Weather.data.lastRefresh)',
    )
    for token in required:
        if token not in source:
            raise AssertionError(f"Weather popup missing compact composition token: {token!r}")

    for forbidden in (
        "implicitHeight: 300",
        "anchors.bottomMargin: 20",
        "DateTime.timeDisplay",
        "pixelSize: Math.round(Appearance.font.pixelSize.large * 1.55)",
        "pixelSize: Math.round(Appearance.font.pixelSize.large * 2.0)",
        "pixelSize: Math.round(Appearance.font.pixelSize.large * 2.6)",
        "width: 58",
        "height: 72",
    ):
        if forbidden in source:
            raise AssertionError(f"Weather popup still contains oversized/loose layout token: {forbidden!r}")

    if source.count("implicitHeight: root.panelHeight") != 3:
        raise AssertionError(
            "Calendar, orbital center and right detail card must share the same outer panel height"
        )
    for token in (
        "implicitWidth: columnLayout.implicitWidth + 10 * 2",
        "implicitHeight: columnLayout.implicitHeight + 10 * 2",
    ):
        if token not in card:
            raise AssertionError(f"Weather detail metric card must stay compact: {token!r}")

    refresh_token = 'text: Translation.tr("Last refresh: %1").arg(Weather.data.lastRefresh)'
    if source.count(refresh_token) != 1:
        raise AssertionError("Weather popup must render exactly one Last refresh label")

    detail_start = source.index("id: detailColumn")
    refresh_pos = source.index(refresh_token)
    if refresh_pos <= detail_start:
        raise AssertionError(
            "Last refresh must live inside the right-hand detailColumn, below weather details"
        )

    print("Weather popup compact composition contract: OK")


if __name__ == "__main__":
    main()
