# Code Workflow Editor — Phase 2 status

Updated 2026-09-20.

Phase 2 now includes a qualified literal-property write path. User-triggered
Apply is enabled only after the same semantic command passes preview, current
pre-Apply diagnostics and exact artifact preparation. Direct-binding preview is
available under Milestone 2J, but direct-binding Apply and every broader write
transform remain disabled.

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

- CodeWorkflowTransaction exposes preApplyDiagnostics and preApplyReady.
  Pre-Apply READY alone does not enable Apply; exact artifacts and the qualified
  lifecycle gate are still required.
- The gate evaluates the active semantic preview command against the analyzer's
  current source identity, never against saved byte ranges.
- READY requires an active non-stale preview, analyzer readiness, matching source
  path/base SHA/stable semantic anchor, resolved current semantic rebind, zero
  current parser diagnostics, resolved candidate semantic rebind, a non-empty
  non-noop candidate SHA, and writable source.
- Package-managed/read-only source is an explicit source-read-only blocker.
- External source change immediately invalidates readiness with preview-stale.
- Undo/Redo restore semantic commands but force a fresh readiness evaluation.
- Settings surfaces PRE-APPLY READY/BLOCKED plus blocker names. READY advances
  the transaction to exact artifact preparation; it is not direct write
  authorization.
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
- Settings exposes Prepare Apply and ARTIFACTS READY. Source QML remains
  unchanged until the separate Apply action introduced by Milestone 2I.
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
- Milestone 2G wires the engine to CodeWorkflowTransaction internally.
  Milestone 2I exposes that already-qualified lifecycle only for an exact,
  identity-matched literal-property transaction.
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
- scripts/test-code-workflow-apply-lifecycle.py guards phase persistence,
  watcher-only reload behavior, semantic rebind, rollback wiring and the
  qualified UI gate.

## Gate 2H — qualified live acceptance

**PASS on c991631a3e7b1e8756d42d1c0656d7026a593035.**

Retained evidence:
docs/evidence/code-workflow/phase2h-apply-lifecycle-c991631a.json

Qualified coverage:

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
- A later automated run proved the production success path and exact rollback
  path. The rollback initially appeared red only because the dev probe counted
  reloadFailed in a generation-local field; transaction evidence already showed
  rollback-complete, a non-empty reload error and verify => base-present.
- The qualifying run then passed all three checks in one retained report:
  successful Apply/reload/rebind, reload-failure exact rollback, and external-edit
  preservation with beginApplyLifecycle() rejected after invalidation.

## Milestone 2I — guarded literal Apply enabled

Implemented:

- CodeWorkflowTransaction.applyEnabled now derives from applyLifecycleReady; it
  is not a generic editor flag.
- applyLifecycleReady requires exact prepared artifacts, Quickshell file
  watching, an idle lifecycle and an active literal-property semantic command
  whose source/base SHA/candidate SHA/anchor/replacement/history index all match
  the persisted Apply handoff.
- beginApplyLifecycle() checks applyEnabled again before spawning commit.py.
- Settings keeps the explicit two-step flow: Prepare Apply first, then Apply.
- The Apply button is visible only for an artifacts-prepared transaction that
  still matches the currently selected semantic node.
- External edits, Undo/Redo/Clear/new preview and selection mismatch cannot
  silently retarget the prepared write. Existing hash/semantic verification and
  exact rollback behavior remain unchanged.
- The prepared artifact manifest still carries applyEnabled=false because an
  artifact file is evidence, not authorization; authorization belongs to the
  live transaction controller.
- scripts/test-code-workflow-apply-enablement.py guards the retained Gate 2H
  evidence, literal-only subset, semantic handoff identity and two-step UI.
- Direct-binding Apply remains disabled; Milestone 2J adds preview-only binding
  transactions without artifact staging or write authorization.

## Milestone 2J — direct binding preview

Implemented:

- A second dry-run transaction subset covers semantic `binding` entries only.
- Current and candidate value kinds are restricted to `identifier` and
  `member_expression`. Calls, binary/conditional expressions, handler/script
  bodies, grouped bindings and opaque contexts remain unsupported.
- The helper still performs exact byte replacement only in memory, reparses the
  full candidate and requires the same stable semantic anchor to remain uniquely
  resolved as a direct binding.
- Binding commands use history kind `direct-binding` and regenerate through the
  same semantic identity rather than saved byte ranges.
- Pre-Apply diagnostics adds `write-subset-not-authorized` for every command
  outside `literal-property`; stageApplyHandoff() independently repeats the
  literal-only check. No direct binding command can stage Apply artifacts.
- Settings exposes identifier/member-expression editing as “Preview binding
  patch” and marks such commands PREVIEW ONLY. Qualified literal Apply remains
  unchanged.
- Native parser regression locks the actual tree-sitter-qmljs kinds used by the
  subset, and scripts/test-code-workflow-binding-preview.py guards exact
  replacement and write isolation.

## Gate 2K-A — source-backed data-edge eligibility

Implemented foundation:

- Reviewed IR edges remain presentation objects by default; an edge ID alone is
  never source identity and never grants mutation authority.
