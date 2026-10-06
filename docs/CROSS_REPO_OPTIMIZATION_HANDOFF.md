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
