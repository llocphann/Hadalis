#!/usr/bin/env python3
"""Contract guard for the independent Daily Note Todo backend."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
backend = (ROOT / "services" / "DailyNoteTodoBackend.qml").read_text(encoding="utf-8")
helper = (ROOT / "scripts" / "todo" / "obsidian_daily_todo.py").read_text(encoding="utf-8")
qmldir = (ROOT / "services" / "qmldir").read_text(encoding="utf-8")

for token in (
    'property string folder: "00_Capture/01_Journal"',
    'property string noteFormat: "YYYY/MMMM/DD-MM-YYYY-dddd"',
    'property string plannerHeading: "Tasks"',
    "property int plannerHeadingLevel: 2",
    "property int defaultDurationMinutes: 30",
    'sourceMode: "markdown-note"',
    'Quickshell.shellPath("scripts/todo/obsidian_daily_todo.py")',
    'Qt.formatDate(new Date(), "yyyy-MM-dd")',
    "function addTask(text: string, startTime: string, endTime: string): bool",
    "function toggleTask(taskId: string): bool",
    "function deleteTask(taskId: string): bool",
    "function previewInternal(internalJsonPath: string): bool",
    "function migrateInternal(internalJsonPath: string, expectedInternalSha: string): bool",
    '"preview-migration"',
    '"migrate-internal"',
    "expected-section-sha",
    "root.migrationFinished(success, payload)",
    "root.migrationCommitted(payload)",
):
    assert token in backend, f"Markdown Todo backend lost contract: {token}"

for token in (
    'DEFAULT_FOLDER = "00_Capture/01_Journal"',
    'DEFAULT_FORMAT = "YYYY/MMMM/DD-MM-YYYY-dddd"',
    'DEFAULT_HEADING = "Tasks"',
    "def scan_daily_note(",
    "def add_task(",
    "def toggle_task(",
    "def delete_task(",
    "daily_note_not_found",
    "invalid_planner_section",
):
    assert token in helper, f"Markdown Todo helper lost contract: {token}"

assert "obsidian_tasks.py" not in backend, "Markdown Todo backend must not depend on Tasks plugin bridge"
assert "probe-capabilities" not in backend, "Markdown Todo backend must not probe Obsidian runtime"
assert "DailyNoteTodoBackend 1.0 DailyNoteTodoBackend.qml" in qmldir

print("Markdown Todo backend contract: PASS")
