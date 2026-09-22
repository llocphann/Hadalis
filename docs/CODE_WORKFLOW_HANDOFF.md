# Code Workflow Phase 0 — completed investigation and online handoff

Updated 2026-09-20. The maintainer explicitly requested **Phase 0 A–E and its
complete evidence**, not the production editor. Refetch current `dev` before
audit and every write, read AGENTS.md, work directly on `dev`, preserve concurrent
work, commit atomic milestones, never mutate `stable`. This handoff is requested.

## Production UI refinement continuation — 2026-09-21

A focused Code Workflow UI pass was applied on current `dev` without changing
the parser/transaction safety model or unrelated shell runtime:

- The existing IR `graph.edges` pipeline remains authoritative. Geometry Shape
  edges now render on a controlled `colLayer0` canvas surface with contrast-safe
  `edgeInk()`, round caps/joins, visible direction arrowheads, hover emphasis and
  matching edge-label ink/borders. No second/fake graph model was introduced.
- Node selected-state text, kind chips and ports now use semantic Material
  foreground/background pairs instead of raw accent-on-accent combinations.
  Long Inspector/source/semantic fields are capped or elided instead of expanding
  the side panel indefinitely.
- Targets now support filtering plus progressive disclosure. Runtime targets retain
  catalog depth, graph nodes expose root/child depth, and parser-derived QML entries
  use semantic scope depth. Anonymous generic visual primitives are hidden by
  default but remain available through search or **Show internals**.
- Parser semantic selection now lives in `CodeWorkflowSession.selectedSemanticAnchor`
  instead of page-local state. Runtime, graph-node and semantic selection share the
  same session boundary; the Targets list reveals the selected item and picker
  selection still commits through `CodeWorkflowSession.selectTarget()`.
- Selecting a parser semantic entry uses its current parser byte range to highlight
  and scroll Source Preview. UTF-8 byte offsets are translated to TextEdit
  positions; reviewed source-needle fallback remains for IR-node selection.
- Runtime and parser capability states are explicit: resident targets report
  `LIVE · RESIDENT`, unloaded targets report `UNLOADED · STATIC SOURCE`, and
  parser `UNAVAILABLE`/`ERROR` state includes the analyzer reason such as
  `grammar-missing`.
- The **Fit graph** control uses actual node/edge bounds instead of the minimum
  pannable world size or one hard-coded pan/zoom tuple. Backward-edge Bézier
  controls are included in the fit bounds, and entering a new subflow schedules
  the same fit.
- Every valid source-backed IR edge is now selectable for inspection. This does
  not widen mutation authority: preview/write affordances remain gated to the
  existing reviewed edge subsets, while ordinary structure/lifecycle/action/data
  edges are labeled `READ ONLY` in Inspector.
- Targets are grouped into non-interactive Runtime, Workflow graph and Parsed QML
  sections after filtering. Semantic selection suppresses stale graph highlights;
  parser READY reconciliation clears a selected semantic anchor if it disappeared
  after source drift.
- **Show internals** and search also expose parser-known `pragma` and `opaque`
  entries as read-only inspect targets. Unsupported semantics remain explicit
  rather than being silently omitted or promoted to editable behavior.
- Edge selection is the primary Inspector object when an edge is selected: the
  header follows the edge label/kind while the destination node/runtime remains
  supporting context.
- Edge geometry uses one authoritative `edgeRoute()` across rendering,
  hit-testing, labels and graph fitting. Separated nodes route left/right,
  horizontally-overlapping nodes route top/bottom, and the reviewed IR currently
  covers both three backward edges and three same-column vertical edges.
- Narrow Settings layouts use a compact toolbar mode: nonessential status pills
  are hidden and toolbar buttons become icon-only while retaining tooltips.
- Source Preview range reveal clamps parser offsets before selection and does not
  move the cursor afterward, preserving the visible selected evidence range.
- Selecting a read-only edge that targets a binding/property node no longer
  inherits that destination node's direct mutation controls. Literal/binding
  preview eligibility is available with no edge selected, or for an explicitly
  reviewed `previewable` edge.
