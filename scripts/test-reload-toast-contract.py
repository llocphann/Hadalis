#!/usr/bin/env python3
"""Source contract for reload-toast dismissal semantics."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TOAST = (ROOT / "modules/common/widgets/ToastNotification.qml").read_text(encoding="utf-8")
MANAGER = (ROOT / "modules/common/ToastManager.qml").read_text(encoding="utf-8")

def require(source: str, token: str, message: str) -> None:
    if token not in source:
        raise SystemExit(f"FAIL: {message} ({token})")

for token in (
    'readonly property bool showDismissButton: root.source !== "reload"',
    'visible: root.showDismissButton',
    'paused: mouseArea.containsMouse',
    'onFinished: root.dismissed()',
):
    require(TOAST, token, "reload toast auto-dismiss contract missing")

for token in (
    '"Quickshell reloaded"',
    '"Niri Reloaded"',
    '2000,',
    '"reload",',
    '"Quickshell reload failed"',
    '"Niri config reload failed"',
    '"error",',
):
    require(MANAGER, token, "reload/error ToastManager routing changed")

require(TOAST, 'visible: root.isError && root.message !== ""',
        "error copy action must remain available")
print("ok - reload toasts self-dismiss without a close X; error actions remain")
