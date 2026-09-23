#!/usr/bin/env python3
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CORNERS = ROOT / "modules" / "screenCorners" / "ScreenCorners.qml"
POPUP = ROOT / "modules" / "screenCorners" / "QuickNotesPopup.qml"
SCREEN_EDGES = ROOT / "modules" / "screenCorners" / "ScreenEdges.qml"
NOTEPAD = ROOT / "modules" / "sidebarRight" / "notepad" / "NotepadWidget.qml"
CONFIG = ROOT / "modules" / "common" / "Config.qml"
DEFAULTS = ROOT / "defaults" / "config.json"
SETTINGS = ROOT / "modules" / "settings" / "InterfaceConfig.qml"
REGISTRY = ROOT / "modules" / "settings" / "SettingsPageRegistryData.qml"
QMLDIR = ROOT / "modules" / "screenCorners" / "qmldir"


def fail(message: str) -> None:
    raise SystemExit("FAIL: " + message)


def require(source: str, token: str, message: str) -> None:
    if token not in source:
        fail(message + " (" + token + ")")


corners = CORNERS.read_text(encoding="utf-8")
popup = POPUP.read_text(encoding="utf-8")
screen_edges = SCREEN_EDGES.read_text(encoding="utf-8")
notepad = NOTEPAD.read_text(encoding="utf-8")
config = CONFIG.read_text(encoding="utf-8")
defaults = json.loads(DEFAULTS.read_text(encoding="utf-8"))
settings = SETTINGS.read_text(encoding="utf-8")
registry = REGISTRY.read_text(encoding="utf-8")
qmldir = QMLDIR.read_text(encoding="utf-8")

# The physical Screen Edge is a maintainer-locked paint geometry. Quick Notes is
# interaction/popup behavior only and must never add a second painted corner.
if "QuickNotes" in screen_edges or "quickNotes" in screen_edges:
    fail("Quick Notes must not modify the locked physical ScreenEdges renderer")

for token in (
    "QuickNotesPopup 1.0 QuickNotesPopup.qml",
):
    require(qmldir, token, "screenCorners module must export the Quick Notes popup")

for token in (
    "import QtQuick.Controls",
    "Bar.StyledPopup {",
    'attachmentEdgeOverride: "bottom"',
    "attachmentThicknessOverride:",
    "hoverActivates: true",
    "alternativeVisibleCondition: root.editorFocused",
    "keyboardFocus: root.editorFocused",
    "closeOnOutsideClick: root.editorFocused",
    "NotepadWidget {",
    "compactPresentation: true",
    "notesEditor.focusEditor()",
    "notesEditor.flushPendingSave()",
    "Component.onDestruction: notesEditor.flushPendingSave()",
    'sequence: "Escape"',
):
    require(popup, token, "Quick Notes popup interaction/focus contract missing")

for token in (
    "function focusEditor(): void",
    "textArea.forceActiveFocus()",
    "function flushPendingSave(): void",
    "saveTimer.stop()",
    "Notepad.setTextValue(textArea.text)",
):
    require(notepad, token, "shared Notepad must expose safe Quick Notes hooks")

for token in (
    "readonly property bool shouldShowQuickNotesCorner:",
    "cornerPanelWindow.isBottomLeft",
    "&& !cornerPanelWindow.shouldShowOrbitHotCorner",
    "&& !cornerPanelWindow.orbitConflictsWithNiriOverview",
    "&& !cornerPanelWindow.quickNotesInteractionBlocked",
    "&& !shouldShowQuickNotesCorner",
    "id: quickNotesCornerLoader",
    "property bool dwellReady: false",
    "id: quickNotesDwellTimer",
    "Config.options?.quickNotes?.hoverDelayMs ?? 220",
    "Config.options?.quickNotes?.cornerSize ?? 14",
    "QuickNotesPopup {",
    "anchorItem: quickNotesAnchor",
):
    require(corners, token, "bottom-left Quick Notes corner contract missing")

# Orbit remains authoritative if the user deliberately assigns it to this
# corner; otherwise Quick Notes owns bottom-left before legacy sidebar opening.
quick_start = corners.index("readonly property bool shouldShowQuickNotesCorner:")
sidebar_start = corners.index("readonly property bool shouldShowSidebarCornerOpen:")
if not quick_start < sidebar_start:
    fail("Quick Notes priority must be resolved before legacy sidebar corner-open")
quick_block = corners[quick_start:sidebar_start]
require(quick_block, "!cornerPanelWindow.shouldShowOrbitHotCorner",
        "Orbit hot corner must retain priority over Quick Notes")
require(quick_block, "!cornerPanelWindow.orbitConflictsWithNiriOverview",
        "native Niri hot corners must retain priority over Quick Notes")

schema_match = re.search(
    r"property JsonObject quickNotes: JsonObject \{([\s\S]*?)\n\s*\}",
    config,
)
if not schema_match:
    fail("Config schema does not expose quickNotes")
schema = schema_match.group(1)
for token in (
    "property bool enable: true",
    "property int hoverDelayMs: 220",
    "property int cornerSize: 14",
    "property int popupWidth: 420",
    "property int popupHeight: 300",
):
    require(schema, token, "Quick Notes Config default missing")

expected_defaults = {
    "enable": True,
    "hoverDelayMs": 220,
    "cornerSize": 14,
    "popupWidth": 420,
    "popupHeight": 300,
}
if defaults.get("quickNotes") != expected_defaults:
    fail("defaults/config.json Quick Notes values do not match Config.qml schema")

for token in (
    'title: Translation.tr("Bottom-left Quick Notes")',
    'Config.options?.quickNotes?.enable ?? true',
    'Config.setNestedValue("quickNotes.enable", checked)',
    'Config.setNestedValue("quickNotes.hoverDelayMs", value)',
    'Config.setNestedValue("quickNotes.cornerSize", value)',
    'Config.setNestedValue("quickNotes.popupWidth", value)',
    'Config.setNestedValue("quickNotes.popupHeight", value)',
):
    require(settings, token, "Quick Notes Settings controls missing")

for token in (
    'section: Translation.tr("Bottom-left Quick Notes")',
    'label: Translation.tr("Quick Notes corner")',
    '"quick notes"',
    '"bottom left"',
    '"hover"',
):
    require(registry, token, "Quick Notes Settings search metadata missing")

print("ok - bottom-left Quick Notes corner contract")