- Compact header buttons retain independent `buttonText` accessibility labels
  when their visual `mainText` collapses to icon-only mode.
- Targets now expose **Connections** and reviewed **Connect candidates** as
  first-class inspect rows instead of leaving those session selections implicit.
  Runtime-root vs graph-node selection is disambiguated so only one row owns the
  primary highlight/reveal at a time.
- Target rows follow the existing Settings keyboard/accessibility convention:
  non-section rows are tab-focusable, Enter/Space and accessibility press use one
  activation path, and visible focus borders distinguish keyboard focus. Graph
  subflow drill-down is a separate keyboard/screen-reader action from node
  selection.
- Edge routing is obstacle-aware. `edgeRoute()` detects unrelated node
  intersections, searches reviewed detour corridors, and all renderer/hit-test/
  fit/label consumers use one cached resolved route. The current IR has two
  crossing cases and both resolve to zero unrelated-node intersections.
  Arrowheads derive orientation from the resolved endpoint tangent rather than
  the original route class, so detoured edges keep correct direction markers.
- Horizontal edge labels cap their width to the actual inter-node gap and elide
  instead of overlapping node cards; hovering the edge reveals the full label.
- Graph zoom bounds now live in `CodeWorkflowSession` (`0.20–2.5`) and are
  shared by restore, Fit graph, wheel and pinch. This lets tall graphs genuinely
  fit smaller Settings viewports instead of being clipped by the old `0.35`
  floor.
- Transaction UI is selection-bound end-to-end. A dirty preview belonging to a
  different inspect object is labeled `OTHER SELECTION` and mutation controls
  stay gated until its target/connection/candidate is re-selected. The
  transaction surface now derives height from visible content, grows from a
  118px floor to a 420px cap, then scrolls longer preparation/lifecycle evidence
  instead of clipping command-specific rows. Undo/Redo/history changes reset the
  transaction scroll to the top of the newly selected command.
- Re-selecting the runtime target for the already-open subflow no longer resets
  pan/zoom to `(0,0,1)`; viewport reset remains limited to an actual subflow
  change, after which the canvas schedules Fit graph.
- Restored semantic inspect state is reconciled with parser readiness: READY
  discloses/reveals the selected semantic row, while parser UNAVAILABLE/ERROR
  clears stale semantic inspection so graph context is not suppressed invisibly.
- Target filtering now preserves the query when selection originates from the
  filtered Targets list; external graph/picker/session selection still clears
  the query when necessary to reveal the newly selected object.
- Edge label hover uses the whole label pill as a stable tooltip surface and
  keeps extra breathing room from endpoint cards. Generic status pills also
  expose their complete unelided label on hover.
- Targets filter and Source Preview have explicit accessibility labels; the
  read-only source TextEdit is keyboard-focusable for selection/copy workflows.
- Graph viewport reveal now treats selected edges as primary objects. Selecting
  a connection reveals/fits its resolved route bounds rather than panning only
  to the destination node; node/edge signal ordering funnels through one primary
  reveal path.
- Source-range regression coverage now includes UTF-8/UTF-16 boundaries for
  Latin-1, CJK and emoji surrogate pairs. Source Preview clears any previous
  evidence selection before resolving the next anchor, avoiding stale highlights
  when the new anchor is absent or non-unique.
- Session restore re-checks the same previewable-edge binding invariant enforced
  by live selection, so persisted workspace state cannot bypass mutation
  selection assumptions after an IR change.

- Static regression contracts in
  `scripts/test-code-workflow-ir-contract.py` and
  `scripts/test-code-workflow-phase1-contract.py` lock the renderer visibility,
  hierarchy/disclosure, unified selection, source-range reveal, fit behavior and
  availability-state semantics.

### Automated live capture bundle

For compositor-qualified review, the repo now includes an opt-in capture runner:

```bash
bash scripts/capture-code-workflow-ui.sh
```

