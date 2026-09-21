#!/usr/bin/env python3
"""Contract guard for the Todo/Obsidian settings surface."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
services = (ROOT / "modules" / "settings" / "ServicesConfig.qml").read_text(encoding="utf-8")
backend = (ROOT / "services" / "ObsidianTodoBackend.qml").read_text(encoding="utf-8")

required_ui = [
    'title: Translation.tr("Todo & Obsidian")',
    'currentValue: Config.options?.todo?.backend ?? "internal"',
    'Config.setNestedValue("todo.backend", newValue)',
    'Config.setNestedValue("todo.obsidian.vaultPath", value)',
    'Config.setNestedValue("todo.obsidian.notePath", value)',
    'Config.setNestedValue("todo.obsidian.preferTasksPlugin", checked)',
    'Config.setNestedValue("todo.obsidian.allowBasicOfflineMutation", checked)',
    '<!-- hadalis:todo:start -->',
    '<!-- hadalis:todo:end -->',
    'Todo.capabilities?.richMutationAvailable === true',
    'Todo.capabilities?.obsidianRunning',
    'Todo.refresh()',
    'Todo.openSource("")',
    'Obsidian 1.13 or newer',
]
for snippet in required_ui:
    assert snippet in services, f"Todo settings UI lost contract: {snippet}"

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
