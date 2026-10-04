#!/usr/bin/env python3
"""Regression guard: every owned nested-Niri debug window uses a dark canvas."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RUNNERS = (
    "scripts/wull-manual-nested-niri.py",
    "scripts/wull-nested-isolation-smoke.py",
    "scripts/wull-manual-nested-field-capture.py",
    "scripts/wull-manual-nested-pointer.py",
    "scripts/wull-manual-private-nested-quarter-visual.py",
)

for relative in RUNNERS:
    source = (ROOT / relative).read_text(encoding="utf-8")
    assert 'background-color "#000000"' in source, relative
    assert 'write_text("", encoding="utf-8")' not in source, relative

print("Nested Niri debug background contract: black")