It launches the repo's standalone Settings directly on page 30 with
`QS_CODE_WORKFLOW_CAPTURE=1`, fullscreens only that Settings window on Niri,
then captures deterministic Code Workflow states: overview, real TextField filter
typing/focus traversal when `wtype` is available, obstacle-detoured edge,
read-only edge-to-binding context, Connect candidate, and parser semantic +
Source Preview. It stores PNGs together with per-step IPC state, the selected
Settings window's Niri record, output/workspace metadata, Settings logs, source
snapshots and SHA256 manifests, restores the pre-capture Code Workflow session,
and emits `hadalis-code-workflow-capture-<timestamp>.tar.gz`.

The `codeWorkflowCapture` IPC exists only while the Code Workflow page is
loaded under `QS_CODE_WORKFLOW_CAPTURE=1`. Its harness is contract-checked to
remain read-only and must not call transaction preview/prepare/apply APIs.

The first real Niri capture bundle (`20260921-213435`, 1920×1200) found two
runtime/UI regressions that static token replay had missed:

- `CodeWorkflow.qml` and `CodeWorkflowIrCanvas.qml` used `ColorUtils`
  without importing `qs.modules.common.functions`. The Settings log contained
  hundreds of `ReferenceError: ColorUtils is not defined` entries, causing edge
  strokes/labels and other contrast colors to resolve as undefined and appear
  almost white on the light graph canvas.
- `ToolbarTextField` defaults to `Layout.fillHeight: true`; the Targets
  filter did not override that default. It consumed most of the Targets column,
  leaving the actual inspect list compressed to roughly one row at the bottom.
  The page now pins that field to its 34px toolbar height and gives it a distinct
  layer-2 background.

That capture also confirmed the standalone Settings process had
`grammar-missing` parser capability and `UNLOADED · STATIC SOURCE` runtime
state. Those are recorded as capture-environment capability limits, not treated
as graph-rendering regressions. The runner now emits parser capability and a
focused Code Workflow runtime-warning summary for every future bundle.

The second real capture (`20260921-215123`) confirmed the missing ColorUtils
imports and Targets filter-height fixes were effective: graph edges were visible
again and the Targets list occupied the full panel. It also exposed a separate
text-rasterization problem. The graph world was fitted at roughly 0.64× and all
node/edge text inherited `StyledText`'s `Text.NativeRendering`; native glyph
rasters looked thin/hollow after fractional scene scaling. Graph-local text now
uses a dedicated `GraphText` with `Text.QtRendering`, and graph MaterialSymbol
text also requests Qt rendering. Source Preview uses the same Qt renderer for
cleaner monospace antialiasing without changing the global StyledText policy.

The same capture's only focused Code Workflow runtime warnings were seven
`Unable to assign [undefined] to QString` messages from the inline Pill tooltip.
The Pill had no local id, so `root.label` resolved to the page root rather than
the inline component. It now owns `id: pill`; hover and tooltip bindings target
`pill`/`pill.label`, eliminating the undefined QString path.

The third real capture (`20260921-220357`) confirmed the warning summary was
clean and text rendering had improved, but edge sharpness still varied with zoom.
The overview fit rendered at about 50%, so a 2.4 world-unit stroke became roughly
1.2 screen pixels; the Resources subflow rendered near 128%, making the same
stroke roughly 3.1 screen pixels. Edge rendering now uses
`Shape.CurveRenderer` with antialiasing and computes world stroke width as the
desired screen-space width divided by the current zoom. This preserves the
existing 2.4/3.0/3.6 px visual hierarchy across Fit, manual zoom and subflows
instead of letting transforms make lines alternately faint or heavy.

### Smart-lane routing and resizable workbench panes

The post-capture routing pass deliberately moved away from a single cubic
Bezier for every relation. The design references mature node/workflow editors:
Blender and Unreal both treat rerouting as a first-class way to keep wires away
from graph content; React Flow exposes `smoothstep`/custom edge routing in
addition to Bezier; Node-RED treats resizable side panels as part of the editor
workspace rather than fixed chrome.

Hadalis now uses an automatic `smooth-step-lane-v2` policy without inventing
synthetic semantic nodes:

- Routes are orthogonal lanes rendered as rounded `PathSvg` corners through
  `Shape.CurveRenderer`.
- Candidate scoring is lexicographic in practice: unrelated node collision is
  dominant, then wire crossing, then non-endpoint collinear overlap, then route
  length/bend count.
