#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")

def require(text: str, token: str, message: str) -> None:
    if token not in text:
        raise SystemExit("FAIL: " + message)

picker = read("services/CodeWorkflowPicker.qml")
runtime = read("services/CodeWorkflowRuntime.qml")
host = read("modules/settings/CodeWorkflowPickerHost.qml")
rail = read("modules/settings/SettingsOverlay.qml")
focus = read("modules/settings/SettingsFocus.qml")
page = read("modules/settings/CodeWorkflow.qml")
bar = read("modules/bar/Bar.qml")
services_qmldir = read("services/qmldir")
settings_qmldir = read("modules/settings/qmldir")

require(services_qmldir,
        "singleton CodeWorkflowPicker 1.0 CodeWorkflowPicker.qml",
        "picker singleton must be exported")
require(settings_qmldir,
        "CodeWorkflowPickerHost 1.0 CodeWorkflowPickerHost.qml",
        "picker host must be exported")

for source, label in ((rail, "rail"), (focus, "focus")):
    require(source, "CodeWorkflowPickerHost {",
            label + " Settings chrome must report presentation lifecycle")
    require(source, "settingsLoaded: root._panelLoaded",
            label + " picker host must wait for actual Settings surface teardown")

require(runtime, "function hit(output: string, x: real, y: real): string",
        "runtime must expose semantic hit testing")
require(runtime, "b.depth - a.depth",
        "hit testing must prefer deeper semantic targets")
require(runtime, "a.rect.width * a.rect.height",
        "hit testing must prefer the smaller target at equal depth")

for token in (
    'property string phase: "idle"',
    'root.phase = "preparing"',
    'root.phase = "picking"',
    'root.phase = "restoring"',
    'GlobalStates.settingsOverlayOpen = false',
    'GlobalStates.openSettingsPage',
    'root.liveOverlays !== 0',
    'CodeWorkflowSession.setViewport',
    'CodeWorkflowSession.selectTarget',
    'root.finish("locked", "")',
    'root.finish("output-removed", "")',
):
    require(picker, token, "picker lifecycle missing " + token)

require(picker, 'record.targetId !== "bar"',
        "picker may hold only already-resident Bar targets")
require(picker, "record.rect?.eligible",
        "picker must not wake or hold an ineligible/hidden Bar")
require(bar, "CodeWorkflowPicker.holdsOutput(barRoot.outputName)",
        "Bar auto-hide must honor the qualified picker hold")

for token in (
    "Variants {",
    "PanelWindow {",
    "WlrLayershell.layer: WlrLayer.Overlay",
    "WlrLayershell.keyboardFocus: WlrKeyboardFocus.None",
    "exclusionMode: ExclusionMode.Ignore",
    "acceptedButtons: Qt.LeftButton | Qt.RightButton",
    "event.accepted = true",
    'CodeWorkflowPicker.finish("cancelled", "")',
    'CodeWorkflowPicker.finish("selected", hit)',
):
    require(host, token, "picker surface contract missing " + token)

require(page, "CodeWorkflowPicker.canBegin",
        "Code Workflow page must gate picker on live overlay availability")
require(page, "CodeWorkflowPicker.begin()",
        "Code Workflow page must start the production picker")
require(page, "Picker is available from overlay Settings only",
        "standalone Settings must explain why picker is disabled")

print("ok - Code Workflow production picker contract")
