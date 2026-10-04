#!/usr/bin/env python3
"""Inert no-Qt security, side-geometry and fake-alpha contract.

Never starts Niri, reads machine sockets, captures a screen, or publishes
raw images. Actual bar/QML must pass a separately pinned isolated worker job.
"""
import ast
from pathlib import Path
import runpy

ROOT=Path(__file__).resolve().parents[1]
SCRIPT=ROOT/"scripts/wull-manual-nested-production-bar.py"
QML=ROOT/"scripts/wull-fixtures/production-bar-field/shell.qml"
runner=SCRIPT.read_text(encoding="utf-8")
qml=QML.read_text(encoding="utf-8")
ast.parse(runner)
assert 'background-color "#000000"' in runner
assert 'backdrop-color "#000000"' in runner
for required in (
    "NESTED_PREREQUISITES_PRESENT_NOT_ISOLATION_PASS",
    "display != host_display and ipc != host_ipc",
    'iso["socket_owned"](ipc, runtime)',
    'iso["socket_owned"](runtime / display, runtime)',
    'iso["outputs"](output) == 1',
    'iso["layers"](layer_data)',
    'host_ok = after is not None and before == after',
    'cleaned = iso["stop_owned"](proc)',
    'need(host_ok, "HOST_INVENTORY_CHANGED")',
    'need(cleaned, "NESTED_CLEANUP_UNQUALIFIED")',
    '"QT_QPA_PLATFORM": "wayland"',
    '"QSG_RHI_BACKEND": "opengl"',
    '"QT_QUICK_BACKEND": "rhi"',
    '"WULL_PANEL_SIDE": side',
    '"WULL_PANEL_REAL_PRIVATE_PNG": str(png)',
    'config["abyss"]["companion"]["enabled"] = False',
    'config["abyss"]["modules"].update({',
    'shutil.copyfile(FIXTURE, shell / "shell.qml")',
    'core["private_env"](xdg, png)',
    'for side in ("left", "right")',
    "panel_alpha(alpha, w, h, side)",
    'NESTED_REAL_BAR_TWO_SIDES_PRIVATE_CAPTURED',
    'ORIGINAL_PRIVATE_IMAGE=NOT_PUBLISHED',
):
    assert required in runner,required
for required in (
    "AbyssField {", "AbyssBar {", "AbyssCompanion {",
    "bar.itemForId(\"clock\")", "bar.layoutRecords",
    "records: bar.deformations",
    "Layout.edgeInsetsForModules(", "Layout.clearanceInsets(",
    "Placement.slot({", "HostPolicy.alongPosition(",
    "root.slot.occupiedOnEdge !== 1",
    'Quickshell.env("WULL_PANEL_REAL_PRIVATE_PNG")',
    "sheet.grabToImage",
    "PANEL_SHADER_UNQUALIFIED", "PANEL_BAR_MODULE_UNQUALIFIED",
    "PANEL_SLOT_UNQUALIFIED", "PANEL_WULL_HOST_UNQUALIFIED",
):
    assert required in qml,required
for forbidden in (
    "grim ", "git push", "subprocess.run(['grim'", "shell=True",
    "grabToImage", "shell_deploy", "git reset --hard"):
    assert forbidden not in runner,forbidden
assert 'Qt.size(512,512)' in qml
assert "WULL_PANEL_REAL_STAGE=BAR_LAYOUT_FIELD_AND_WULL_READY" in qml
fake=runpy.run_path(str(SCRIPT),run_name="wull_inert_nested_actual_bar")
assert fake["EXPECTED_STAGES"] == (
    "BOOT", "BAR_LAYOUT_FIELD_AND_WULL_READY", "PNG_SAVED")
stages="\n".join("WULL_PANEL_REAL_STAGE="+s for s in
                 fake["EXPECTED_STAGES"])+"\n"
judge=fake["fixed_qt_result"]
assert judge(stages,0,False)=="QUALIFIED"
assert judge(stages,1,False)=="QT_CHILD_UNQUALIFIED"
assert judge(stages,0,True)=="QT_CHILD_UNQUALIFIED"
assert judge(stages+"WULL_PANEL_REAL_FAIL=PANEL_SLOT_UNQUALIFIED\n",
             1,False)=="PANEL_SLOT_UNQUALIFIED"
assert judge(stages+"WULL_PANEL_REAL_FAIL=PRIVATE_CONFIG_PATH\n",
             1,False)=="QT_CHILD_UNQUALIFIED"
assert judge(stages+"WULL_PANEL_REAL_FAIL=PANEL_SLOT_UNQUALIFIED\n"*2,
             1,False)=="QT_CHILD_UNQUALIFIED"
w=h=512
paint=fake["panel_alpha"]
for side in ("left","right"):
    alpha=bytearray(w*h)
    a,b=(36,150) if side=="left" else (362,476)
    for y in range(330,370):
        for x in range(a,b):
            alpha[y*w+x]=255
    a,b=(0,24) if side=="left" else (488,512)
    for y in range(260,280):
        for x in range(a,b):
            alpha[y*w+x]=255
    assert paint(alpha,w,h,side)
    missing_rim=bytearray(alpha)
    for y in range(260,280):
        for x in range(a,b):
            missing_rim[y*w+x]=0
    try:
        paint(missing_rim,w,h,side)
        raise AssertionError("missing real field rim accepted")
    except fake["Gate"] as err:
        assert str(err)=="PANEL_ALPHA_UNQUALIFIED"
    missing_body=bytearray(alpha)
    a,b=(36,150) if side=="left" else (362,476)
    for y in range(330,370):
        for x in range(a,b):
            missing_body[y*w+x]=0
    try:
        paint(missing_body,w,h,side)
        raise AssertionError("missing Wull body accepted")
    except fake["Gate"] as err:
        assert str(err)=="PANEL_ALPHA_UNQUALIFIED"
print("WULL_NESTED_REAL_ABYSS_BAR_FAKE_ONLY_PASS")
