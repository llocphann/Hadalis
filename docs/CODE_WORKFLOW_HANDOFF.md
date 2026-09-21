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
- Edge geometry is direction-aware. The reviewed IR currently contains backward
  edges in Media and Resources; renderer endpoints, cubic controls, hit-testing,
  arrowheads and labels now use the same left/right routing convention.
- Narrow Settings layouts use a compact toolbar mode: nonessential status pills
  are hidden and toolbar buttons become icon-only while retaining tooltips.
- Source Preview range reveal clamps parser offsets before selection and does not
  move the cursor afterward, preserving the visible selected evidence range.

- Static regression contracts in
  `scripts/test-code-workflow-ir-contract.py` and
  `scripts/test-code-workflow-phase1-contract.py` lock the renderer visibility,
  hierarchy/disclosure, unified selection, source-range reveal, fit behavior and
  availability-state semantics.

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