- Shared source/target endpoint segments are allowed to bundle because the
  reviewed IR is node-level and does not claim Blender/Blueprint-style pin
  semantics that it does not actually have.
- Fan-out lanes are ordered by target position. Horizontal routes preserve a
  target-side label run, and labels prefer the last horizontal segment so dense
  lifecycle fan-outs do not pile all labels on the source trunk.
- Stroke and arrow dimensions remain screen-space stable across zoom.
- Manual reroute handles are intentionally deferred. They would require an
  explicit visual-layout persistence model and, for pin-level behavior, richer
  reviewed IR evidence rather than fabricated sockets.

A deterministic replay of the current 4 graphs / 37 edges reports **0 unrelated
node collisions, 0 wire crossings and 0 non-endpoint overlap**. Current route
complexity is: Bar 18 edges / 11,216 Manhattan units / max 2 bends; Media
6 / 935 / 2; Clock 6 / 957 / 2; Resources 7 / 2,162 / 3. This is static
geometry evidence; live Niri capture remains the visual acceptance gate.

The workbench is also no longer fixed-width chrome. Targets, Graph and Inspector
share a horizontal Qt `SplitView`; the graph/source workspace shares a vertical
`SplitView`. Targets persist at 224px by default (180–420px), Inspector at
280px (240–520px), and Source Preview at 190px (120–420px). Splitter visuals are
6px, expose an 18px invisible edge hit target, show the correct horizontal/
vertical resize cursor, and persist final pane dimensions through
`CodeWorkflowSession`. The capture harness includes a non-default
`pane-resize` state and emits `meta/route-diagnostics.json` for visual review.

The fourth live capture (`20260921-234057`) compositor-qualified the smart-lane
geometry itself: every captured graph reported zero unrelated-node collisions,
zero wire crossings and zero non-endpoint overlap, and the Resources perimeter
route rendered cleanly at ~132% zoom. It also found that pane persistence had
only been added to `CodeWorkflowSession`, not to the typed
`Persistent.states.settings` schema. QML therefore rejected
`codeWorkflowTargetsPaneWidth` repeatedly and the pane-resize capture remained
at 224/280/190. The typed schema now declares all three pane dimensions. Capture
status also records requested *and actual* SplitView geometry, and the warning
extractor now treats `Cannot assign to non-existent property` as a focused Code
Workflow runtime failure so this class of regression cannot be reported clean.

On `2026-09-22`, a follow-up P0 containment pass fixed graph content escaping
the Code Workflow viewport. `CodeWorkflowIrCanvas` now hard-clips its root;
edge hit testing rejects out-of-viewport coordinates; node/subflow pointer
activation maps transformed coordinates back to the canvas; and the old
edge-label `StyledToolTip` was replaced by one canvas-local, viewport-clamped
HUD so tooltip fallback reparenting cannot paint into the toolbar or Source
Preview. The capture harness now includes a deliberate `viewport-boundary`
scenario and records canvas width/height plus pan/zoom state. Static contracts
were updated to lock those invariants. A new live Niri capture is still required
before calling this compositor-qualified.

The same pass refined dense fan-out readability without changing IR semantics:
lane spacing now scales from 8 to 10/12 world units for progressively denser
source fan-outs, while keeping the existing lane cap and scoring order. Selected
and hovered edges also render above sibling wires but below edge labels and
nodes, preserving readable shared endpoint trunks. These changes remain within
the existing `smooth-step-lane-v2` policy; manual reroute semantics are still
deferred.

Graph navigation now supports direct manipulation without changing reviewed IR.
Left-button drag on a node writes only a session-local visual offset keyed by
graph/node ID; the node follows scene-space pointer motion adjusted for current
zoom, receives a small pickup-scale animation, and invalidates the route cache
on each layout revision so connected smart-lane edges reroute live. Dragging
empty canvas space pans the viewport with either left or middle mouse button;
node and edge hit areas are excluded so selection/drag gestures keep priority.
Edge-proximity node drag now auto-pans at a bounded 16ms cadence. Pan deltas are
fed back into the node's world-position calculation, so the grabbed node stays
under the pointer while the viewport moves. Wheel, pinch, empty-space pan and
auto-pan use transient viewport updates during active gestures and commit only
after the gesture/debounce window, avoiding per-frame persistence churn.
The visual offsets survive Settings page eviction through
`CodeWorkflowSession` but intentionally do not mutate source/IR and are not yet
persisted across a full shell restart. The toolbar now exposes `Reset layout`,
enabled only when the current graph has visual offsets; it restores reviewed
positions and re-fits the graph.

