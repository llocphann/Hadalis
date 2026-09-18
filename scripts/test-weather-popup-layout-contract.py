#!/usr/bin/env python3
"""Regression contract for the compact Weather/Calendar hover composition."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "modules" / "bar" / "weather" / "WeatherPopupContent.qml"


def main() -> None:
    source = SOURCE.read_text(encoding="utf-8")

    required = (
        "columns: root.compact ? 1 : 3",
        "(Weather.data?.hourly ?? []).slice(0, 8)",
        "implicitHeight: composition.implicitHeight",
        "implicitHeight: 270",
        "anchors.topMargin: -12",
        "anchors.bottomMargin: 0",
        "anchors.verticalCenterOffset: -24",
        "pixelSize: Math.round(Appearance.font.pixelSize.large * 1.55)",
        'text: Translation.tr("Last refresh: %1").arg(Weather.data.lastRefresh)',
    )
    for token in required:
        if token not in source:
            raise AssertionError(f"Weather popup missing compact composition token: {token!r}")

    for forbidden in (
        "implicitHeight: 300",
        "anchors.bottomMargin: 20",
        "pixelSize: Math.round(Appearance.font.pixelSize.large * 2.0)",
        "pixelSize: Math.round(Appearance.font.pixelSize.large * 2.6)",
    ):
        if forbidden in source:
            raise AssertionError(f"Weather popup still contains oversized/loose layout token: {forbidden!r}")

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
