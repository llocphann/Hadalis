# Code Workflow Editor — Phase 1 status

Updated 2026-09-20.

Phase 0 A–E is complete. Phase 1 has started with the first production read-only
live workflow foundation. This milestone promotes only contracts already
qualified by Phase 0 and does not introduce source writes.

## Milestone 1 implemented

- Settings -> Reference -> Code Workflow is appended at page index 30, before
  Shortcuts, without renumbering historical pages.
- Settings arrangement schema v6 migrates saved custom layouts so the new page
  follows the user's Reference-like group instead of falling into More.
- CodeWorkflowSession owns primitive selection/output/viewport/source-preview
  state outside the lazy Settings page and persists it through Persistent.
- CodeWorkflowRuntime exposes a semantic allowlist for horizontal ii Bar, Media,
  Clock and Resources. It never recursively walks the QObject tree.
- CodeWorkflowRuntimeTarget promotes the Phase 0 output-local horizontal-Bar
  geometry adapter and allowlisted runtime values.
- Bar/Media/Clock/Resources register from production QML.
- The Code Workflow page has a Geometry read-only graph, Targets, Inspector and
  read-only Source Preview.
- Standalone Settings naturally degrades to static source records because it has
  no main-shell runtime registrations.
- scripts/test-code-workflow-phase1-contract.py guards the foundation without
  depending on live desktop smoke tests.

## Milestone 2 implemented

- CodeWorkflowPicker promotes the Phase 0 picker state machine into production.
- Both Settings overlay chromes report their real _panelLoaded lifecycle through
  CodeWorkflowPickerHost; picker surfaces are not created until Settings input
  has fully torn down.
- One full-output Overlay-layer surface is created per output only while picking.
  Keyboard interactivity remains None, right-click cancels, and every click is
  consumed before picker surfaces are removed.
- Hit testing uses only registered CodeWorkflowRuntime targets and chooses the
  deepest/smallest eligible semantic target.
- An already-visible Bar can be held through auto-hide while picking; the picker
  never wakes a closed Bar or dormant target.
- Selection is committed only after picker surfaces are destroyed and the saved
  Settings page plus graph viewport have been restored.
- Screen lock or removal of an original output cancels the session.
- Standalone Settings keeps the picker disabled until a future cross-process
  runtime bridge exists.
- scripts/test-code-workflow-picker-contract.py statically guards these lifecycle
  rules. Production live compositor acceptance remains to be run on a desktop.

## Milestone 3 implemented

- defaults/code-workflow-ir.json is a versioned, read-only semantic projection
  manifest for Bar, Media, Clock and Resources.
- The projection covers component, service, binding, event, action and lifecycle
  node kinds plus structural/data/event/action/lifecycle edges.
- Every projected node carries a sourcePath + reviewed sourceNeedle and
  editable=false. The contract test rejects stale anchors and invalid endpoints.
- CodeWorkflowIr loads the manifest as data; it does not regex-parse QML and does
  not claim source ranges that only the parser/CST layer can provide.
- CodeWorkflowSession now persists subflowTargetId + selectedNodeId. Picking or
  choosing Media/Clock/Resources opens that semantic subflow directly.
- CodeWorkflowIrCanvas renders nodes and wires from the IR with GeometryRenderer.
  The previous fixed Bar -> Media/Clock/Resources graph is gone.
- Inspector and Source Preview follow the selected semantic node; reviewed source
  anchors are highlighted as evidence.
- scripts/test-code-workflow-ir-contract.py validates manifest schema, source
  anchors, edge endpoints, read-only status, kind coverage and graph integration.

## Milestone 4 implemented

- scripts/code-workflow/analyze.py defines parser protocol v1 for one tracked
  QML source at a time. Requests are confined to the active shell/runtime root.
- The analyzer uses only Python stdlib plus the Tree-sitter public C API adapter;
  it performs no download, package install, compiler invocation or source write.
- Missing grammar/libtree-sitter is an explicit `unavailable` result, not a
  regex fallback. Reviewed semantic IR remains usable while parser capability is
  absent.
