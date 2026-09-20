# Hadalis Unified Surface U1

Status: **isolated developer PoC only**. Nothing under this directory is imported
by the production Hadalis shell, and the runtime payload explicitly excludes
`scripts/unified-surface`.

## What U1 proves

U1 tests one invariant: an inverted physical-frame field and a moving rounded
popup rectangle form one SDF silhouette without contact-corner objects or
source-specific topology logic.

The shader knows only:

- output-local frame outer/inner rectangles;
- frame radius;
- one popup rectangle/radius;
- a smooth-union radius;
- material color.

It does not know which module produced the rectangle or which contact corner to
draw.

## Build

U1 stores GLSL source and uses Qt Shader Tools only at developer/build time:

```sh
scripts/unified-surface/build-shader.sh
```

The script never installs packages and never downloads anything. Set `QSB` if
the Qt shader baker is not discoverable automatically.

The canonical CI bake uses Ubuntu 24.04's Qt 6 shader baker. Runtime shader
compilation is not part of this architecture.

## Run

This starts a **separate Quickshell config** and does not invoke `inir run`,
`inir restart`, or modify the production shell:

```sh
scripts/unified-surface/run-u1.sh
```

Useful environment controls:

```text
HADALIS_U1_OUTPUT=<output-name>
HADALIS_U1_EDGE=top|bottom|left|right
HADALIS_U1_LAYER=top|overlay
HADALIS_U1_MODE=control|bounded|full
HADALIS_U1_ANIMATE=0|1
HADALIS_U1_REVEAL_CYCLE=0|1
HADALIS_U1_TARGET_HZ=60
HADALIS_U1_BENCHMARK=0|1
```

Geometry overrides are intentionally generic:

```text
HADALIS_U1_EDGE_THICKNESS
HADALIS_U1_OWNER_THICKNESS
HADALIS_U1_FRAME_RADIUS
HADALIS_U1_POPUP_RADIUS
HADALIS_U1_SMOOTH_K
HADALIS_U1_POPUP_WIDTH
HADALIS_U1_POPUP_HEIGHT
HADALIS_U1_ATTACHMENT_DEPTH
HADALIS_U1_COLOR
```

## Benchmark

Run the same motion with three modes:

```sh
HADALIS_U1_MODE=control HADALIS_U1_BENCHMARK=1 scripts/unified-surface/run-u1.sh
HADALIS_U1_MODE=bounded HADALIS_U1_BENCHMARK=1 scripts/unified-surface/run-u1.sh
HADALIS_U1_MODE=full    HADALIS_U1_BENCHMARK=1 scripts/unified-surface/run-u1.sh
```

After warmup the PoC prints one JSON line prefixed
`HADALIS_U1_BENCHMARK` with mean/p50/p95/p99/max frame time and missed-frame
ratio. Set `HADALIS_U1_TARGET_HZ` to the actual monitor refresh rate.

`FrameAnimation` itself keeps a frame loop alive while benchmarking. Idle
redraw behavior must therefore be checked with `HADALIS_U1_BENCHMARK=0` and
`HADALIS_U1_ANIMATE=0`.

## Lifecycle rule

The `PanelWindow` stays `visible: true` for the entire PoC lifetime. Current
Quickshell WlrLayershell destroys its backing window when visibility becomes
false, which would make same-layer stacking tests invalid. U1 toggles only child
rendering state.

Changing the target screen is also a separate lifecycle operation because
Quickshell hides/reshows a live window when its screen changes. Do not use output
migration as an animation path.

## Rejection rules

U1 fails architecturally if it needs any of the following:

- Canvas/contact flares;
- contact-plane or AA compensation offsets in semantic geometry;
- per-module branches;
- manual contact-corner selection;
- a production `ScreenEdges.qml`, Bar, StyledPopup, Sidebar, Dashboard or
  Settings modification;
- runtime shader compilation/download;
- blur used to hide a topology defect.

Blur and production shadow ownership are intentionally out of scope for U1.


## QSB reproducibility

Qt 6.4 QShader package serialization is not byte-deterministic across otherwise
equivalent bakes, so raw `.qsb` SHA equality is deliberately **not** the
correctness gate.

`verify-shader-package.sh` preserves the committed package, performs a fresh
bake, and compares extracted:

- reflection metadata (JSON-normalized);
- SPIR-V 1.0 payload;
- GLSL ES 300 payload;
- GLSL 330 payload.

A package is accepted only when those semantic/executable payloads match.


## Headless control-mode smoke

GitHub-hosted runners expose no DRM render node, so CI cannot honestly validate
ShaderEffect pixels there. The CI smoke therefore uses an owned Sway headless
compositor with the Pixman renderer plus Qt Quick's software backend and launches
U1 in `control` mode.

It still verifies:

- the isolated QML config loads;
- both Top and Overlay layer-shell hosts can map;
- the host remains alive instead of relying on hide/remap;
- a fractional Sway output at scale 1.25 is visible to the test;
- no fatal QML type/reference/syntax errors occur.

This smoke **does not** validate the SDF shader, topology, AA, GPU performance or
Niri stacking. QSB semantic equivalence is checked separately in CI. Actual
pixels are reserved for the live-Niri GPU validator so a missing CI GPU cannot
produce a false renderer failure.
