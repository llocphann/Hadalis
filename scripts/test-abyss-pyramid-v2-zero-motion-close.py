#!/usr/bin/env python3
"""Lock Pyramid v2 close cleanup when the reveal scalar is already zero.

In reduced/disabled motion the popup owner can jump externalProgress directly to
zero. If that happens before semantic-close bookkeeping arms pyramidClosing,
there may be no later progressChanged signal. The host must therefore run the
same completion predicate immediately after beginClose.
"""
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
host=(ROOT/"modules/abyss/AbyssBodyHost.qml").read_text()

assert "function finishPyramidCloseIfDone(): void" in host
assert "root.progress > 0.001" in host
assert "root.pyramidCoordinator?.finishClose(root.identity)" in host

# The predicate is invoked both from the regular progress signal and directly
# after pyramidClosing becomes true.
assert "root.pyramidClosing=true" in host
close_arm=host.index("root.pyramidClosing=true")
immediate=host.index("root.finishPyramidCloseIfDone()", close_arm)
assert immediate > close_arm
assert "function finishPyramidReopenIfDone(): void" in host
assert "root.progress < 0.999" in host
assert "root.pyramidCoordinator?.finishReopen(root.identity)" in host
assert "onProgressChanged: {" in host
assert "root.finishPyramidCloseIfDone()" in host
assert "root.finishPyramidReopenIfDone()" in host

print("Pyramid Popup v2 zero-motion close cleanup contract: ok")
