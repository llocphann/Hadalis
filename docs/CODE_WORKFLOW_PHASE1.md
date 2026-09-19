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

## Still deliberately unfinished

- production picker and Settings hide/pick/restore;
- parser helper packaging and semantic Workflow IR;
- dynamic binding/event/effect/lifecycle graph construction;
- source patches, Apply, transactions, conflicts or undo/redo;
- Sidebar, Dashboard, Dock, Waffle and shell-wide coverage;
- Curve renderer promotion; memory acceptance remains HOLD.

## Next milestone

Promote the qualified Phase 0 picker into production and connect its semantic
result to CodeWorkflowSession. It must remain per-output, pointer-first,
non-exclusive, consume the selection click, restore Settings and viewport, and
never wake dormant targets. Then package the parser boundary and build the first
real read-only Workflow IR for Bar/Media.

No manual or live smoke result is implied here.
