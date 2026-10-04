#!/usr/bin/env python3
"""Inert contract for synthetic real-field capture in a nested session.

No host sockets, real Qt, compositor, screenshot access or Git mutation.
"""
import ast
from pathlib import Path
import runpy

ROOT = Path(__file__).resolve().parents[1]
P = ROOT / "scripts/wull-manual-nested-field-capture.py"
SOURCE = P.read_text(encoding="utf-8")
ast.parse(SOURCE)
assert 'background-color "#000000"' in SOURCE
assert 'backdrop-color "#000000"' in SOURCE
FIXTURE = (ROOT / "scripts/wull-fixtures/real-field-canary/shell.qml").read_text()
assert "id: sheet\n            // The compositor owns FloatingWindow sizing" in FIXTURE
assert "width: 512\n            height: 512" in FIXTURE
assert "id: sheet\n            anchors.fill: parent" not in FIXTURE
for required in (
    'QT_QPA_PLATFORM": "wayland"',
    '"QSG_RHI_BACKEND": "opengl"',
    '"QT_QUICK_BACKEND": "rhi"',
    '"WAYLAND_DISPLAY": display',
    '"NIRI_SOCKET": ipc',
    '"XDG_RUNTIME_DIR": str(runtime)',
    'need(display != host_display and ipc != host_ipc',
    'and iso["socket_owned"](ipc, runtime)',
    'and iso["socket_owned"](runtime / display, runtime)',
    'and iso["outputs"](output) == 1',
    'iso["layers"](layer_data)',
    'host_ok = after is not None and before == after',
    'cleaned = iso["stop_owned"](proc)',
    'need(host_ok, "HOST_INVENTORY_CHANGED")',
    'need(cleaned, "NESTED_CLEANUP_UNQUALIFIED")',
    'core["private_env"](xdg, output)',
    'shutil.copyfile(FIXTURE, shell / "shell.qml")',
    'config["abyss"]["quality"] = "performance"',
    'field["painted_cells"](alpha, width, height)',
    'run_name="nested_field_alpha_decoder"',
    'WULL_FIELD_CANARY_FAILURE=',
    'NESTED_SHADER_SYNTHETIC_PRIVATE_CAPTURED',
    'ORIGINAL_PRIVATE_IMAGE=NOT_PUBLISHED',
    'REAL_HOST_PANEL_OR_POINTER=NOT_TESTED',
):
    assert required in SOURCE, required
for prohibited in ("git push", "grim ", "subprocess.run(['grim'",
                  "shell=True", "shutil.rmtree(ROOT",
                  '"QT_QPA_PLATFORM": "offscreen"', '"WAYLAND_DISPLAY": host_display,\n        "NIRI_SOCKET":'):
    assert prohibited not in SOURCE, prohibited
m = runpy.run_path(str(P), run_name="fake_only_nested_field")
judge = m["fixed_qt_result"]
stage = ("WULL_FIELD_CANARY_STAGE=BOOT\n"
         "WULL_FIELD_CANARY_STAGE=REAL_FIELD_FOUR_HOSTS_READY\n"
         "WULL_FIELD_CANARY_STAGE=PNG_SAVED\n")
assert judge(stage, 0, False) == "QUALIFIED"
assert judge(stage, 1, False) == "QT_CHILD_UNQUALIFIED"
assert judge(stage, 0, True) == "QT_CHILD_UNQUALIFIED"
assert judge(stage.replace("PNG_SAVED", "UNKNOWN"), 0, False) == (
    "QT_STAGE_UNQUALIFIED")
assert judge(stage + "WULL_FIELD_CANARY_FAILURE=WINDOW_NOT_BACKING\n",
             1, False) == "WINDOW_NOT_BACKING"
assert judge(stage + "WULL_FIELD_CANARY_FAILURE=MY_PRIVATE_PATH\n",
             1, False) == "QT_CHILD_UNQUALIFIED"
assert judge(stage + ("WULL_FIELD_CANARY_FAILURE=WINDOW_NOT_BACKING\n" * 2),
             1, False) == "QT_CHILD_UNQUALIFIED"
print("WULL_NESTED_FIELD_FAKE_ONLY_PASS")
