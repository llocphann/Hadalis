#!/usr/bin/env python3
from pathlib import Path

root = Path(__file__).resolve().parents[1]
service = (root / "services/deferred/Cliphist.qml").read_text()
image = (root / "modules/common/widgets/CliphistImage.qml").read_text()
item = (root / "modules/clipboard/ClipboardItem.qml").read_text()

for needle in [
    'const preview = raw.replace(/^\\s*\\d+(?:\\t|\\s+)/, "").trim()',
    'binary data\\b',
    'png|jpe?g|webp|gif|bmp|tiff?|avif|heic|heif',
    '\\d{1,6}x\\d{1,6}',
]:
    assert needle in service, needle

assert 'root.entry.match(/^\\s*(\\d+)(?:\\t|\\s+)/)' in image
assert 'Cliphist.decodeCommand(root.entry)' in image
assert 'active: root.imageEntry' in item
assert 'visible: !root.imageEntry' in item

# The old detector was exact-tab-only and caused real image metadata to render
# as text when cliphist used a different list separator.
assert '^\\d+\\t\\[\\[' not in service

print("clipboard image classification contract: ok")