- Only four current ii Bar data edges are marked previewable because their target
  node is a reviewed direct `ui_binding` already inside the 2J parser subset:
  `clock.data.time`, `clock.data.date`, `resources.data.memory` and
  `resources.data.cpu`.
- Each previewable edge records only reviewed evidence:
  `previewTransform=direct-binding-retarget`, its current
  `sourceExpression`, and expected semantic/value kinds. The native analyzer
  must still resolve the target node to a unique semantic binding before any
  candidate can be generated.
- Data edges such as binding -> component are visual propagation edges, not QML
  constructs, and therefore remain non-previewable.
- `media.data.player` is excluded even though the IR node is visually a
  binding: its source is a property declaration initializer, not a `ui_binding`
  accepted by 2J.
- `resources.data.gameMode` is excluded because its current value is a compound
  expression outside the identifier/member-expression subset.
- CodeWorkflowIr now exposes `edgeFor()` and
  `previewableDataEdgesFor()` so later canvas/inspector operations can resolve a
  reviewed edge without scanning arbitrary QML or treating rendered geometry as
  semantic identity.
- No edge is editable, no edge can stage Apply artifacts, and literal-property
  Apply remains the only source-writing transform.

Disconnect remains blocked at this gate. Removing a `ui_binding` is a deletion
transform with different verification semantics: the old semantic anchor is
expected to disappear, the candidate must reparse, and the UI must show the
resulting unbound/default property state. Replacing a binding with `undefined`
is not considered disconnect.

Cycle diagnostics also remain conservative. A path found in the reviewed graph
may block a proposed connection; absence of a reviewed path is not proof that no
QML dependency cycle exists because the current projection is intentionally
incomplete.

## Milestone 2K-B — edge selection and retarget context

Implemented:

- CodeWorkflowSession persists a primitive `selectedEdgeId`; selecting an edge
  resolves through `CodeWorkflowIr.edgeFor()` and selects the edge's reviewed
  binding target node. The analyzer/transaction still use that node's semantic
  anchor as source identity; edge ID remains UI/session identity only.
- Canvas wire picking uses an editor-side distance test over the same cubic
  geometry used for rendering. Twenty line segments approximate the cubic and
  the hit tolerance is `9 / zoom`, keeping roughly constant screen-space
  tolerance.
- Node rectangles are excluded from edge hit testing so node TapHandlers retain
  their normal selection behavior.
- No wide invisible stroke, MouseArea or per-edge input item is added to the
  Shape delegate.
- Only 2K-A previewable edges participate in wire hit testing. A selected edge is
  visually emphasized without changing renderer ownership.
- Keyboard users can select the same inbound previewable connection from the
  Inspector after focusing its binding node; edge interaction is not pointer-only.
- The existing 2J binding field then provides retarget candidate text while the
  selected edge supplies graph context. Retarget remains preview-only and is
  blocked by `write-subset-not-authorized`.
- Selecting a normal node, changing target/subflow, or restoring an invalid edge
  clears edge selection. Only primitive edge ID is persisted.

## Milestone 2K-C — verified Disconnect preview

Implemented:

- Disconnect is available only from a selected 2K-A previewable edge whose
  reviewed `sourceExpression` still exactly equals the analyzer's current
  semantic binding value.
- The transaction resolves the target semantic anchor again and accepts only a
  unique, non-opaque direct `binding` in the existing 2J value-kind subset.
- Disconnect deletes the complete `ui_binding` member only when that member is
  the sole non-whitespace content on its source line. Inline/multi-member line
  deletion fails closed.
- The candidate reparses as a full QML document with zero parser diagnostics;
  the old semantic anchor must resolve as missing. A surviving/ambiguous anchor
  invalidates the candidate.
- Preview reports an empty replacement and explicit
  `resultingState=unbound/default`; it never substitutes `undefined`.
- History uses command kind `disconnect-binding` and regenerates the same
  semantic deletion command against fresh source identity.
- Disconnect is PREVIEW ONLY. The existing pre-Apply
  `write-subset-not-authorized`, literal-only stageApplyHandoff(), and
  literal-only applyCommandMatchesHandoff guards remain intact. Disconnect Apply remains disabled.
- Connect of a previously absent property is still deferred because it requires
  a verified legal insertion point and stronger port/type compatibility.

## Milestone 2K-D — parser-backed Connect insertion proof

Implemented research/proof:

- Connect identity is `parent object anchor + binding name + source expression`.
  There is no target binding anchor before insertion, and no byte offset is
  persisted as command identity.
- Generic semantic extraction now exposes transient `initializer_range` on
  object entries. Stable identity remains the object semantic anchor.
- `scripts/code-workflow/connect.py` is a preview-only parser helper. It
  re-resolves the parent anchor, rejects opaque/non-unique parents and existing
  members, derives the insertion point from the current standalone closing-brace
  line, and preserves the existing direct-member indentation/newline style.
- The first proof intentionally requires an object with resolvable, consistent
  existing direct-member indentation. Empty/inline/inconsistently-indented
  objects fail closed instead of guessing formatting.
