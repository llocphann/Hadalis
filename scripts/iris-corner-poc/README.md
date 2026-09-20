# iRiS Corner PoC for Hadalis ii

Developer-only visual research. This directory is excluded from the installed
Hadalis runtime and **does not modify ii production surfaces or Waffle**.

## Reference implementation

The field shader source and compiled QSB in this directory are copied from:

- upstream: `snowarch/iNiR`
- release: `v2.31.0`
- commit: `9574fa424c0d1008e927454e933a7fbe292f9fb2`
- source: `modules/iris/field/IrisField.frag`
- QSB upstream Git blob: `1dc24922099d00d255b8e78c234d889f7220e616`
- license: GPL-3.0

Hadalis is also GPL-3.0. The QML wrapper/harness is a reduced Hadalis research
adaptation; the shader source and QSB are kept verbatim so the first visual test
uses iRiS's actual field math rather than a reimplementation.

## What is being tested

The PoC has exactly two field bodies:

```text
owner
popup -> joins: "owner"
```

The upstream shader evaluates rounded-box SDFs, keeps the plain union, then adds
a polynomial smooth-union fillet only for explicit joins.

Two geometry modes are intentionally kept separate:

### `card-owner` (default)

This is the relevant analogue for Hadalis `StyledPopup`.

It follows the settled iRiS Control Center/Card pattern:

- popup semantic/body rect stays intact;
- placement overlaps the owner by a small `weld`;
- popup declares `joins: "owner"`;
- popup supplies a deep `fuse`;
- no corner helper, flare, sink or contact-plane offset exists.

### `edge-reach`

This reproduces the different `IrisStage.meltInto()` rule used by pieces that
attach directly to a screen/frame edge:

```text
reach = min(width, height) / 2 + 1
```

Only the field rect is grown into the owner. The cyan guide remains the semantic
popup rect so this hidden extent is obvious.

Do **not** use this mode as evidence that a Bar popup should use edge-piece
geometry; it exists to prevent conflating the two upstream mechanisms.

## Run

```sh
scripts/iris-corner-poc/run.sh
```

Defaults are deliberately exaggerated for visual inspection:

- yellow unified field;
- cyan semantic popup outline;
- magenta owner seam;
- popup radius 48 px;
- fuse 56 px;
- profile `diagnostic`.

Useful overrides:

```sh
HADALIS_IRIS_POC_EDGE=top|bottom|left|right \
HADALIS_IRIS_POC_MODE=card-owner|edge-reach \
HADALIS_IRIS_POC_PROFILE=diagnostic|upstream-relative \
HADALIS_IRIS_POC_SOURCE_T=0.5 \
HADALIS_IRIS_POC_OWNER_THICKNESS=56 \
HADALIS_IRIS_POC_POPUP_WIDTH=380 \
HADALIS_IRIS_POC_POPUP_HEIGHT=300 \
HADALIS_IRIS_POC_POPUP_RADIUS=48 \
HADALIS_IRIS_POC_FUSE=56 \
HADALIS_IRIS_POC_WELD=4 \
HADALIS_IRIS_POC_GUIDES=1 \
scripts/iris-corner-poc/run.sh
```

Set `HADALIS_IRIS_POC_OUTPUT=<output-name>` on a multi-output desktop.





## Geometry profiles

The PoC separates visual diagnosis from upstream-scale calibration.

`diagnostic` is the default because the maintainer requested larger corners for
easy inspection:

```text
owner thickness 56
popup           380 x 300
radius          48
fuse            56
weld            4
```

`upstream-relative` follows the default iRiS v2.31 scale much more closely:

```text
owner thickness 42
popup           360 x 300
radius          30
fuseDeep        30
weld            3
```

The upstream values come from `IrisStyle.qml` at density/melt defaults:
`radiusPanel = corner(30)`, `fuseDeep = 30 * density * meltDepth`,
`weld = 3 * density`, and the default Bar height is 42.

Select it with:

```sh
HADALIS_IRIS_POC_PROFILE=upstream-relative \
scripts/iris-corner-poc/run.sh
```

Explicit geometry environment variables still override either profile.

## Capture the full live visual matrix

To avoid accepting a center-only case, capture all 12 mandatory combinations:

```text
top / bottom / left / right
×
sourceT 0.02 / 0.50 / 0.98
```

Run inside the real Wayland session:

```sh
HADALIS_IRIS_POC_OUTPUT=<output-name> \
scripts/iris-corner-poc/capture-matrix.sh
```

The output defaults to `scripts/iris-corner-poc/captures/` and contains:

- 12 full-output PNG screenshots;
- 12 focused junction PNGs (`*-detail.png`);
- one machine-readable geometry JSON and one Quickshell log per case;
- `manifest.tsv`;
- `contact-sheet-<mode>-<profile>.png` when ImageMagick is available;
- `detail-sheet-<mode>-<profile>.png` when ImageMagick is available.

The harness launches only this developer PoC, waits for its
`HADALIS_IRIS_POC` readiness marker, persists the reported output-local
geometry, captures with `grim`, then terminates that exact PoC process before
moving to the next case. It does **not** restart, reload or IPC-call the running
Hadalis shell.

The focused crop is computed from the semantic popup/owner geometry and
`ShellScreen.x/y`, then passed to `grim -g` in compositor layout coordinates.
This avoids shrinking a 1440p/4K full screenshot just to inspect a 30–56 px
fillet, and it does not assume that Qt `devicePixelRatio` equals the
compositor's fractional output scale.

For the first acceptance pass, leave the default:

```sh
HADALIS_IRIS_POC_MODE=card-owner
```

Use `edge-reach` only as a diagnostic comparison after the card-owner matrix
has been reviewed.

## Acceptance before production work

The first gate is visual, not architectural:

1. the two junction corners must read as part of the popup/owner silhouette;
2. they must not look like blobs underneath the popup;
3. source positions near 0.02 / 0.5 / 0.98 must remain coherent;
4. all four edges must produce the same topology;
5. `card-owner` must be judged independently from `edge-reach`.

If this is not visually correct, discard/rework this PoC. Do not patch
`StyledPopup`, `ConnectedSurfaceJoinFlares`, Bar or ScreenEdges.
