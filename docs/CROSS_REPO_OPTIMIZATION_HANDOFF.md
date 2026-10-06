# Cross-repo optimization handoff

## 2026-10-06 — Maintainer-scoped Screen Edge analytic renderer

The maintainer explicitly prioritized Screen Edges before Wull and authorized
implementation in two classes: strict-lossless changes, and very small visual
deviation only when it buys a large rendering reduction. This checkpoint is
separate from the generic research-only optimization program.

### Implemented healthy path

- `modules/screenCorners/ScreenEdgeField.frag` +
  `ScreenEdgeField.qml` are the normal physical Screen Edge painter.
- The healthy path is one output-local analytic rounded-box SDF
  `ShaderEffect`: **zero texture samples, zero ShaderEffectSource capture,
  zero blur-pyramid intermediates and zero MultiEffect pass**.
- The accepted historical odd-even `ShapePath` / four-`PathArc` /
  `MultiEffect` renderer remains available only through a lazy
  `ShaderEffect.Error` Loader. It is not constructed on a healthy shader path.
- The exact existing frame insets, Bar-owned edge thickness, radius token,
  reservation windows, mapping/fullscreen lifecycle and click-through ownership
  remain unchanged.
- Shader QColor inputs use Qt's premultiplied representation correctly; no
  second alpha multiplication is applied.
- The inward physical shadow uses a three-band analytic response
  (sharp shoulder / middle rolloff / faint tail) chosen to track the accepted
  Qt 6.11 MultiEffect profile without sampling the blur pyramid.
- Deep workspace fragments are rejected before `length`, `fwidth` and
  `smoothstep`. The guard is geometry-safe and is covered by 50,000
  deterministic randomized cases. At the default 1920x1080 / 10 px frame /
  25 px radius / 15 px shadow geometry, about **92.9% of output pixels** fall
  into that guaranteed deep-interior early-return region. This is a structural
  fragment-work reduction, not a measured whole-GPU speedup percentage.
- The physical shadow work remains disabled when a fullscreen client covers the
  output and in minimal Game Mode, while the FrameWindow mapping lock remains
  intact.
- Screen Edge workspace-Overview support is lazy: bottom/left/right reservations
  no longer instantiate unusable Overview stacks, and a normal horizontal-Bar
  configuration retains no workspace-Overview support stack in Screen Edges.

### QSB source identity

`.github/workflows/screen-edge-shader-bake.yml` builds the shader twice and
requires byte equality between those two same-toolchain outputs. Publication is
fail-closed: it verifies that current `dev` still contains the exact GLSL
source that was baked before updating only
`modules/screenCorners/ScreenEdgeField.frag.qsb`.

The QSB corresponding to the current three-band field was published by commit
`f5e5a2ae232303c5f012ae87463472c362c490fa`. Later commits in this checkpoint
change tests/docs/job dispatch only, not the shader source.

### Validation status

At exact checkpoint `44a1b978c358d05eb3b67e5d9f48647dc415f0d2`,
the repository-wide CI invocation of the canonical validator reported:

- `test-screen-edge-analytic-field-contract.py`: PASS;
- `test-screen-edge-analytic-perceptual.py`: process PASS (owner-session visual
  mode was not enabled by canonical CI, so this is not live visual acceptance);
- `test-screen-edge-shadow-padding-parity.py`: PASS;
- `test-screen-edge-shadow-raster-perceptual.py`: process PASS (same
  owner-session qualification caveat);
- `test-shell-elevation-shadow-contract.py`: PASS;
- `test-shell-surface-contracts.py`: PASS;
- `test-bar-orientation-module-sync.py`: PASS;
- `test-performance-lifecycle.sh`: PASS;
- documentation contracts: PASS.

The same canonical run completed **417 PASS / 11 FAIL / 12 SKIP**. None of the
11 failures were Screen Edge failures; they were existing Abyss/Wull and
MegaQML checks outside this scoped task. Do not present that run as a repository
canonical PASS.

The deterministic local worker has not published analytic Screen Edge receipts:
R63 through R69 remain pending while results stop at R62. Therefore the
authoritative local canonical PASS is **not claimed** for this checkpoint.

### Remaining acceptance boundary

Implementation/source work for this Screen Edge optimization is complete.
Two environment-owned acceptance items remain separate and must not be inferred
from source inspection:

1. run the analytic-vs-pre-cutover owner-session A/B with
   `HADALIS_SCREEN_EDGE_ANALYTIC_PERCEPTUAL=1` and retain the reported
   `global_mae` / edge-band diagnostic; the intended budget is <= 1% global
   normalized mean pixel error;
2. visually verify real Niri/Quickshell idle/maximized/fullscreen,
   top/bottom/left/right Bar ownership, fractional scaling and multi-output
   behavior on the exact runtime SHA.

No whole-Hadalis CPU/GPU/RAM/FPS percentage is claimed without before/after
measurement.


## 2026-10-06 — Screen Edge strict-lossless continuation checkpoint

This section supersedes the earlier full-output analytic-painter implementation
details while preserving the same visual/SDF contract. The maintainer requested
continued Screen Edge optimization with strict-lossless changes preferred and a
visual budget below 1% only where necessary.

### Additional implemented reductions

- **Adaptive four-tile rasterization.** The analytic field is no longer drawn as
  one full-output quad. Four disjoint `ShaderEffect` tiles cover only the
  perimeter region that can produce non-zero pixels; the centre is never
  rasterized. All tiles evaluate the same output-local SDF through `tileRect`.
