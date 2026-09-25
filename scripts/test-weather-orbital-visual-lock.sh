#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

# First keep the semantic renderer/fallback contract green. The exact-content
# lock below is intentionally stricter and protects the maintainer-approved
# Orbital Weather appearance from cleanup/refactor/performance drift.
python3 "$repo_root/scripts/test-weather-liquid-orbital-contract.py"

python3 - "$repo_root" <<'PY'
from __future__ import annotations

import hashlib
from pathlib import Path
import sys


root = Path(sys.argv[1])
approved_on = "2026-09-25"

# VISUAL FREEZE: the maintainer explicitly approved this exact Orbital Weather
# appearance on 2026-09-25. These are Git blob IDs, so even a tiny edit to the
# visual-defining source/QSB fails closed.
#
# Do NOT refresh these hashes as part of refactors, cleanup, optimization,
# renderer work, or automated formatting. An intentional visual change requires
# explicit maintainer approval first, then a deliberate re-baseline of this map.
expected = {
    "modules/bar/weather/LiquidOrbitalField.qml":
        "1883b6877a02f6013fcacc7e30142e5f522b6165",
    "modules/bar/weather/LiquidOrbitalField.frag":
        "b14385e93e3690e18bfe10cbf123dc8525591b4e",
    "modules/bar/weather/LiquidOrbitalField.frag.qsb":
        "586f42291e050d432406e1ce9f1235ee63b91d34",
    "modules/bar/weather/OrbitalWeather.qml":
        "1b74f970a179756a6ec743b310654bdaf5ae90eb",
    "modules/bar/weather/WeatherPopupContent.qml":
        "cf6db708ed65f7d161f8e0bf391dfb0e70b8b3ab",
    "modules/bar/weather/WeatherPopup.qml":
        "5c6e11509eaa5ad3eafdc755fcc7e593ba82e83e",
}


def git_blob_id(payload: bytes) -> str:
    header = f"blob {len(payload)}\0".encode("ascii")
    return hashlib.sha1(header + payload).hexdigest()


drift = []
for relative, approved_blob in expected.items():
    path = root / relative
    if not path.is_file():
        drift.append((relative, approved_blob, "<missing>"))
        continue
    actual_blob = git_blob_id(path.read_bytes())
    if actual_blob != approved_blob:
        drift.append((relative, approved_blob, actual_blob))

if drift:
    print(
        f"Orbital Weather visual lock FAILED (approved {approved_on}).",
        file=sys.stderr,
    )
    for relative, approved_blob, actual_blob in drift:
        print(
            f"  {relative}: approved={approved_blob} current={actual_blob}",
            file=sys.stderr,
        )
    print(
        "This visual is frozen. Do not update the baseline for unrelated work. "
        "Only re-baseline after explicit maintainer approval of the new visual.",
        file=sys.stderr,
    )
    raise SystemExit(1)

print(f"Orbital Weather visual lock: PASS (approved {approved_on})")
PY
