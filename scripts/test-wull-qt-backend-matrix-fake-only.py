#!/usr/bin/env python3
"""No Qt/no host access: fixed-category diagnostic parser and source guard."""
from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts/wull-qt-offscreen-backend-matrix.py"
QML = ROOT / "scripts/wull-fixtures/qt-backend-probe/shell.qml"
text = SCRIPT.read_text()
fixture = QML.read_text()
for expected in (
    "borrowed[\"private_env\"](xdg, workspace",
    '"QT_QUICK_BACKEND"',
    'env.update(QSG_RHI_BACKEND="opengl", QT_QUICK_BACKEND="rhi")',
    'env["QT_QUICK_BACKEND"] = "software"',
    "start_new_session=True", "os.killpg(",
    "GATE=BACKEND_MATRIX_D", "os.umask(0o077)",
):
    assert expected in text, expected
assert 'visible: true' in fixture
assert "WULL_BACKEND_PROBE=" in fixture
assert "backingWindowVisible" in fixture
for forbidden in ("grabToImage", "saveToFile", "grim ",
                  "WlrLayershell", "import Quickshell.Wayland", "git push"):
    assert forbidden not in fixture
for forbidden in ("shell=True", "git push", "grim ", "WAYLAND_DISPLAY="):
    assert forbidden not in text
m = runpy.run_path(str(SCRIPT), run_name="wull_fake_backend_parser")
classify = m["parse_private_stage"]
assert classify("WULL_BACKEND_PROBE=BACKING\n", 0, False) == "1"
assert classify("WARN: only synthetic test\nWULL_BACKEND_PROBE=NO_BACKING\n",
                0, False) == "0"
assert classify("WULL_BACKEND_PROBE=BACKING\n" * 2, 0, False) == "X"
assert classify("WULL_BACKEND_PROBE=BACKING\n", 1, False) == "X"
assert classify("WULL_BACKEND_PROBE=BACKING\n", 0, True) == "X"
assert classify("raw-unrecognized-private-error", 0, False) == "X"
print("WULL_QT_OFFSCREEN_BACKEND_MATRIX_FAKE_ONLY_PASS")
