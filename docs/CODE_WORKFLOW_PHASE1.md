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

## Still deliberately unfinished

- production picker live-compositor acceptance on the shipped shell;
- parser helper packaging and semantic Workflow IR;
- dynamic binding/event/effect/lifecycle graph construction;
- source patches, Apply, transactions, conflicts or undo/redo;
- Sidebar, Dashboard, Dock, Waffle and shell-wide coverage;
- Curve renderer promotion; memory acceptance remains HOLD.

## Next milestone

Run the production picker through the same Niri/Sway acceptance ideas proven in
Phase 0, without weakening its contracts. Then package the parser boundary and
build the first real read-only Workflow IR for Bar/Media so graph nodes are
derived from semantics instead of the current fixed read-only projection.

No manual or live smoke result is implied here.
