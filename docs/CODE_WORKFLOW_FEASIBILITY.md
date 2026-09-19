# Code Workflow Editor: Phase 0 evidence

This records experiments, not production readiness. The editor design is in
[CODE_WORKFLOW_EDITOR.md](CODE_WORKFLOW_EDITOR.md); reproducible probes are in
[scripts/code-workflow](../scripts/code-workflow/README.md).

## Spike A — corpus/range feasibility: pass for continued prototyping

Initial locked corpus revision: `c257f222c406f33f590f2a419032fa06cda4526e` on `dev`.
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

The final A/B publication `2289105d686f38a7a682cef0b781f3bc0ee781c6` was also
checked: 1,006/1,006 QML files (including the sandbox), 12,033,891 source bytes,
2,495,924 CST nodes, and all preservation/incremental/anchor checks passed.
That corpus manifest is `e810b79fc9d7f3b8a4788e5f0d5b84d066cab4e2a80e93f820895b43bcd2719d`.

## Spike B — initial sandbox observations (superseded by final qualification below)

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
follow the compositor-granted window size. The initial QtTest wheel adapter used device-pixel positions. Native fractional
output qualification later rejected that assumption; public QWheelEvent logical
coordinates now pass the unchanged pivot assertion.

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

At this initial checkpoint, longer memory/profiling and native fractional
qualification were still open. The final experiments below close that investigation
with an explicit Curve HOLD. Hardware touchpad and wider driver coverage remain
product integration work. Software fallback is not a Shape renderer comparison.

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

Final C–E implementation validation at
`997caa0f8453bcbc9b4b6fe37f21676185d03845` reports **80 passed, 21 failed,
1 deferred Nix check**. The comparison baseline
`b8ab566d5138d5dbcc18217b956f45f560a45817` has identical totals and all 21 failure
labels. After normalizing temporary directories, two failure bodies differ only
by removal of the same ProbeShell Config warning; fatal counts do not increase.

The [final log](evidence/code-workflow/validation.997caa0f.txt),
[baseline log](evidence/code-workflow/validation.b8ab566d.txt) and
[comparison](evidence/code-workflow/validation-comparison.json) retain exact SHA,
commands, environment and full diagnostics. The current Niri/Sway CDE JSON reports
also pin `997caa0f`. These are local evidence, not CI or a whole-repository PASS.
Later concurrent `dev` changes and the documentation-only evidence publication
are not covered by the tested SHA. A green parser/input/live probe never
substitutes for the repository gate.

## Spike C — actual ii Bar registry: pass for the prototype scope

Ten checks passed with Quickshell 0.3.1 on nested Niri 26.04, using committed
Hadalis source `82774929` and the real BarContent/Media/ClockWidget implementations.
The runner instruments a temporary Git export; no production module imports the
probe. [Machine-readable evidence](evidence/code-workflow/spike-c.niri.json)
pins source revision and probe hashes.

Semantic IDs and output-qualified instance IDs survive actual Media destruction
and recreation. The QObject reference clears on unload and selection becomes
static; recreation gets a different runtime token. Resources remains unloaded.
Twenty repeated snapshots do not activate or read the dormant LazyLoader item.
An explicit property allowlist excludes a private sentinel. Registry targets
are intentional; Settings/picker internals are not recursively discovered.

This runs real Quickshell/layer-shell objects in a private session, not mocked
QObjects, but does not claim the user's installed shell was instrumented.
Audio/system services are intentionally unavailable there; existing Media popup
QQmlListReference and isolation-related warnings are distinct from probe errors.
Picker click delivery and reload persistence are tested in the following spikes.

## Spikes D/E — isolated live runtime feasibility passes

The combined matrix has **40 passing checks on nested Niri 26.04** and
**44 on headless Sway 1.12**, both using actual Quickshell 0.3.1 and actual Hadalis
Bar/Media/Clock/SettingsOverlay components. Source revision and every probe/driver
hash are pinned in the [Niri report](evidence/code-workflow/spike-cde.niri.json)
and [Sway report](evidence/code-workflow/spike-cde.sway.json). These are local
runtime results, not GitHub CI or a whole-shell acceptance claim.