The capture harness now snapshots/restores visual layout state and includes a
`node-layout` scenario that moves `clock.hover`, fits the graph and records the
selected node offset plus layout revision alongside route diagnostics. This
qualifies moved-node rendering and automatic rerouting deterministically; real
mouse drag/pan ergonomics still require a live Niri input run before being
called compositor-qualified.

Direct node drag now uses a two-tier routing path during direct manipulation.
The committed `edgeRouteCache` stays stable while a node is held; only edges
touching the active node are recomputed into `dragEdgeRouteCache`, coalesced at
a 16 ms frame cadence. Node position itself still follows pointer samples
immediately. The final visual offset is written to `CodeWorkflowSession` only
when drag ends, then the full smart-lane graph is rebuilt once. This avoids the
old per-pointer full-router + layout-map mutation path that caused visible lag.
Idle graph/node cursors remain `ArrowCursor`; closed-hand feedback appears only
while a pan/node drag is active.

Source Preview has now become a guarded Source Editor. It reuses the production
`org.kde.syntaxhighlighting` backend, keeps per-source draft buffers across
inspect-selection switches, exposes dirty/save/conflict state, and writes only
through an atomic compare-and-swap helper scoped to the Hadalis shell root.
External edits therefore become explicit conflicts instead of silent
overwrites. `Ctrl+S` and Revert stay in the pane header; Save is disabled
while a Code Workflow transaction is dirty.

The Source Editor is intentionally an in-process hot-fix editor rather than a
second full IDE. It has three modes: `NORMAL`, `INSERT`, and `VISUAL`.
Normal/Visual navigation supports `h/j/k/l`, `0`, and `$`; edit entry
supports `i/a/I/A/o/O`; `v` begins character Visual selection; `y` yanks,
`x` deletes a character, Visual `d/x` deletes the selection, Visual `c`
deletes then enters Insert, and `p/P` pastes the internal yank buffer.
Visual yank also copies to the system clipboard, Ctrl+V can paste the system
clipboard, Insert mode preserves native TextEdit clipboard/IME behavior, Escape
returns to Normal, and the gutter shows synchronized line numbers.

This modal surface is deliberately small. It does not implement command-line
editing, macros, named registers, plugins, terminal sessions, multi-buffer
management, or a complete clone of any standalone editor. Its scope is quick
temporary inspection and hot fixes while preserving the existing guarded
source-save lifecycle.


**Supersession note:** the Phase 0 renderer decision and “no production editor
UI” statements later in this document are preserved as historical experiment
evidence. They predate the current scoped Code Workflow implementation above and
must not be read as a description of the current `dev` UI. Their benchmark and
qualification limits still apply to the historical experiments they describe.

This pass intentionally does **not** widen source-write allowlists, transaction
semantics, parser capability, runtime registration scope, or shell-wide inspect
coverage. GitHub connector status queries for these direct `dev` push commits
currently return no exposed status/check records; do not describe that as CI
verified. Live visual acceptance should still be performed in the real Settings
surface on the shipped desktop before treating light/dark rendering and picker
ergonomics as compositor-qualified.

## Decision

**The scoped A–E experiments are complete. Geometry is viable for a read-only
Phase 1 prototype; Curve remains HOLD for sustained memory acceptance.** This is
not a whole-repository PASS, production renderer promotion, 60 FPS claim, or
permission to skip semantic/source-transaction gates. No production editor UI
or source-writing transform was implemented.

