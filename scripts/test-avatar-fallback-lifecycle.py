#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

SURFACES = (
    ("modules/settings/SettingsFocus.qml", "avatarResolver"),
    ("modules/dashboard/DashWelcome.qml", "avatarResolver"),
    ("modules/sidebarRight/SidebarProfileHeader.qml", "avatarResolver"),
    ("modules/background/widgets/userCard/UserCardWidget.qml", "avatarResolver"),
    ("modules/controlPanel/ProfileHeader.qml", "profileAvatarResolver"),
    ("modules/lock/LockSurface.qml", "lockAvatarResolver"),
    ("modules/waffle/lock/WaffleLockSurface.qml", "waffleLockAvatarResolver"),
    ("modules/waffle/lock/WaffleLockSurfaceSafe.qml", "safeLockAvatarResolver"),
)


def main() -> None:
    for rel, resolver in SURFACES:
        source = (ROOT / rel).read_text(encoding="utf-8")
        if "readonly property int imgStatus:" in source:
            raise SystemExit(
                f"avatar fallback lifecycle failed: {rel} binds Image.status into a resolver that mutates its source"
            )

        source_token = f"source: {resolver}.resolvedSource"
        signal_token = f"onStatusChanged: {resolver}.handleImageStatus(status)"
        handler_token = "function handleImageStatus(status): void {"
        source_pos = source.find(source_token)
        signal_pos = source.find(signal_token)
        handler_pos = source.find(handler_token)
        if source_pos < 0 or signal_pos < 0 or not (source_pos < signal_pos < handler_pos):
            raise SystemExit(
                f"avatar fallback lifecycle failed: {rel} does not handle status on its avatar Image"
            )

        if handler_pos < 0:
            raise SystemExit(
                f"avatar fallback lifecycle failed: {rel} lost ordered avatar fallback handling"
            )

    print("avatar fallback lifecycle: ok")


if __name__ == "__main__":
    main()
