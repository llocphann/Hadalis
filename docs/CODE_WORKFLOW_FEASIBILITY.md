# Code Workflow Editor: Phase 0 evidence

This records experiments, not production readiness. The editor design is in
[CODE_WORKFLOW_EDITOR.md](CODE_WORKFLOW_EDITOR.md); reproducible probes are in
[scripts/code-workflow](../scripts/code-workflow/README.md).

## Spike A — corpus/range feasibility: pass for continued prototyping

Latest corpus revision: `c257f222c406f33f590f2a419032fa06cda4526e` on `dev`.
Manifest SHA-256: `7f647d1e02c2ab4b93cd896d449e739cbf1512869416ff9b573c6f110529f774`.
The runner reads committed Git objects so subsequent dev/working-tree changes
do not change the evidence. Re-run for any later source revision.

Candidate: tree-sitter-qmljs **0.3.1**, upstream
`de96ed62abded51fcdfcbeaaa120e0dd0d20c697`, released generated C parser/scanner,
libtree-sitter **0.26.9**, Python **3.14.7** standard-library test driver,
Qt **6.11.2**, Linux x86_64. The pinned crate SHA-256 is
`e6ed3a7040df54fed1183801ad482139622bf9b9ec1c5f7ee36c5ece25806c58`.
Two independent temporary builds succeeded without Node.js or Python packages.
Rust's toolchain was unavailable on this host. No dependency was added to Hadalis
installation, startup, package manifests, or Nix support.

| Evidence | Result |
| --- | ---: |
| Tracked QML files / parsed without ERROR or missing nodes | 1,005 / 1,005 |
| Source bytes / CST nodes checked | 12,011,472 / 2,489,238 |
| Comments retained | 11,182 |
| Byte-identical leaf + trivia-gap reconstruction | 1,005 / 1,005 |
| Incremental edit/reparse equals a fresh CST | 1,005 / 1,005 |
| Extraction anchors unchanged after Unicode/comment prefix insertion | 1,005 / 1,005 |
| Native regression tests, including Qt diagnostic oracle | 16 passed |
| Complete corpus run (includes extraction and 3 parses/file) | 89.769 seconds |

Timing is the developer harness wall time, not parser-only throughput or a
runtime latency claim. Fixtures additionally cover an insertion inside an
object, CRLF, BOM, Unicode byte offsets, comments, missing final newline,
malformed syntax/encoding, duplicate anchors, and opaque JavaScript bodies.

Real extraction includes 81,694 bindings, 16,144 property declarations,
6,940 handler candidates, 419 Connections, 840 lifecycle objects, 272 Component
objects, 223 inline component declarations, and 18 explicit Binding objects.
The required Bar/Media, dashboard, overview, SettingsPageHost, NiriService,
ShellEditSession and Waffle files are all included. These are source-backed
syntax candidates, not type-resolved Workflow IR or verified reactive edges.

### Ambiguity and unsupported semantics

All extracted entries remain read-only. The JSON report enumerates each opaque
range and reason; `--inspect PATH` emits complete extraction for a source file.

| Construct | Count | Policy |
| --- | ---: | --- |
| Lowercase/grouped object notation | 760 | Opaque, including its descendants; type/scope disambiguation required |
| Property interceptors/value sources (`Behavior on`, etc.) | 1,932 | Opaque; preserve target and source span |
| Imperative `Qt.binding` | 12 | Opaque script; never relabel as a declarative binding wire |

Repeated opaque `Qt.binding` calls produce anchor collisions in
`MediaControlsWidget.qml`, `OverviewNiriWidget.qml`, and Waffle's
`WindowThumbnail.qml`. They are explicitly flagged non-unique and cannot become
persistent selection IDs. Anonymous object anchors use structural ordinals:
comment/line insertion stability is proven, arbitrary structural edits are not.
Import/type resolution, attached properties, lexical dependency resolution,
signal existence, and robust reconciliation remain future semantic work.

### A useful rejection probe