| Spike | Final result | Evidence |
| --- | --- | --- |
| A — parser corpus | 1,010/1,010 QML files pass syntax, byte preservation, incremental equivalence and prefix-anchor checks; 16 native regression tests pass. Four collision-bearing files stay read-only. | [Full corpus index](evidence/code-workflow/spike-a.c466de89.json) |
| B — renderer/input | 20 checks per Shape renderer on Niri and native-scale Sway; software fallback also 20. Paired 20/60/100/250-node measurements, QML profiling and two 600-second/40-rebuild soaks complete. Geometry viable; Curve memory HOLD. | [Conclusion and metrics](evidence/code-workflow/spike-b.conclusion.json), [all matrix runs](evidence/code-workflow/spike-b.sway-matrix.2ac7583b.json) |
| C — registry | 10 checks per compositor: semantic/output IDs, allowlisted snapshots, unloaded state, no dormant LazyLoader activation, destruction/rebind. | [Niri](evidence/code-workflow/spike-cde.c466de89.niri.json), [Sway](evidence/code-workflow/spike-cde.c466de89.sway.json) |
| D — picker | 21 Niri / 25 Sway checks: real compositor input, consumed selection click, Settings teardown/restore, hold/cancel/lock signal and two-output scale 1/1.25 lifecycle. | Same CDE reports |
| E — reload | 9 checks per compositor, including three ordinary source-triggered reloads, old-object destruction, new generation, selection/viewport and unloaded-selection persistence. | Same CDE reports |

A and final CDE/canonical validation target committed source
`c466de89581ebf5edf55be47aac3f10709e050a5`. B's controlled matrix targets
`2ac7583bc8c37ce8190992d080ef03bec4ed1df2`; no code-workflow implementation files
changed between these revisions. Every report pins its source and driver hashes.
The outer headless-Niri wrapper was then added and executed successfully; its
[provenance](evidence/code-workflow/spike-cde.c466de89.niri-host.json) hashes the
published wrapper. That wrapper is the only new executable in this final evidence
milestone. No later production changes are implicitly covered by these results.

## B findings and unresolved limits

Incident-only routing replaces global edge invalidation. A 250-node move updates
only its connected paths; pan/zoom does not reroute. Separate QML profiler runs
show mean inclusive setNodePosition time 6.713 to 1.299 ms and endpoint calls
399,475 to 3,160. These are instrumented function observations, not GPU time.
Raw 123/42 MiB traces stay temporary; committed summaries retain their SHA-256,
counts and reproduction instructions in the probe README.

The paired 100-node p95 frame cadence **regresses**: Geometry 18.121 to 23.965 ms,
Curve 21.042 to 23.906 ms. At 250 nodes it improves to 37.885/49.291 ms from
43.085/53.077 ms. This single paired matrix cannot establish a universal winner
or a production node budget. All failed qualification attempts are retained.

Both soaks rebuild 40 times. Geometry ends with 4,213 objects, with second-half
RSS changing by +1,044 KiB. Curve also ends with 4,213 objects, but its second-half
RSS grows +87,824 KiB and whole-run RSS grows +200,744 KiB. Transient 5,643-object
samples coincide with rebuild before deferred deletion; they are not proof of
permanent QObject leakage. Sustained Curve RSS growth is unresolved and blocks
its promotion. It requires allocation profiling, not a relabelled PASS.

The controlled B matrix uses Sway 1.12, Qt 6.11.2, actual OpenGL API, native DPR
1.25 and matched 1532x931 windows. Actual GPU/vendor identity was not captured.
Synthetic touch/pinch does not qualify physical touchpad arbitration; virtual
output lifecycle does not prove physical hotplug or Niri multi-monitor support.
Occasional screenshots/input/static checks overlapped the long soaks: use them
for observed memory/lifetime behavior, not clean comparative frame timings.

## Runtime lessons and qualification corrections

Persist primitive semantic IDs and JSON strings, not old-engine QObject/QJSValue
references. Restore only after PersistentProperties loads. Use object-owned
birth markers and destruction signals because memory addresses can be reused.
Use Config.setNestedValue to keep the fixture's normal JSON mirror consistent.
Keep the virtual input device alive for the complete hover experiment.

