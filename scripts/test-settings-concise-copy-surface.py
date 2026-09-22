#!/usr/bin/env python3
"""Contract guard for concise Settings copy and shared base surface color."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
README = (ROOT / "README.md").read_text(encoding="utf-8")
SERVICES = (ROOT / "modules" / "settings" / "ServicesConfig.qml").read_text(encoding="utf-8")
OVERLAY = (ROOT / "modules" / "settings" / "SettingsOverlay.qml").read_text(encoding="utf-8")
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
assert "color: Appearance.colors.colLayer0" in overlay_content
assert "colSurfaceContainerLow" not in overlay_content

assert """color: root.uiReady
        ? Appearance.colors.colLayer0
        : "transparent"""" in WINDOW
window_start = WINDOW.index("id: contentContainer")
window_end = WINDOW.index("// ── Page header", window_start)
window_content = WINDOW[window_start:window_end]
assert "color: Appearance.colors.colLayer0" in window_content
assert "colSurfaceContainerLow" not in window_content

# Source-of-truth comparison: physical Screen Edge and normal ii Bar use the
# same Material base token that Settings now uses.
assert ": Appearance.colors.colLayer0" in SCREEN_EDGE
assert "return Appearance.colors.colLayer0" in BAR

print("Settings concise-copy/shared-surface contract: PASS")