D proves Settings teardown before picking, deepest eligible target selection,
no leaked selection click, a working underlying Media click after picker removal,
Settings page/viewport restoration, hold/release of an existing auto-hide Bar,
right-click cancellation, top/bottom geometry tracking, shell-lock signal
cancellation, and refusal to load a closed Bar. A second simultaneous session is
rejected. Two-output Sway additionally proves selection at real compositor scale
1.25, output removal cancellation, explicit stale selected-output state, and
reconnection to a replacement instance.

The pointer is injected through the compositor's actual virtual-pointer protocol.
Five picker layer-surface lifetimes on Niri and fourteen on Sway were checked in
the Wayland trace: Overlay, full-output anchors, keyboard interactivity None,
no exclusive reservation, and actual destruction before cleanup. Niri's own IPC
also reports the picker on Overlay with keyboard interactivity None.

E performs three actual source-watcher reloads. Two resident reloads preserve
semantic selection and serialized viewport while replacing the QObject; the old
Media destruction is observed. A third reload keeps selected-but-unloaded Media
in static mode, without forcing the dormant LazyLoader. Returning Media then
rebinds the selection. No QObject is persisted across engines.

The final qualified harness restores non-default Settings page 2 and a modified
viewport; E changes pan/zoom/subflow again before reload. Returning constructor
defaults cannot satisfy these checks. QObject memory addresses are diagnostic
only: an allocator reused an address during qualification. A birth marker owned
by the actual Media object, its destruction signal, and the new registry
generation jointly prove replacement even when the address is reused.

The experiment found and corrected three harness/architecture assumptions:

- PersistentProperties cannot safely carry a JS object from the old QQmlEngine;
  serialize metadata to primitive strings and restore after its loaded signal.
- Fixture changes must use the normal mirror-aware Config API. Direct adapter
  assignments can be overwritten by pending writes and produce false positives.
- A headless input device must remain alive during a hover/hold experiment;
  destroying the last virtual pointer generates leave independently of picking.

Limits: the lock case injects the real shell lock-state signal; it does not test
PAM authentication or compositor session-lock security. Physical hotplug and
Niri multi-output are not claimed. Geometry currently covers the horizontal ii
Bar and its modules only. Ephemeral popups are excluded; the real-click positive
control's popup is reset before the independent hold case. Initial Settings page
0 may leave its published page field at -1, so the adapter reads the actual
SettingsOverlay page. Existing Settings ColorUtils/Translation and Media
QQmlListReference warnings remain baseline issues, separate from the probe.

The concurrent `b8ab566d` fix for generated-only imports is preserved, including
its regression coverage. ProbeShell's module import is injected only into the
staged runtime. No production shell file imports the registry or picker.

## Final qualification — 2026-09-20

A revalidation on c466de89581ebf5edf55be47aac3f10709e050a5 passes all four corpus
checks for 1,010 files, 12,054,434 bytes and 2,500,520 CST nodes. The
[full index](evidence/code-workflow/spike-a.c466de89.json) includes grammar pins,
manifest, semantics limits and hashed per-file chunks. Four files with anchor
collisions remain read-only. Native regressions remain 16 passed.

B now has 20 input checks per renderer on Niri and native DPR 1.25 Sway, plus
20 software-fallback checks. The [complete controlled matrix](evidence/code-workflow/spike-b.sway-matrix.2ac7583b.json)
pins 2ac7583bc8c37ce8190992d080ef03bec4ed1df2, Qt 6.11.2, Sway 1.12,
OpenGL API, matched 1532x931 windows and actual Shape renderer. Baseline QML is
7387ef0a26081d56df816369d4d9d74fedbe2324, replayed with the same current harness.
Each paired case runs 8 seconds after 2 seconds warmup; all 16 cases are retained.

| Nodes | Geometry frame p95, baseline → candidate (ms) | Curve frame p95 (ms) |
| --- | ---: | ---: |
| 20 | 29.589 → 29.359 | 31.228 → 29.429 |
| 60 | 25.122 → 25.336 | 25.266 → 24.488 |
| 100 | 18.121 → 23.965 | 21.042 → 23.906 |
| 250 | 43.085 → 37.885 | 53.077 → 49.291 |

