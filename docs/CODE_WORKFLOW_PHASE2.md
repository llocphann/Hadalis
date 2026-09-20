# Code Workflow Editor — Phase 2 status

Updated 2026-09-20.

Phase 2 now includes a contract-tested atomic writer and production lifecycle
controller, but user-triggered Apply remains disabled. The Settings UI can only
preview and prepare artifacts; applyEnabled is still false.

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
- Milestone 2G extends the same primitive handoff with write/reload/verify/
  rollback phases; no QObject, QJSValue or transient byte range is persisted.
- scripts/test-code-workflow-reload-handoff.py guards reload persistence and
  primitive-only pending identity across the full lifecycle.

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
- Milestone 2G wires the engine to CodeWorkflowTransaction internally while
  keeping Settings unable to invoke the write lifecycle; applyEnabled remains
  false. Contract tests still exercise commit/verify/rollback against temporary
  fixture files in addition to static lifecycle wiring guards.
- scripts/test-code-workflow-atomic-commit-engine.py guards source mode
  preservation, commit/rollback hash checks, external-edit conflict behavior,
  runtime packaging and the production no-Apply boundary.

## Milestone 2G — watcher-driven commit/reload/rollback lifecycle

Implemented:

- CodeWorkflowTransaction now consumes only an artifacts-prepared handoff and
  persists write-issued before spawning commit.py.
- The controller never calls Quickshell.reload(). It relies on Quickshell's
  watched-source reload and observes reloadCompleted/reloadFailed.
- Process death during reload is expected: all recovery identity remains in
  PersistentProperties, and a new generation can resume write-issued,
  waiting-reload, verify, rebind, rollback or failure phases.
- The selected source's own fileChanged event is treated as expected while the
  lifecycle owns that path; concurrent edits are still detected by commit.py
  hash checks and post-reload verify.
- Successful reload requires verify => candidate-present followed by a fresh
  CodeWorkflowAnalyzer semantic-anchor rebind against the candidate SHA.
- Reload failure starts conflict-checked rollback from the exact snapshot.
  Rollback then waits for the watcher-driven reload and verifies base-present.
- Rollback never overwrites a post-Apply external edit because commit.py permits
  rollback only while the live source still equals candidateSha256.
- Undo/Redo/Clear/new preview are blocked while the write lifecycle is active.
- The lifecycle is intentionally not exposed by Settings yet:
  applyEnabled remains false and no Apply button calls beginApplyLifecycle().
- scripts/test-code-workflow-apply-lifecycle.py guards phase persistence,
  watcher-only reload behavior, semantic rebind, rollback wiring and the
  no-user-Apply boundary.

## Gate 2H — automated live acceptance harness ready

Implemented, but **not yet qualified as passing evidence**:

- scripts/code-workflow/run-apply-lifecycle.py stages a committed tree into a
  fresh work directory and launches it under headless Sway with isolated XDG
  paths/private session bus.
- The harness instantiates a dev-only ApplyTarget fixture and invokes the
  production CodeWorkflowAnalyzer and CodeWorkflowTransaction through probe IPC;
  the commit/reload/rollback state machine is not mocked.
- Success case requires an atomic literal Apply, watcher-driven Quickshell reload,
  candidate-present verification and stable semantic-anchor rebind.
- Rollback case proposes a tree-sitter-valid but QML-type-invalid literal so the
  watcher reload should fail; the exact snapshot must then be restored and a
  second watcher reload must verify base-present.
- External-edit case mutates the isolated source after exact artifacts are
  prepared; production handoff must be invalidated and beginApplyLifecycle()
  rejected while the external edit remains intact.
- The driver refuses an existing work directory, requires an explicit grammar
  and Sway executable, and confines its mutable fixture below the staged config.
- The driver is excluded from the installed runtime payload.
- flake.nix exposes devShells.workflow-acceptance from the same packaged runtime
  and QML dependency closures plus Sway/DBus/parser capability. The Nix shell
  also supplies an explicit dbus-run-session binary, dbus-daemon and
  share/dbus-1/session.conf because non-NixOS CI has no /etc/dbus-1/session.conf.
- .github/workflows/code-workflow-acceptance.yml runs the harness headlessly on
  relevant Workflow changes and uploads report/log/state artifacts even on
  failure.
- The first automated run exposed a real parser/transaction boundary defect:
  tree-sitter-qmljs can wrap a QML value in expression_statement. The semantic
  extractor now unwraps only a unique healthy named expression child, preserving
  fail-closed behavior for ambiguous wrappers; literal/member value kinds and
  exact ranges have dedicated regression coverage.
- The next automated run reached a successful atomic candidate write but exposed
  a Quickshell 0.3.1 QFileSystemWatcher ordering race: an atomic rename can
  invalidate the file watch while directoryChanged arrives before fileChanged,
  leaving the transaction at waiting-reload. commit.py now creates and removes a
  hidden sibling after the verified replace so a later directoryChanged drives
  Quickshell's existing content-hash reload path. No manual shell reload call is
  introduced.
- Hosted acceptance forces QT_QUICK_BACKEND=software because Gate 2H validates
  parser/write/watcher/reload semantics, not GPU/OpenGL availability.
- The watcher-qualified run then proved the candidate source reloads, but exposed
  a second lifecycle boundary: PersistentProperties nested in the transaction
  singleton is outside the ShellRoot old/new reload matching tree, so its state
  returned to defaults after generation replacement. Cross-generation state now
  lives in CodeWorkflowReloadBridge, instantiated directly under ShellRoot. The
  bridge persists one primitive JSON string and imports/exports it through the
  transaction singleton; the acceptance ProbeShell uses the same bridge.
- No claim of live acceptance is made until a retained
  apply-lifecycle-report.json records all checks passing.

## Not implemented yet

- retained passing Gate 2H live acceptance evidence and user-triggered Apply UI;
- direct binding transforms;
- connect/disconnect data dependencies;
- signal/action transforms;
- Connections creation/removal;
- multi-file transactions;
- multi-file rollback/transactions.

## Next gate

The next gate is live acceptance of the wired lifecycle against an expendable
literal property: successful watcher reload, semantic rebind, forced reload
failure with exact rollback, and conflict preservation under an external edit.
Only after that lifecycle evidence is captured should applyEnabled become true
and an Apply button be exposed.