The design's original valid-corpus requirement for *nested inline declarations*
was impossible: [Qt does not support them](https://doc.qt.io/qt-6/qtqml-documents-definetypes.html).
There are none in the real corpus. It now requires valid inline declarations
and nested Component/Loader boundaries, with a separate negative fixture.

For `Item { component A: Item { component B: Item {} } }`:

- tree-sitter produces a clean CST;
- qmlformat 6.11.2 returns success;
- qmllint 6.11.2 emits `[syntax]` but returns zero;
- QQmlComponent 6.11.2 rejects creation with a nested-inline diagnostic.

The prototype analyzer marks this unsupported construct opaque and reports a
diagnostic. This proves why neither CST success nor validator exit code alone
can authorize a transform. The eventual transaction validator must consume
diagnostics and distinguish syntax acceptance from semantic/runtime validity.

### Decision and remaining gates

Keep tree-sitter-qmljs as the viable **CST/range candidate** for Phase 0. The
probe preserves original source bytes and source slices; it does not serialize
a tree into QML or implement a source-writing transform. The optional native
test dependency is skipped explicitly when unavailable to the normal validator.

Runtime helper language/JSON-lines protocol, packaging across supported install
paths, semantic resolution and source transaction safety are **not proven**.
This is sufficient to continue to independent renderer/input experiments; it
does not select a permanent runtime dependency or authorize production editing.

## Spike B — working sandbox; performance/platform acceptance remains open

The standalone QML canvas uses one Shape with many ShapePaths, explicit graph
coordinates, Pointer Handlers, independent bounding-box/segment wire hit tests,
multi-selection/lasso, a subflow stack and keyboard focus. No shell service or
production UI imports it. Data/binding, event, effect and lifecycle categories
are synthetic Bar/Media-shaped fixtures, not claimed to be resolved source IR.

**18 interaction checks passed** with software rendering offscreen at DPR 1.0
and with CurveRenderer/OpenGL on Wayland at DPR 1.25. They cover node drag,
pan without metadata mutation, pointer-centered wheel zoom, pixel-only scroll,
Ctrl-click selection, Shift-lasso, wire picking/tolerance across zoom, subflow
restoration, arrow/Tab focus, synthetic pinch and stable object counts through
five rebuilds. No QML warnings were emitted. A captured sandbox image was
inspected for actual wire/node rendering.

The probe caught and fixed two integration assumptions: WheelHandler requires
`Mouse | TouchPad` to accept this host's touchpad device, and the canvas must
follow the compositor-granted window size. The QtTest 6.11 wheel adapter uses
device-pixel positions on this host, while QML graph math remains in logical
coordinates; the pivot assertion guards against a future adapter mismatch.

### Short benchmark observations

Host: Qt 6.11.2, Niri/Wayland, OpenGL, one 1920x1200 60 Hz output at compositor
scale 1.0. Each renderer/count combination ran for 4 seconds after 500 ms of
workload warmup. Logical test windows were 1872x1136; all listed nodes were
visible at the end. Both requested Shape renderer variants were actually active.
The workload simultaneously mutates a connected node, pans/zooms, maintains a
multi-selection, updates values and produces 16-event bursts in a 64-entry trace.

| Nodes / wires | QObject + visual tree objects | Geometry frame p50 / p95 (ms) | Curve frame p50 / p95 (ms) |
| --- | ---: | ---: | ---: |
| 20 / 34 | 321 | 13.10 / 22.80 | 12.89 / 22.48 |
| 60 / 114 | 921 | 14.68 / 24.39 | 14.24 / 26.20 |
| 100 / 194 | 1,521 | 15.55 / 25.67 | 15.80 / 29.57 |
| 250 / 715 | 4,213 | 17.20 / 25.74 | 22.39 / 31.23 |

At 250 nodes, model mutation alone reached p95 14 ms (geometry) / 15 ms (curve);
the GUI timer reached p95 19.78 / 27.10 ms. This prototype invalidates every
wire after a layout revision, so targeted edge updates and profiling are the
next useful experiment. The short runs do not establish a node budget or a
winner between renderer variants. `frameSwapped` cadence includes QtTest/Python
scheduling and is not GPU execution time or a full Quickshell profile.

RSS increased by about 13–19 MiB over these short runs despite stable object
counts in the rebuild test. This is not evidence of a leak or evidence of no
leak; a longer steady-state/rebuild soak is still needed. A separate 5-second
60-node Curve run at effective DPR 1.25 had frame p50/p95 14.47/27.32 ms. This
used per-process `QT_SCALE_FACTOR`, not a change to compositor output settings.

Remaining B evidence: actual hardware touchpad arbitration, longer memory and
profiling runs, other supported Qt/driver combinations, and compositor-native
fractional scaling. Offscreen software fallback was tested but does not count
as a geometry-versus-curve comparison. Production renderer selection remains open.

## Repository validation and continuation blockers

The canonical validator was run with Qt 6 tools first on PATH and
`--current-repo --strict-qml`. A clean baseline at
`c257f222c406f33f590f2a419032fa06cda4526e` reports **79 passed, 21 failed,
1 deferred Nix check**. An earlier clean comparison at `bad29812` and the
initial Spike A implementation had exactly the same 21 failure labels.
An initial host probe selected `/usr/bin/qmlformat` 1.0; the comparison above
explicitly selects `/usr/lib/qt6/bin/qmlformat` 6.11.2 instead.

Existing failures include Bar/orientation and connected-surface contracts,
Settings/Screen Edge contracts, documentation drift, missing retired helper
references, optional audio/package contracts and window-preview lifecycle.
The real Qt 6 qmlformat also exits 1 for the baseline
`modules/common/models/LauncherSearchResult.qml` (without a diagnostic), while
Tree-sitter accepts it. This tool disagreement remains a baseline investigation,
not a claim that parser acceptance proves runtime validity. The feasibility
work does not rewrite production behavior or relax these unrelated tests.

The final commit's validator result and complete logs must be reported separately
with its exact SHA. A green parser/input probe never substitutes for that gate.

## Remaining spikes and readiness

| Spike | Evidence status | Next gate |
| --- | --- | --- |
| B — renderer/input | Prototype checks pass; acceptance incomplete | Profile edge invalidation, memory soak, real input/platform matrix |
| C — ii Bar registry | Not started | Real resident/unloaded targets, stable identity, allowlisted snapshots, no forced loading |
| D — picker | Not started | Multi-output lifecycle, presentation hold, Settings restore, click isolation and lock cancellation |
| E — reload/rebind | Not started | Actual QObject destruction/replacement, static fallback and selection survival |

No production Code Workflow UI or source-writing operation is ready. Phase 0
must complete A–E before implementing the first source-writing transform.
This pass stops before live ii Bar instrumentation: B still has the measured
performance/platform gaps above, the existing shell validation baseline is red,
and this host has only one output for the later picker matrix. The next work is
to close B's acceptance gaps and triage that baseline, then run the read-only
registry, picker and real reload/rebind experiments. No synthetic registry or
reload simulation is reported as a pass for C, D or E.
