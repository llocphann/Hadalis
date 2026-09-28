#!/usr/bin/env python3
from pathlib import Path
t=(Path(__file__).resolve().parents[1]/"services/deferred/Cliphist.qml").read_text()
assert r"/\[\[\s*binary data\b[\s\S]*?\]\]/i" in t
assert "x×" in t
assert "^\\[\\[\\s*binary data" not in t
print("clipboard owner binary metadata contract: ok")
