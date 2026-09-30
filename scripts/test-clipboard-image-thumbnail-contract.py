#!/usr/bin/env python3
"""Clipboard image rows must render the existing lazy thumbnail path, not metadata text."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ITEM = (ROOT / "modules/clipboard/ClipboardItem.qml").read_text(encoding="utf-8")
IMAGE = (ROOT / "modules/common/widgets/CliphistImage.qml").read_text(encoding="utf-8")
SERVICE = (ROOT / "services/deferred/Cliphist.qml").read_text(encoding="utf-8")

def require(source: str, token: str, message: str) -> None:
    if token not in source:
        raise SystemExit(f"FAIL: {message} ({token})")

for token in (
    "readonly property bool imageEntry:",
    "&& Cliphist.entryIsImage(root.cliphistRawString)",
    "visible: !root.imageEntry",
    "active: root.imageEntry",
    "sourceComponent: CliphistImage {",
    "maxWidth: Math.max(48,",
):
    require(ITEM, token, "Clipboard image/text presentation split missing")

for token in (
    "// Lazy decode: only start when visible",
    "if [ -s '${imageDecodeFilePath}' ]; then",
    "_tmp='${imageDecodeFilePath}'.$$",
    "/usr/bin/mv -f",
    "maxWidth / imageWidth",
    "maxHeight / imageHeight",
):
    require(IMAGE, token, "mature lazy thumbnail decode/cache contract missing")

require(SERVICE, "function entryIsImage(entry)", "cliphist image detection missing")
require(SERVICE, "binary data", "cliphist binary metadata detection missing")
print("ok - image clipboard rows use bounded lazy thumbnails and hide binary metadata text")
