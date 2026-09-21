#!/usr/bin/env python3
"""Contract guard for the Todo/Obsidian settings surface."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
services = (ROOT / "modules" / "settings" / "ServicesConfig.qml").read_text(encoding="utf-8")
backend = (ROOT / "services" / "ObsidianTodoBackend.qml").read_text(encoding="utf-8")
facade = (ROOT / "services" / "Todo.qml").read_text(encoding="utf-8")

required_ui = [
    'title: Translation.tr("Todo & Obsidian")',
    'Config.setNestedValue("todo.obsidian.vaultPath", value)',
    'Config.setNestedValue("todo.obsidian.notePath", value)',
    'Config.setNestedValue("todo.obsidian.preferTasksPlugin", checked)',
    'Config.setNestedValue("todo.obsidian.allowBasicOfflineMutation", checked)',
    '<!-- hadalis:todo:start -->',
    '<!-- hadalis:todo:end -->',
    "Todo.beginObsidianSetup()",
    "Todo.cancelObsidianSetup()",
    "Todo.reactivateInternal()",
    "Todo.initializeSection()",
    "Todo.previewInternalToObsidian()",
    "Todo.migrateInternalToObsidian(",
    "Todo.activateObsidian()",
    "Todo.openObsidianSource()",
    "Todo.obsidianSetupActive",
    "Todo.obsidianReady",
    "Todo.obsidianBusy",
    "Todo.obsidianCapabilities",
    "Todo.obsidianMigrationPreview",
    "Todo.obsidianList.length",
    'Translation.tr("Preview import")',
    'Translation.tr("Import & activate")',
    'Translation.tr("Use Obsidian note")',
]
for snippet in required_ui:
    assert snippet in services, f"Todo settings UI lost contract: {snippet}"

# Settings must never switch canonical ownership merely because the user picked
# a backend. Setup is staged through Todo and activation happens only after a
# verified note or committed migration.
assert 'Config.setNestedValue("todo.backend", newValue)' not in services
assert 'currentValue: Config.options?.todo?.backend ?? "internal"' not in services
assert 'Config.setNestedValue("todo.backend", "obsidian")' not in services
assert 'Config.setNestedValue("todo.backend", "obsidian")' in facade
assert "function activateObsidian(): bool" in facade
assert "signal migrationCommitted(var payload)" in backend
assert 'mutationProc.kind === "preview-migration"' in backend

# Paths are committed on editingFinished, not on every keystroke. This avoids
# repeatedly retargeting filesystem/CLI operations while a path is incomplete.
vault_block = services[services.index("id: todoObsidianVaultPath"):]
vault_block = vault_block[:vault_block.index("StyledText {", 100)]
assert "onEditingFinished:" in vault_block
assert "onTextEdited:" not in vault_block

note_block = services[services.index("id: todoObsidianNotePath"):]
note_block = note_block[:note_block.index("StyledText {", 100)]
assert "onEditingFinished:" in note_block
assert "onTextEdited:" not in note_block

assert "if (root.noteFullPath.length > 0)" in backend
assert "return root.noteFullPath" in backend

print("Todo/Obsidian settings UI contract: PASS")
