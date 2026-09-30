#!/usr/bin/env python3
from pathlib import Path

text = (Path(__file__).resolve().parents[1] / "services/deferred/Cliphist.qml").read_text()

for needle in [
    "function entryImageMime(entry): string",
    'return "image/png"',
    'return "image/jpeg"',
    'return "image/webp"',
    "function wlCopyCommand(entry): string",
    "--type",
    "root.wlCopyCommand(entry)",
]:
    assert needle in text, needle

print("clipboard image MIME restore contract: ok")
