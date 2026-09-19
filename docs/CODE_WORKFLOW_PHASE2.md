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

## Milestone 2B — semantic preview history and regenerate

Implemented:

- CodeWorkflowTransaction now stores preview commands by semantic identity:
  sourcePath + baseSha256 + semanticAnchor + replacement. Byte ranges remain
  result evidence and are not used as command identity.
- Successful previews append to history and truncate the redo branch after a new
  proposal, matching normal undo/redo semantics.
- Undo can return to the clean/no-preview state; Redo restores a prior semantic
  preview. No history action writes source.
- External source changes mark every matching historical command stale. Showing
  a stale command yields conflict rather than presenting it as current.
- Regenerate re-runs the active semantic command against the analyzer's latest
  source SHA. transaction.py must re-resolve the stable anchor and parse the
  candidate again before the command becomes a fresh preview.
- A successful regeneration replaces the stale history entry instead of adding
  a second logical command.
- The patch drawer exposes Undo, Redo, Regenerate and Clear. It still exposes no
  Apply action and CodeWorkflowTransaction.applyEnabled remains false.
- scripts/test-code-workflow-transaction-history.py guards history/regenerate
  semantics and the no-write boundary.

## Milestone 2C — pre-Apply diagnostics gate

Implemented:

- CodeWorkflowTransaction exposes preApplyDiagnostics and preApplyReady while
  keeping applyEnabled=false.
- The gate evaluates the active semantic preview command against the analyzer's
  current source identity, never against saved byte ranges.
- READY requires an active non-stale preview, analyzer readiness, matching source
  path/base SHA/stable semantic anchor, resolved current semantic rebind, zero
  current parser diagnostics, resolved candidate semantic rebind, a non-empty
  non-noop candidate SHA, and writable source.
- Package-managed/read-only source is an explicit source-read-only blocker.
- External source change immediately invalidates readiness with preview-stale.
- Undo/Redo restore semantic commands but force a fresh readiness evaluation.
- Settings surfaces PRE-APPLY READY/BLOCKED plus blocker names. READY means the
  evidence is sufficient for a future write controller; it does not enable or
  expose Apply.
- scripts/test-code-workflow-preapply-gate.py guards the diagnostic criteria and
  the no-write invariant.

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

The next implementation gate is an atomic one-file Apply controller with a
second/final hash+semantic-anchor check immediately before writing, an exact
rollback snapshot, normal Quickshell watcher reload,
reloadCompleted/reloadFailed observation and semantic target rebind. Apply must
remain disabled until that controller can prove the complete lifecycle; the
write path must consume the same semantic command and never reuse stale byte
ranges from history.
