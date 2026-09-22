#!/usr/bin/env python3
"""Contract guard for concise Settings copy and shared base surface color."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
README = (ROOT / "README.md").read_text(encoding="utf-8")
SERVICES = (ROOT / "modules" / "settings" / "ServicesConfig.qml").read_text(encoding="utf-8")
OVERLAY = (ROOT / "modules" / "settings" / "SettingsOverlay.qml").read_text(encoding="utf-8")
FOCUS = (ROOT / "modules" / "settings" / "SettingsFocus.qml").read_text(encoding="utf-8")
MODULES = (ROOT / "modules" / "settings" / "ModulesConfig.qml").read_text(encoding="utf-8")
WINDOW = (ROOT / "settings.qml").read_text(encoding="utf-8")
SCREEN_EDGE = (ROOT / "modules" / "screenCorners" / "ScreenEdges.qml").read_text(encoding="utf-8")
BAR = (ROOT / "modules" / "bar" / "BarContent.qml").read_text(encoding="utf-8")

assert "Settings copy stays terse." in README
assert "only a few words or one short clause" in README
assert "paragraph-length explanation" in README

for token in (
    'Translation.tr("One Markdown file and heading.")',
    'Translation.tr("Obsidian vault root.")',
    'Translation.tr("Fixed or date-based Markdown path.")',
    'Translation.tr("Checkboxes under this heading only.")',
    'Translation.tr("Direct Markdown sync.")',
    'Translation.tr("Activate verified source.")',
    'Translation.tr("Capture to Zettelkasten; keep the draft.")',
    'Translation.tr("Blank = reuse Todo vault.")',
    'Translation.tr("Vault-relative capture folder.")',
    'Translation.tr("Uses the vault Zettelkasten template.")',
):
    assert token in SERVICES, f"concise Settings copy lost: {token}"

for stale in (
    "Use one Markdown note source. The path may be fixed or contain date tokens",
    "Physical Obsidian vault folder. Hadalis resolves the configured note strictly inside this directory.",
    "Dashboard Quick Notes are drafts until capture. A successful capture creates one filesystem-canonical Zettelkasten note, then clears the unchanged draft.",
    "The generated Markdown follows the vault's Zettelkasten schema:",
):
    assert stale not in SERVICES, f"verbose/stale Settings copy returned: {stale}"

overlay_start = OVERLAY.index("id: overlayContentContainer")
overlay_end = OVERLAY.index("// ── Page header", overlay_start)
overlay_content = OVERLAY[overlay_start:overlay_end]
assert 'color: "transparent"' in overlay_content
assert "Appearance.colors.colLayer0" not in overlay_content
assert "colSurfaceContainerLow" not in overlay_content

assert 'color: "transparent"' in WINDOW
window_surface_start = WINDOW.index("id: windowBaseSurface")
window_surface_end = WINDOW.index("Shortcut {", window_surface_start)
window_surface = WINDOW[window_surface_start:window_surface_end]
assert 'color: root.uiReady ? Appearance.colors.colLayer0 : "transparent"' in window_surface

window_start = WINDOW.index("id: contentContainer")
window_end = WINDOW.index("// ── Page header", window_start)
window_content = WINDOW[window_start:window_end]
assert 'color: "transparent"' in window_content
assert "Appearance.colors.colLayer0" not in window_content
assert "colSurfaceContainerLow" not in window_content

# Source-of-truth comparison: physical Screen Edge and normal ii Bar use the
# same Material base token that Settings now uses.
assert ": Appearance.colors.colLayer0" in SCREEN_EDGE
assert "return Appearance.colors.colLayer0" in BAR

# The connected surface owns colLayer0 exactly once; inner content must not
# repaint it because colLayer0 may carry global transparency.
overlay_surface_start = OVERLAY.index("id: settingsCard")
overlay_surface_end = OVERLAY.index("anchors.horizontalCenter", overlay_surface_start)
overlay_surface = OVERLAY[overlay_surface_start:overlay_surface_end]
assert "readonly property color surfaceFillColor: Appearance.colors.colLayer0" in overlay_surface
assert "panelBgOpacity" not in overlay_surface
assert "CF.ColorUtils.applyAlpha(" not in overlay_surface

focus_surface_start = FOCUS.index("id: card")
focus_surface_end = FOCUS.index("anchors.horizontalCenter", focus_surface_start)
focus_surface = FOCUS[focus_surface_start:focus_surface_end]
assert "readonly property color surfaceFillColor: Appearance.colors.colLayer0" in focus_surface
assert "CF.ColorUtils.applyAlpha(" not in focus_surface

assert 'Translation.tr("Panel background opacity (%)")' not in MODULES
assert "Settings base surface has one owner." in README

# Standalone Settings must handle Config already being ready before
# Connections.onReadyChanged can observe the transition, just like shell.qml.
assert "if (Config.ready) {" in WINDOW
assert "Qt.callLater(() => ThemeService.applyCurrentTheme())" in WINDOW

print("Settings concise-copy/shared-surface contract: PASS")