Picker surfaces exist only during picking. Wait for Settings teardown, consume
the full click, destroy surfaces, then restore Settings page 2 and custom viewport.
The proven keyboard mode is None with right-click cancel. The protocol checks
individual surface lifetimes, not reused Wayland object numbers. Geometry is
QML-owned/output-local and only the horizontal ii Bar adapter is qualified.
Lock tests drive GlobalStates.screenLocked, not PAM or session-lock security.

One desktop-nested Niri run stopped at the ordinary Media click positive control;
its trace contained pointer motions outside the probe sequence. The unchanged
assertions pass 40/40 when Niri runs in an owned headless Sway, excluding desktop
pointer ingress. Both [rejected attempt](evidence/code-workflow/spike-cde.c466de89.desktop-input-rejected.json)
and qualified result are retained. Do not diagnose a production defect from that
contaminated run. Earlier B failures similarly exposed a half-width cropped/
throttled Niri window and a QtTest DPR adapter error; fixture fixes preserve the
strict visibility/frame-delivery and wheel-pivot assertions.

## Repository gate and next readiness

Canonical local validation at c466de89 is **79 passed, 22 failed, one deferred
Nix check**. At 2ac7583b it was 80/21/1, with all normalized failure bodies
identical to 997caa0f. Concurrent popup work adds
`test-styled-popup-content-contract.py` to the failure labels. No code-workflow
implementation changed in that interval. Read the full logs; this comparison
is not a claim that every old assertion body is unchanged at c466de89.

- [Latest full validator log](evidence/code-workflow/validation.c466de89.txt)
- [Latest label comparison](evidence/code-workflow/validation-comparison.c466de89.json)
- [Prior full validator log](evidence/code-workflow/validation.2ac7583b.txt)
- [Prior normalized comparison](evidence/code-workflow/validation-comparison.2ac7583b.json)

These are **LOCAL VALIDATED** results, not CI VERIFIED. Relevant baseline failures
remain integration blockers. Phase 1 can investigate a read-only Bar projection
with Geometry, semantic resolution and helper packaging; writable transforms
still require diagnostics-aware transactions, conflict handling and minimal
source-patch proofs. Broader hardware/platform qualification remains future work.
No further implementation beyond Phase 0 is part of this handoff.

## Published milestones and files

- A: `1d98e2e7e1d38bcd79c2bb4362f9082c874b8949`.
- A/B sandbox: `2289105d686f38a7a682cef0b781f3bc0ee781c6`.
- C: `dddae31695f1a6d73e4a8025821da68839148c48`.
- D/E: `2171f6d69fe05e4106f79f8a95495c81c39b21f7`.
- CDE state/lifetime qualification: `997caa0f8453bcbc9b4b6fe37f21676185d03845`.
- B incident routing, matrix and profiler tooling: `aa3d12f892718dba43cbc61928cfb039ff168006`.
- B viewport and native fractional input qualification: `2ac7583bc8c37ce8190992d080ef03bec4ed1df2`.
- This final evidence commit is identified by Git history for this file; a commit
  cannot contain its own SHA. Its parent source is c466de89 above.

Implementation is under `scripts/code-workflow/`: parser/corpus, GraphSandbox,
sandbox/matrix/profiler drivers, staged runtime QML and pointer helper. The final
milestone adds `run-headless-niri.py`, updates the probe README and three
`docs/CODE_WORKFLOW_*.md` files, and commits reports/logs/screenshots under
`docs/evidence/code-workflow/`. Reviewed corpus reports split per-file arrays into
hashed chunks; indexes retain all other fields and the original report hash.
No source file under the ChatGPT project's synced sources was edited.

For online continuation, start here on freshly fetched `dev`, then read
[full feasibility](CODE_WORKFLOW_FEASIBILITY.md), [design](CODE_WORKFLOW_EDITOR.md)
and [reproduction commands](../scripts/code-workflow/README.md). All per-run JSON,
corpus records, profiler summaries, inspected screenshots and canonical logs are
on the repository. Large raw profiler traces and verbose runtime logs stay in
local temporary folders; reports retain assertions/snapshots/protocol lifetime
evidence and hashes. An online environment without Wayland may review these
results and run static checks, but cannot claim new live validation. Preserve
negative evidence and do not weaken contracts to improve status.
