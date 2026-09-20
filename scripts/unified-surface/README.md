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
draw. The popup rests exactly on the inverted frame's inner boundary; there is
no permanent attachment-depth/contact offset. Effective per-corner popup radii
are derived continuously from each corner's signed distance to the inner frame,
matching Caelestia's inverted-frame `cornerFill` semantics.

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
HADALIS_U1_TRACE_GEOMETRY=0|1
HADALIS_U1_TARGET_HZ=60
HADALIS_U1_BENCHMARK=0|1
```

Geometry overrides are intentionally generic:

```text
HADALIS_U1_EDGE_THICKNESS
HADALIS_U1_OUTER_PADDING
HADALIS_U1_OWNER_THICKNESS
HADALIS_U1_FRAME_RADIUS
HADALIS_U1_POPUP_RADIUS
HADALIS_U1_SMOOTH_K
HADALIS_U1_POPUP_WIDTH
HADALIS_U1_POPUP_HEIGHT
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


## Live nested-Niri GPU validation

Pixel/topology validation must run where a real DRM/GPU render path exists.
`validate-live-niri.py` starts a **new nested Niri instance** inside the current
Wayland session. It never edits or reloads the host Niri configuration.

Quick iteration:

```sh
python3 scripts/unified-surface/validate-live-niri.py
```

Required fractional-scale matrix before U1 can be considered topology-complete:

```sh
python3 scripts/unified-surface/validate-live-niri.py \
  --scales 1 1.25 1.5 1.75 2 \
  --benchmark
```

For each scale the validator tests top/bottom/left/right with synthetic source
positions `0.02`, `0.5`, and `0.98`. The extremes force normal placement
clamping without introducing a topology flag. Every case renders both bounded
and full-output variants, captures the nested output with `grim`, and checks:

- the strong material mask has one dominant connected component;
- bounded and full renderings agree in the bounded material region;
- clamped popup geometry is produced by ordinary placement;
- the renderer receives only generic `sourceT`/rectangle data;
- QML/RHI/shader load errors are absent.

The report records both Niri's fractional output scale and Quickshell's reported
DPR. They are intentionally not assumed to be identical. If they differ, the
bounded-vs-full comparison determines whether the clipping strategy is still
correct rather than adding a one-pixel compensation patch.

`--benchmark` additionally compares control, bounded and full modes using the
existing FrameAnimation instrumentation. Evidence is kept in a fresh
`/tmp/hadalis-u1-live-*` directory unless `--work-dir` is supplied.


## Motion and fullscreen lifecycle gates

The live validator also proves that the unified visual host remains the same
Wayland layer surface while geometry changes. Motion/reveal runs enable
`WAYLAND_DEBUG=client` and require exactly one `get_layer_surface` creation
for the U1 namespace while:

- the synthetic source sweeps from left through center to right;
- captured moving silhouettes remain one dominant connected component;
- reveal traverses hidden/open states;
- geometry trace demonstrates that data changed without remapping the host.

A test-only `FloatingWindow` is created only when
`HADALIS_U1_FULLSCREEN_PROBE=1`. The validator asks the **nested** Niri
instance to fullscreen that window by IPC. It requires:

- the Top U1 host to return with the same material after fullscreen exits;
- the Overlay U1 host to stay visible over fullscreen content;
- exactly one layer-surface creation through each enter/exit sequence.

These probes are isolated to U1 and never modify the production shell or host
Niri configuration. Use `--skip-lifecycle` only for focused topology
iteration; it is not a complete U1 acceptance run.


## Junction morphology correction

The original U1 draft permanently nested the popup into the owner band through
`HADALIS_U1_ATTACHMENT_DEPTH` and used one radius for all four popup corners.
That was not an accurate minimum model of Caelestia.

The corrected model deliberately removes that depth. At rest, the popup edge is
flush with the inverted frame's inner boundary. Reveal translates the complete
rectangle underneath the owner.

The shader now evaluates every popup corner against the same `frameInner` box.
A corner near that boundary continuously reduces toward a 2px minimum radius;
a corner deep inside the workspace keeps the full popup radius. Therefore the
Bar-facing corners and any additional Screen-Edge-facing corners follow live
geometry without `joinTop`, `joinLeft`, module identity or a separately
positioned corner object.


## Diagnostic morphology defaults

The current U1 defaults intentionally exaggerate the contact morphology a little
so junction placement is visually obvious during live validation:

- `HADALIS_U1_POPUP_RADIUS=32` (previously 28);
- `HADALIS_U1_SMOOTH_K=28` (previously 20);
- `HADALIS_U1_FRAME_RADIUS=25` remains unchanged so the physical frame baseline
  is not conflated with the junction experiment.

This is a research/viewability preset, not a production token decision. The
contact shoulder is still produced only by the same SDF field and corner-fill
math. No contact object, semantic offset, join flag or module-specific branch is
introduced. Override either environment variable to compare smaller/larger
morphology with the same shader.


## Production-faithful screen-edge clamp

U1 tangent placement is clamped to `frameInner`, not to the outer output
rectangle. This mirrors production `StyledPopup`, where
`screenMargin = screenEdgeThickness` keeps the popup at the physical Screen
Edge's inner boundary.

The popup's maximum width/height is likewise bounded by the inner workspace.
This matters for the extreme `sourceT=0.02/0.98` cases: those cases now test an
actual adjacent-Screen-Edge junction rather than letting the synthetic popup
underlap all the way to output coordinate zero.


## Padded inverted frame

U1 uses `HADALIS_U1_OUTER_PADDING=50` by default. The outer SDF rectangle
extends 50 logical pixels beyond the output while `frameInner` stays at the
actual Bar/Screen Edge inner boundary.

This mirrors both Caelestia's `BlobInvertedRect { anchors.margins: -50 }` and
Hadalis `ScreenEdges.qml`'s locked `outerPadding: 50`. It prevents the
off-screen outer boundary from artificially limiting the inner-frame smooth-max
radius. The window still clips all drawing to the real output.


## Border-facing reveal compression

During reveal/retract, a popup rectangle temporarily travels inside the inverted
frame's owner band. U1 now applies the same generic border-facing SDF compression
used by Caelestia: proximity to the four `frameInner` sides scales the popup
distance field along the locally facing axis, with the same maximum boost of 3.

At a fully opened resting popup, border proximity is zero, so this does **not**
change the enlarged diagnostic contact corner/shoulder. It only narrows the
smooth-union influence while the popup is hidden or crossing the owner border.

The operation remains topology-neutral: it consumes only `pixel`,
`frameInner`, `popupRect`, and `smoothK`. There is no attachment-edge flag,
contact plane, module name or reveal-specific geometry offset.


## Junction morphology gate

Connectivity alone is not sufficient. A corner/flare can be technically attached
while still being buried underneath the popup, which is the visual failure this
research is trying to eliminate.

The live validator therefore samples the actual rendered material near every
free tangent side of the popup:

- at `0.25 * smoothK` into the popup, the unified field must protrude visibly
  outside the popup side;
- near `0.95 * smoothK`, that protrusion must have tapered back toward the
  ordinary popup side;
- screen-edge-clamped tangent sides are inferred from `frameInner` geometry and
  are not mistaken for a free shoulder.

With the current diagnostic `smoothK=28`, the CPU reference predicts roughly
9 logical pixels of exposed shoulder at the near sample and approximately zero
by the deep sample. The GPU capture, not the reference prediction, is the
acceptance source.

This gate directly rejects the old failure mode where a decorative corner sits
below/behind the popup even though the total mask remains connected.