- **Cheapest-axis partition selection.** The wrapper evaluates horizontal-corner
  and vertical-corner four-tile partitions and selects the smaller raster area
  without adding draw calls. At the default 1920x1080 / 10 px inset / 25 px
  radius / 15 px shadow geometry, the structural fragment-invocation footprint
  is below **9.7% of the output**; at 3840x2160 it is below **4.9%**. These are
  raster-area ratios, not measured GPU speedup percentages.
- The 50,000-case geometry oracle proves every omitted pixel belongs to the
  already-proven transparent deep-interior region. The owner-session
  `test-screen-edge-banded-perceptual.py` separately retains the <=1% global
  normalized-MAE budget for seam/derivative verification.
- **Exact SDF fast paths.** Straight-edge samples skip Euclidean
  `length/sqrt`; a 200,000-case float32 oracle requires bit-identical output
  against the canonical rounded-box formula. Exact outside/inside AA/shadow
  regions also bypass unnecessary smoothstep/composition work.
- **Minimal safe band bounds.** Conservative padding that was not needed by the
  proven SDF/shadow reach was removed; per-side shallow/deep extents retain the
  complete corner/shadow support.
- **Covered-frame sleep.** The physical FrameWindow remains mapped across
  fullscreen as required by the stacking lock, but `updatesEnabled` is false
  while the fullscreen client completely covers it.
- **Transparent reservation sleep.** Bottom/left/right reservation windows
  paint nothing and no longer render-update. The top reservation renders only
  when vertical-Bar workspace-Overview hover support is actually available;
  mapping, exclusive-zone and input-mask state remain independent.
- **Legacy type-graph isolation.** `QtQuick.Shapes` and `QtQuick.Effects`
  moved into `ScreenEdgeLegacyFallback.qml`, loaded by URL only after aggregate
  tiled `ShaderEffect` failure. The healthy ScreenEdges.qml path no longer
  imports or embeds the legacy Shape/MultiEffect graph.
- **Output-targeting allocation removal.** The old
  `Quickshell.screens.filter(...)` temporary result array is replaced by a
  complete-order scan that records only whether any configured output exists.
  A 50,000-case behavior/read-order oracle preserves answers and full screen
  traversal/dependency order.
- **Fallback bridge binding compaction.** The inactive legacy Loader previously
  kept ten value-proxy bindings per output (four insets, radius, padding,
  shadow state/size/color and edge color) resident even though the fallback
  renderer was not loaded. The healthy path now retains only two object
  references (`edgeRoot` + `frameHost`); all fallback value bindings are
  instantiated only after an actual tiled ShaderEffect error. This removes
  **8 resident fallback bindings per output** without changing fallback values
  or visual behavior.

The current analytic QSB containing the exact-SDF fast paths was published by
`f7d8d2d282326c2f906f2c385cca19ee5d1660f2`. Later commits in this
checkpoint change QML partitioning, lifecycle gating, tests and documentation;
they do not change the fragment shader source.

### Scoped validation

At exact runtime/source checkpoint
`254f7d3db6a787d6cdda444c778d3750fd574f83`, the repository-wide CI
invocation of the canonical validator completed **419 PASS / 11 FAIL / 12
SKIP**. The dedicated Nix package workflow for the same exact SHA also
completed successfully. All Screen Edge and connected-perimeter checks relevant to this work
passed, including:

- `test-screen-edge-analytic-field-contract.py`;
- `test-screen-edge-banded-perceptual.py` in its canonical process/skip mode;
- `test-screen-edge-output-targeting.py`;
- `test-screen-edge-shadow-padding-parity.py`;
- `test-shell-elevation-shadow-contract.py`;
- `test-shell-surface-contracts.py`;
- `test-bar-orientation-module-sync.py`;
- `test-performance-lifecycle.sh`;
- `test-perimeter-compatibility-placement-contract.sh`;
- packaging/make contracts and source-tree cleanliness.

The remaining 11 failures are existing Abyss/Wull and MegaQML checks outside
this scoped Screen Edge task. Therefore this is a **scoped Screen Edge
validation checkpoint**, not a repository-wide canonical PASS. The CI host also
lacked `qmlformat`, so the strict parser pass remains unclaimed on this exact
SHA.

The deterministic local worker remains stalled with Screen Edge results ending
at R62 while R63-R69 remain pending. Do not create additional duplicate worker
jobs until that transport/backlog issue is resolved.

### Completion boundary

The current Screen Edge optimization implementation pass is complete through
`254f7d3db6a787d6cdda444c778d3750fd574f83`. No further runtime candidate is
promoted here because remaining ideas either add draw-call complexity, alter
QML reactive topology, or produce only micro-level savings relative to the
already-bounded raster footprint.

Live owner-session acceptance remains separate:

1. run `HADALIS_SCREEN_EDGE_BANDED_PERCEPTUAL=1
   python3 scripts/test-screen-edge-banded-perceptual.py` and retain
   `global_mae`, `edge_mae` and `max_channel_delta`; intended global budget
   is <=1%;
2. run the existing analytic-vs-pre-cutover visual fixture if historical visual
   comparison is still desired;
3. verify real Niri/Quickshell multi-output, fractional scaling, Bar ownership
   and fullscreen transitions.

No whole-Hadalis CPU/GPU/RAM/FPS percentage is claimed without before/after
measurement.
