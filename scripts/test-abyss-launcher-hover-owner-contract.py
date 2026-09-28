#!/usr/bin/env python3
from pathlib import Path
t=(Path(__file__).resolve().parents[1]/"modules/abyss/AbyssPerimeter.qml").read_text()
assert '["wifi","bluetooth","utilities","launcher"].includes(kind)' in t
print("launcher hover ownership contract: ok")
