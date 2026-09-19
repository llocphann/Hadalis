# Code Workflow Editor — Phase 2 status

Updated 2026-09-20.

Phase 2 has started with a deliberately non-writing transaction preview
foundation. No Apply/source-write path exists in this milestone.

## Milestone 2A — literal property dry-run preview

Implemented:

- CodeWorkflowTransaction is a singleton outside the lazy Settings page.
- transaction.py takes source path, analyzer base SHA, stable semantic anchor and
  a proposed replacement, but never writes the source file.
- The first supported transform is intentionally narrow: a unique, non-opaque
  semantic `property` whose current CST value kind is one of
  `true`, `false`, `number` or `string`.
- Base SHA is checked before parsing. A changed source returns `conflict`.
- The semantic anchor is re-resolved against current source before patching.
- Only the exact semantic `value_range` is replaced in memory.
- The entire candidate source is parsed again. The same semantic anchor must
  remain unique and the resulting value must still be in the literal subset.
- Preview returns old/new text, byte range, line, before/after SHA and source
  writability. `applyEnabled` is explicitly false.
- Source Preview watches external changes and marks an existing preview as
  conflicted so stale preview evidence is never presented as current.
- Settings shows a compact literal input only when the selected reviewed node is
  backed by an eligible literal property; the bottom drawer shows a dry-run patch
  preview with no Apply action.
- scripts/test-code-workflow-transaction-preview.py guards minimal replacement,
  SHA conflicts, unsupported binding/expression rejection, no-write behavior and
  runtime packaging.

## Not implemented yet

- source writes or Apply;
- undo/redo command history;
- direct binding transforms;
- connect/disconnect data dependencies;
- signal/action transforms;
- Connections creation/removal;
- multi-file transactions;
- rollback after reload failure.

## Next gate

Before enabling any source write, add transaction command history and a
diagnostics/patch model that can rebase or explicitly reject a preview after
external source changes. Then add an atomic one-file Apply path with pre-write
hash verification, parser validation, normal Quickshell watcher reload,
reloadCompleted/reloadFailed observation and semantic target rebind.
