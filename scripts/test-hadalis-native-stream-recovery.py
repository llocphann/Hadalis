#!/usr/bin/env python3
"""Include native stream recovery contracts in canonical maintainer acceptance."""
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parents[1]
for name in ("test-hadalis-native-session.mjs", "test-hadalis-native-stream-recovery.mjs"):
    subprocess.run(["node", str(root / "scripts" / name)], cwd=root, check=True, timeout=15)