- The candidate is reparsed as a complete QML document. The parent anchor must
  survive, and exactly one new same-scope `binding` with the requested name and
  identifier/member-expression value must appear.
- Native Spike A regression covers real tree-sitter-qmljs initializer ranges,
  stable parent rebind and inserted binding extraction.
- The helper emits `commandKind=connect-binding`,
  `applyEnabled=false`, insertion evidence, and never writes source.
- Type compatibility remains UNKNOWN because 2K-D has no QML type resolver.
  UNKNOWN is not permission to connect or Apply.
- Cycle safety remains UNKNOWN because the reviewed IR is incomplete. A known
  reviewed path may later hard-block a candidate; absence of such a path cannot
  qualify it as acyclic.
- This proof is not wired to Settings or CodeWorkflowTransaction. No Connect
  button is exposed and literal-property Apply remains the only source-writing
  transform.

## Milestone 2K-E — reviewed Connect target identity

Implemented foundation:

- Reviewed IR may declare explicit `connectTargets`; these are authored
  descriptors, not inferred ports. The first fixture is
  `clock.connect.rootVisible`, representing an absent root `visible`
  binding with candidate expression `root.showDate`.
- A target carries `parentNodeId`, runtime-relative source path,
  `parentObjectNeedle`, absent `bindingName`, reviewed source expression and
  expected parser kinds. It also carries explicit UNKNOWN type/cycle status.
- The fixture remains `previewable=false` and `editable=false`; descriptor
  presence is identity/evidence only and grants no transaction authority.
- `CodeWorkflowIr.connectTargetsFor()` and `connectTargetFor()` provide
  reviewed lookup without deriving target identity from geometry, labels or
  arbitrary source scanning.
- Analyzer protocol adds `--object-needle` and
  `resolve_reviewed_object_anchor()`. A unique needle such as `id: root`
  resolves to the smallest containing non-opaque semantic `object`, not to the
  id binding itself, and returns the stable parent anchor, scope and transient
  initializer range.
- Native Spike A proves that the reviewed object needle resolves the real parent
  `Item` object and its initializer braces.
- 2K-E deliberately does not wire `connect.py` into
  CodeWorkflowTransaction. No Connect control is exposed, no history command is
  created and no Apply path changes.
- Type/cycle UNKNOWN remain hard blockers to write authorization.


## Milestone 2K-F — deterministic Connect preview coordinator

Implemented research/proof:

- `scripts/code-workflow/connect_preview.py` composes the explicit 2K-E reviewed
  target descriptor with the 2K-D parser-backed insertion helper. It is not wired
  into `CodeWorkflowTransaction` or Settings.
- The resolver request uses the reviewed source path and `parentObjectNeedle`,
  requires one non-opaque parent object of the reviewed semantic kind, and captures
  the current source SHA plus stable parent semantic anchor.
- The second parser request receives a primitive-only handoff: source path, source
  SHA, connect-target ID, stable parent anchor, absent binding name, source
  expression, and reviewed semantic/value kinds. Transient initializer/semantic
  ranges, parser nodes/indices, QObject/QJSValue values and parser objects never
  cross the request boundary.
- `connect.py` re-resolves the parent from the stable anchor, checks the same-SHA
  base, proves the member is still absent, derives formatting from the current
  CST/source, reparses the full candidate, and proves one inserted direct binding.
- The coordinator independently checks source-path/SHA/parent/name/expression
  continuity and requires the inserted semantic/value kinds to match the reviewed
  subset before returning preview.
- TYPE UNKNOWN (`unknown-unresolved`) and CYCLE UNKNOWN
  (`unknown-incomplete-projection`) are preserved exactly. They remain blockers
  to source-write authorization.
- The result is PREVIEW ONLY: `applyEnabled=false`,
  `artifactsStaged=false`, no source write and no production history/UI wiring.
- `test-code-workflow-connect-preview-coordinator.py` locks the two-request
  boundary, primitive handoff, drift rejection and write isolation. When the
  native grammar is available it runs the real coordinator twice and requires
  deterministic semantic anchors, candidate hash and patch.
- Code Workflow acceptance runs this focused native proof before the existing
  literal Apply lifecycle gate; this does not broaden Gate 2H authorization.

## Not implemented yet

- applying direct binding transforms;
- production Connect UI/transaction integration;
- signal/action transforms;
- Connections creation/removal;
- multi-file transactions;
- multi-file rollback/transactions.

## Next gate

The coordinator proof is now the completed 2K-F research gate. The next gate may
integrate `connect-binding` into transaction history as PREVIEW ONLY, add
primitive selected-connect-target session state, and expose an explicit reviewed
Connect Preview control with diagnostics that visibly retain TYPE UNKNOWN,
CYCLE UNKNOWN and PREVIEW ONLY.

Do not open Connect Apply, stage Apply artifacts, mark reviewed connect targets
editable/previewable as mutation authority, or infer compatibility/cycle safety
from labels, runtime values or the incomplete reviewed graph. Connect write
authorization still requires separate type/cycle acceptance gates.