The 100-node regression is real in this retained paired observation. No universal
speedup, FPS target or node budget follows from one short paired run. Model-update
p95 at 250 nodes improves 13/14 to 7/7 ms. The per-node adjacency index updates only
incident ShapePaths after both node coordinates change; view transforms do not
reroute. A separate instrumented QML profile records mean setNodePosition
6.713 to 1.299 ms and endpoint calls 399,475 to 3,160. Committed
[baseline](evidence/code-workflow/spike-b.profile-baseline.json) and
[candidate](evidence/code-workflow/spike-b.profile-candidate.json) summaries pin
raw trace hashes and inclusive counts/times. Nested inclusive time is not GPU or
wall time; large raw traces stay temporary and can be reproduced with the README.

Both 250-node soaks run 600 seconds after 20 seconds warmup and rebuild 40 times.
Geometry second-half RSS changes +1,044 KiB with stable 4,213 sampled/final objects.
Curve second-half RSS grows +87,824 KiB; full-run growth is +200,744 KiB. Its final
object count is also 4,213; transient 5,643 samples coincide with rebuild before
deferred destruction. This does not diagnose a leak, but **Curve sustained-memory
acceptance is HOLD**. Geometry is the viable next prototype path within the
observed window. [Machine-readable conclusion](evidence/code-workflow/spike-b.conclusion.json)
retains all derived metrics and limits. Inspected
[Geometry](evidence/code-workflow/spike-b.geometry-soak.png) and
[Curve](evidence/code-workflow/spike-b.curve-soak.png) screenshots show actual
rendering; thin Geometry wires alias at the dense zoom level. They do not certify
production layout or legibility.

Rejected B runs are preserved: [cropped/throttled Niri](evidence/code-workflow/spike-b.niri-rejected.json)
and [native DPR wheel adapter failure](evidence/code-workflow/spike-b.scale-adapter-rejected.json).
The matrix now requires all benchmark nodes visible and minimum frame delivery;
Niri maximizes its own window. Wheel dispatch now uses logical coordinates.
Assertions were not weakened. Actual GPU/vendor identity was not captured;
physical touchpad, physical hotplug and wider Qt/driver combinations remain open.
Occasional screenshot/input/static work overlapped soaks, so their frame cadence
is not clean comparative timing. Timing buffers and traces have bounded storage.

CDE was revalidated against c466de89: **Niri 40/40, Sway 44/44**. The
[Niri](evidence/code-workflow/spike-cde.c466de89.niri.json) and
[Sway](evidence/code-workflow/spike-cde.c466de89.sway.json) reports supersede the
997caa0f source result for these scopes. A desktop-nested Niri click-control run
was contaminated by out-of-sequence pointer motions and is retained separately.
The unchanged probe passes in Niri hosted by an owned headless Sway, with
[wrapper provenance](evidence/code-workflow/spike-cde.c466de89.niri-host.json).
The existing lock, geometry, popup and hardware scope limits still apply.

Latest canonical validation at c466de89 is **79 passed / 22 failed / 1 deferred
Nix check**. Concurrent popup work adds the styled-popup-content regression label
to the earlier 80/21/1 baseline; no code-workflow implementation changed between
2ac7583b and c466de89. [Full latest log](evidence/code-workflow/validation.c466de89.txt)
and [comparison](evidence/code-workflow/validation-comparison.c466de89.json) retain
diagnostics and exact source. Local results are not CI VERIFIED or a whole-repo PASS.

## Phase 0 exit and next readiness

The scoped A–E investigation is complete, including negative results. A/C/D/E
pass their prototype contracts; B establishes Geometry feasibility and leaves
Curve on HOLD. This is a constrained path to a read-only Phase 1 Bar projection,
not production UI or writable transforms. Semantic resolution, helper packaging,
diagnostics-aware transactions and relevant repository baseline failures remain
next gates. The maintainer requested Phase 0 only. See
[the complete handoff](CODE_WORKFLOW_HANDOFF.md) for public milestone SHAs,
all evidence, reproduction and continuation constraints.
