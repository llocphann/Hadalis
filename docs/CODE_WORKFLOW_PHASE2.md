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

## Milestone 2D — reload-stable transaction handoff

Implemented:

- CodeWorkflowTransaction now has a stable reloadableId and owns a
  PersistentProperties handoff object.
- Semantic preview history is serialized as a JSON string plus primitive index
  so Undo/Redo context can survive a normal Quickshell config reload.
- Restore parses history defensively, clamps historyIndex and reconstructs the
  active preview presentation from the semantic command rather than a QObject.
- stageApplyHandoff() is available only when preApplyReady is true. It records
  only primitive command identity: source path, base/candidate SHA, semantic
  anchor, replacement and history index.
- No transient parser byte range, runtime QObject or QJSValue is stored in the
  reload handoff.
- pendingApplyPhase is only "idle" or "prepared" in this milestone. There is no
  write-issued/waiting-reload state yet because source writes remain disabled.
- scripts/test-code-workflow-reload-handoff.py guards reload persistence,
  primitive-only pending identity and the no-write boundary.

## Milestone 2E — exact Apply preparation artifacts

Implemented:

- scripts/code-workflow/apply.py re-validates the same literal-property semantic
  command against current source, parser diagnostics, stable anchor and expected
  candidate SHA.
- Preparation still does not modify tracked QML source.
- A successful preparation writes three private mode-0600 files beneath the
  Quickshell state directory: snapshot.qml, candidate.qml and manifest.json.
- snapshot.qml is the exact current/base bytes for rollback; candidate.qml is the
  exact fully re-parsed candidate; manifest.json records only primitive semantic
  identity, hashes and artifact paths.
- The artifact transaction ID is deterministic from source path, base/candidate
  SHA, semantic anchor and replacement.
- CodeWorkflowTransaction upgrades pendingApplyPhase from prepared to
  artifacts-prepared only when the helper response exactly matches the staged
  path/base SHA/candidate SHA/semantic anchor.
- Source change, Clear, Undo, Redo or a new preview invalidates any prepared
  handoff/artifact state before another command can be staged.
- Settings exposes Prepare Apply and ARTIFACTS READY, while explicitly stating
  that source QML remains unchanged. applyEnabled is still false and there is no
  Apply action.
- scripts/test-code-workflow-apply-preparation.py verifies exact artifact bytes,
  private permissions, source immutability, runtime packaging and no-write UI
  boundaries.

## Milestone 2F — isolated atomic commit engine

Implemented:

- scripts/code-workflow/commit.py consumes only a prepared manifest and keeps
  source commit mechanics separate from parser/semantic preparation.
- commit verifies snapshot/candidate artifact paths and hashes, confines the
  manifest sourcePath to the active runtime root, checks writability and requires
  the live source SHA to equal the prepared base SHA.
- A same-directory temporary file is fully written/fsynced, inherits the source
  mode, and the source SHA is checked again immediately before os.replace().
- The parent directory is fsynced after replacement and the resulting source SHA
  must equal the prepared candidate SHA.
- rollback uses the exact snapshot artifact and is allowed only when the live
  source still equals the candidate SHA. Any external edit after Apply therefore
  blocks rollback instead of being overwritten.
- verify distinguishes candidate-present, base-present and diverged without
  modifying the source.
- The engine is not wired to CodeWorkflowTransaction or Settings yet;
  applyEnabled remains false. Contract tests exercise commit/verify/rollback only
  against temporary fixture files.
- scripts/test-code-workflow-atomic-commit-engine.py guards source mode
  preservation, commit/rollback hash checks, external-edit conflict behavior,
  runtime packaging and the production no-Apply boundary.

## Not implemented yet

- production source writes or Apply UI;
- QML lifecycle wiring for the isolated commit engine;
- direct binding transforms;
- connect/disconnect data dependencies;
- signal/action transforms;
- Connections creation/removal;
- multi-file transactions;
- rollback after reload failure.

## Next gate

The next implementation gate is production lifecycle wiring for the isolated
commit engine. CodeWorkflowTransaction must consume only an artifacts-prepared
handoff, set write-issued before spawning commit.py, never issue a second manual
reload, survive the watcher-driven reload through PersistentProperties, observe
reloadCompleted/reloadFailed, verify candidate-present after success, rebind the
semantic anchor, and invoke conflict-checked rollback on reload failure. Only
after that complete lifecycle passes contracts may Apply become enabled.