- CodeWorkflowAnalyzer runs only when the Code Workflow page requests analysis,
  queues source changes, parses JSON output, and exposes diagnostics/status.
- The Inspector reports parser readiness and diagnostics for the selected source.
- Installed runtime payload now keeps only analyze.py/native.py/semantics.py from
  scripts/code-workflow; Phase 0 renderer/compositor/profiler harnesses are
  excluded.
- scripts/test-code-workflow-parser-boundary.py guards confinement, no-network/
  no-build behavior, unavailable semantics, runtime payload policy and QML wiring.

## Milestone 5 implemented

- distro/arch/inir-workflow-parser packages the pinned qmljs 0.3.1 generated
  parser/scanner as an architecture-specific optional capability.
- The package installs only qmljs.so plus the upstream MIT license and depends on
  the system tree-sitter library; Node/npm/tree-sitter-cli are not runtime
  dependencies.
- Analyzer discovery is explicit/env grammar first, then runtime-local grammar,
  then /usr/lib/inir/code-workflow/qmljs.so.
- inir-shell-git advertises the parser through optdepends; the source-install
  dependency tracker records it as optional.
- Stable inir-shell intentionally does not advertise the parser yet because its
  pinned source snapshot predates CodeWorkflowAnalyzer; the contract enforces
  that source/capability identity boundary.
- The shell payload remains architecture-neutral and works without the parser.

## Milestone 6 implemented

- Every reviewed Phase 1 sourceNeedle is now contractually unique in its source
  file; the three ambiguous Bar/Media/Resources anchors were tightened before
  parser ranges were trusted.
- analyze.py accepts one reviewed --needle and, after a successful native parse,
  resolves it only when exactly one byte occurrence exists.
- The analyzer returns transient needle byte/point ranges, the smallest enclosing
  named CST node, and the smallest enclosing extracted semantic entry when one
  exists. Missing or ambiguous anchors stay explicit and unresolved.
- CodeWorkflowAnalyzer includes sourceNeedle in its cache/queue identity, so
  selecting two nodes in the same file cannot reuse stale range evidence.
- Inspector exposes CST evidence for the selected reviewed IR node. The manifest
  itself still stores no sourceRange; range evidence is recomputed from current
  source and is never persisted as editor state.
- Source Preview highlighting also refuses ambiguous needles even when the native
  parser capability is unavailable.
- No source-writing path, patch generation, Apply action or editability flag was
  introduced.

## Milestone 7 implemented

- nix/workflow-parser.nix packages the same pinned qmljs 0.3.1 generated C
  parser/scanner used by the Arch capability boundary.
- The default Nix Hadalis package remains parser-free through
  withWorkflowParser=false.
- The flake exports inir-workflow-parser and inir-with-workflow-parser; the
  latter wraps the launcher with immutable grammar and libtree-sitter store
  paths, so child analyzer processes inherit both paths.
- NixOS/Home Manager need no new mutable service option: users opt in by
  overriding programs.inir.package to the parser-capable flake package.
- Nix CI builds the parser-capable variant in addition to the default package.
- No Node/npm/tree-sitter-cli or runtime grammar generation is introduced.

## Still deliberately unfinished

- production picker live-compositor acceptance on the shipped shell;
- stable-source promotion of the Arch parser optdepend;
- generic semantic extraction beyond the reviewed ii Bar projection;
- persistent/stable semantic anchors for future source-writing transforms;
- source patches, Apply, transactions, conflicts or undo/redo;
- Sidebar, Dashboard, Dock, Waffle and shell-wide coverage;
- Curve renderer promotion; memory acceptance remains HOLD.

## Next milestone

Run the production picker through the same Niri/Sway acceptance ideas proven in
Phase 0, without weakening its contracts. In parallel, expand semantic extraction
only where QML constructs can be represented honestly; unsupported constructs
remain opaque. Nix-native parser packaging can follow the same optional-capability
boundary.

No manual or live smoke result is implied here.
