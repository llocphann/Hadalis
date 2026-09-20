# Unified Surface Research — New Chat Handoff

Use this file when the current ChatGPT conversation is too long and work must continue in a fresh chat.

Primary research document:

- `docs/UNIFIED_SURFACE_RESEARCH.md`

Related existing architecture/contracts:

- `docs/PERIMETER.md`
- `docs/SHELL_SURFACE_CONTRACTS.md`
- `ARCHITECTURE.md`
- `AGENTS.md`

## Current repository state

The contact-corner patch series was reverted.

Revert commit:

- `cef10e8923c24ef4cf4106237dfaa418c1abe4a9`
- `revert: restore pre-contact-corner baseline`

The affected production files were verified byte-identical to the pre-corner baseline:

- `ad42c9326e34cdec6e2d7791a2a0664d8bbfb82f`

The branch continues to receive unrelated Code Workflow Editor commits, so **always refetch current `dev` before doing anything**.

Do not reset/rewrite unrelated Workflow Editor work.

## Key decision already reached

Do **not** continue trying to solve the visual requirement with:

- Canvas corner flares;
- extra `RoundCorner` objects;
- contact-inset patches;
- per-consumer seam offsets;
- manual “join” geometry as the fundamental model.

The user wants Bar/Screen Edge + connected popup/panel to behave as **one material/silhouette**, especially when Bar modules are reordered.

The research direction is Caelestia-like unified surface composition:

```text
shared visual host/domain
  + inverted frame
  + moving rounded panel/popout shapes
  -> SDF smooth union / border sink
  -> one silhouette
```

Source module movement should only update the popup rectangle. The union topology should follow automatically.

## Important constraints

1. Do not modify the locked physical Screen Edge/Bar geometry while researching.
2. A real SDF union cannot span independent `QQuickWindow` scenegraphs. Shapes that visually union need representations inside one visual host/window/domain.
3. Interactive content may remain in separate windows; the shared host can own only material/background/shadow.
4. One global host is not automatically correct because Settings Overlay/scrim and other layer relationships differ. Investigate **composition domains**.
5. Hadalis currently has no native Qt Quick rendering plugin. Native QSG work has packaging/ABI consequences.
6. Hadalis already ships a `.qsb` ShaderEffect asset (`FluidRipple`), making a non-production QSB SDF PoC plausible.
7. Do not commit production implementation until the remaining architecture blockers are researched.

---

## Copy/paste prompt for the next chat

```text
Continue the Hadalis unified-surface research from the repository handoff.

Repository: llocphann/Hadalis
Branch: dev

FIRST:
1. Refetch the current dev HEAD because unrelated Code Workflow Editor work is continuing in parallel.
2. Read:
   - docs/UNIFIED_SURFACE_RESEARCH.md
   - docs/UNIFIED_SURFACE_HANDOFF.md
   - docs/PERIMETER.md
   - docs/SHELL_SURFACE_CONTRACTS.md
   - ARCHITECTURE.md / AGENTS.md as applicable.
3. Verify the reverted contact-corner files still match the pre-experiment baseline ad42c9326e34cdec6e2d7791a2a0664d8bbfb82f where expected.
4. Do not rewrite/reset unrelated commits.

Context:
- The Canvas/flare/contact-plane patch approach was rejected and reverted.
- The product requirement is a Caelestia-like common silhouette: Bar/Screen Edge and connected popup/panel should behave as one shape/material.
- When a Bar module is reordered, the popup's contact topology must follow its live anchor automatically; the renderer must not select/draw corners manually.
- Caelestia achieves this with BlobGroup + rounded/inverted SDF shapes in one scenegraph.
- Cross-QQuickWindow SDF union is not possible after separate scenegraphs render; Hadalis likely needs visual composition domains/hosts while retaining separate input/content windows.
- Do NOT commit production code yet.

Continue research deeply on these three blockers first:
A. Niri/Wayland layer-shell stacking and lifetime for a shared input-transparent visual host:
   - ScreenEdges FrameWindow vs Bar vs Overlay popup;
   - same-layer creation/remap ordering;
   - whether Bar popout backgrounds can be rendered by a Top host while content stays Overlay;
   - whether a second Overlay visual domain is needed.

B. Blur/material/shadow ownership:
   - current BackgroundEffect.blurRegion behavior;
   - how a unified host can request blur only inside the SDF union;
   - transparent Material/backgroundTransparency cases;
   - common union shadow;
   - Settings Overlay/scrim ordering.

C. Renderer/package architecture:
   - minimal QSB ShaderEffect SDF PoC vs native QQuickItem/QSG plugin;
   - repo-copy update lifecycle;
   - Arch package and Nix package;
   - QML import path/Qt ABI/hot reload/fallback;
   - leverage the existing optional native Code Workflow parser packaging pattern only where appropriate.

Also extract the minimum Caelestia Blob shader model needed for Hadalis:
- rounded-rect SDF;
- inverted frame;
- smooth union;
- border sink;
- bounding geometry/fill-rate strategy.

Then design, but do NOT yet implement, the exact U1 PoC:
- one output-local visual host;
- locked frame parameters reproduced as data;
- one moving popup rounded rect driven by a real/fake Bar module anchor;
- renderer has zero module-specific or corner-specific branches;
- topology tests for center/edges/top-bottom/vertical/fractional scale;
- performance instrumentation;
- explicit pass/fail gates and rollback.

Use GitHub integration to inspect source/history. Do not commit until the user explicitly approves implementation after reviewing the research.
```

## Reminder for future implementation

The first implementation should be an **isolated PoC**, not a replacement for `StyledPopup`, `ScreenEdges`, Sidebar or Dashboard.

A successful PoC must prove:

- one SDF silhouette;
- source module can move and contact follows automatically;
- no `joinTop/joinRight`-style topology logic;
- no per-popup magic offset;
- correct fractional-scale rendering;
- acceptable performance;
- no input interception;
- no production geometry mutation.
```


---

## Continuation update — U0 blockers resolved

Research continued on 2026-09-20 and is recorded in
\`docs/UNIFIED_SURFACE_RESEARCH.md\`, sections 21–25.

Documentation commit:

- \`1a8781339e2d8198848bf0ce30fa36e2db425e7f\`
- \`docs(surface): resolve U0 blockers and specify U1\`

No production code was changed.

### Decisions now reached

- **Layer lifetime:** Niri/Smithay same-layer ordering is insertion/remap sensitive.
  A shared visual host whose relative order matters must stay mapped; mutate shape
  membership/opacity instead of its Wayland surface lifetime.
- **Top vs Overlay:** a Top-only host cannot provide the complete material for
  existing Overlay popouts across fullscreen/overview. Keep the persistent
  perimeter in a Top base domain, and compose attached popup material in an
  Overlay-local domain. For \`StyledPopup\`, prefer eventually rendering the local
  SDF material inside its existing full-output Overlay scenegraph rather than
  adding a second same-layer visual window.
- **Blur:** \`BackgroundEffect.blurRegion\` is \`ext-background-effect-v1\`
  surface state backed by a \`wl_region\`, not shader alpha. Future architecture
  should project one renderer-neutral shape registry both to the SDF renderer and
  to a compositor Region mask. U1 uses opaque material and no blur.
- **Shadow:** future connected-surface shadow belongs to the unified field/alpha,
  not Niri's rectangular layer-surface shadow. Production shadow remains unchanged
  during U1.
- **Settings:** keep Settings as a local Overlay composition domain under its
  existing backdrop/scrim ordering; do not move its card material into the Top
  perimeter host.
- **Renderer:** U1 is explicitly QSB/ShaderEffect. Native QSG remains a U3
  production candidate only if shape count/fill-rate requires it.
- **Native packaging, if later needed:** use a separate \`Hadalis.Surface\` QML
  module package, built with Qt CMake/QML tooling and added to the QML import path.
  The existing Code Workflow parser split is only a lifecycle precedent, not a
  direct QML-plugin template. Repo-copy updates must never compile a native plugin.
- **Caelestia minimum model:** rounded-rect SDF + inverted frame + circular smooth
  union + generic border sink + bounded affected geometry. Do not port spring
  deformation or other Blob features into U1.

### U1 is designed but not implemented

The exact isolated U1 contract is in
\`docs/UNIFIED_SURFACE_RESEARCH.md#24-exact-isolated-u1-sdf-poc-specification\`.

It proposes only non-production files under:

\`\`\`text
scripts/unified-surface/
  U1Shell.qml
  U1Surface.qml
  U1Surface.frag
  U1Surface.qsb
  README.md
  build-shader.sh
\`\`\`

Important: do **not** implement U1 unless the maintainer explicitly asks to start
the PoC. When implementation is approved, refetch \`dev\` first because unrelated
work may have advanced the branch.

The reverted pre-contact-corner baseline remains authoritative. Do not resurrect
Canvas flares, contact-plane offsets, \`contactInset\`, or per-consumer seam
patches.


---

## Current direction — iRiS v2.31.0, not Caelestia/U1

The maintainer has explicitly selected upstream **iRiS v2.31.0** as the primary
reference for connected popup corners.

Reference:

- `snowarch/iNiR@9574fa424c0d1008e927454e933a7fbe292f9fb2`
- `modules/iris/field/IrisField.qml`
- `modules/iris/field/IrisField.frag`
- `modules/iris/stage/IrisStage.qml`
- `modules/iris/control/IrisControlCenter.qml`

Caelestia remains historical research only. Do not restart the old U1
border-sink/cornerFill path.

### Isolated PoC now exists

Commits:

- `c2a15b9b87e5d8cb144405fc5ef8dec01126716a`
- `0a39ba386849c96248393b52ea4fd10552c57856`

Files live under:

```text
scripts/iris-corner-poc/
```

The exact upstream iRiS shader source and QSB are committed there. The directory
is developer-only and runtime-excluded.

Default mode:

```text
HADALIS_IRIS_POC_MODE=card-owner
```

This is the relevant `StyledPopup` analogue:

- small weld overlap;
- explicit `joins: "owner"`;
- deep fuse;
- no manually drawn corner.

`edge-reach` is only a diagnostic reproduction of `IrisStage.meltInto()` and
must not be confused with card/popup geometry.

Run:

```sh
scripts/iris-corner-poc/run.sh
```

Useful visual matrix:

```sh
HADALIS_IRIS_POC_EDGE=top    HADALIS_IRIS_POC_SOURCE_T=0.02 scripts/iris-corner-poc/run.sh
HADALIS_IRIS_POC_EDGE=top    HADALIS_IRIS_POC_SOURCE_T=0.50 scripts/iris-corner-poc/run.sh
HADALIS_IRIS_POC_EDGE=top    HADALIS_IRIS_POC_SOURCE_T=0.98 scripts/iris-corner-poc/run.sh
HADALIS_IRIS_POC_EDGE=bottom HADALIS_IRIS_POC_SOURCE_T=0.50 scripts/iris-corner-poc/run.sh
HADALIS_IRIS_POC_EDGE=left   HADALIS_IRIS_POC_SOURCE_T=0.50 scripts/iris-corner-poc/run.sh
HADALIS_IRIS_POC_EDGE=right  HADALIS_IRIS_POC_SOURCE_T=0.50 scripts/iris-corner-poc/run.sh
```

Guides:

- yellow = actual iRiS field;
- cyan = semantic popup rect;
- magenta = owner seam.

### Hard rules

- ii only;
- Waffle untouched;
- no production cutover before visual acceptance;
- no Canvas/JoinFlares/contactInset/cornerFill/borderSink patches in the PoC;
- preserve immutable slide-only `SurfaceMotion`;
- if the visual is wrong, modify/revert the isolated PoC rather than layering
  geometry patches onto production.


### Latest gate — live iRiS contact sheet

The isolated iRiS PoC is now source-side complete enough for visual acceptance.

Additional commits:

- `ff54e4b47578e271271bd023d9a39e4793213c62` — live 12-case matrix capture;
- `b50f93f8eed288c42faf9b6c90296a6ef93b7c32` — diagnostic and upstream-relative profiles;
- `204ece1d96d117d49371a0ed6a2399635dfa757d` — exact iRiS QSB ABI guard.

The two profiles are:

```text
diagnostic:
  owner 56, popup 380x300, radius 48, fuse 56, weld 4

upstream-relative:
  owner 42, popup 360x300, radius 30, fuse 30, weld 3
```

Run the diagnostic matrix first:

```sh
HADALIS_IRIS_POC_OUTPUT=<output-name> \
HADALIS_IRIS_POC_PROFILE=diagnostic \
scripts/iris-corner-poc/capture-matrix.sh
```

Then compare with:

```sh
HADALIS_IRIS_POC_OUTPUT=<output-name> \
HADALIS_IRIS_POC_PROFILE=upstream-relative \
scripts/iris-corner-poc/capture-matrix.sh
```

The harness captures four edges x three source positions and, when ImageMagick
is installed, writes one contact sheet per profile.

This is the current hard gate. Do not integrate `StyledPopup` until these live
captures are accepted. If they are wrong, only the isolated PoC may change.

Waffle remains completely out of scope.

---

## Latest continuation — focused/multi-owner iRiS live gate

Two more isolated PoC commits are now part of the hard visual gate:

- `e7700ea31c5ff07edda001ef0f00674e33f217c0` — focused `grim -g`
  junction captures plus per-case geometry JSON;
- `f72af8b8407e796eb117402d1057da47f257aa9d` — multi-owner corner
  coverage.

The important correction is that the old center-only model did not exercise the
real Hadalis output-corner topology. The PoC now keeps three owner bodies plus
the popup:

```text
primary owner
frame-start
frame-end
popup
```

Join selection is generic geometry, not module-specific state:

```text
sourceT 0.50 -> ["owner"]
sourceT 0.02 -> ["owner", "frame-start"]
sourceT 0.98 -> ["owner", "frame-end"]
```

The start/end records model the perpendicular physical Screen Edge (default
10 logical px). This uses the exact upstream iRiS QSB's two explicit join slots;
it does not add any corner renderer.

The live harness now writes, per case:

- full-output PNG;
- focused `*-detail.png`;
- geometry JSON;
- Quickshell log;
- manifest row.

With ImageMagick it also writes both a full contact sheet and a focused detail
sheet. The focused region is derived from output-local popup geometry plus
`ShellScreen.x/y` and captured in compositor layout coordinates; do not replace
this with a DPR-based crop.

Current source-side evidence:

```text
iRiS PoC contract  PASS
validator          115 PASS / 22 FAIL / 2 SKIP
Nix package        PASS
```

Production is still **not approved for cutover**. The next action is still to run
both live profiles on the real Wayland/GPU session and inspect the detail sheets:

```sh
HADALIS_IRIS_POC_OUTPUT=<output-name> \
HADALIS_IRIS_POC_PROFILE=diagnostic \
scripts/iris-corner-poc/capture-matrix.sh

HADALIS_IRIS_POC_OUTPUT=<output-name> \
HADALIS_IRIS_POC_PROFILE=upstream-relative \
scripts/iris-corner-poc/capture-matrix.sh
```

Acceptance must explicitly cover:

1. center cases: one primary-owner fillet;
2. start/end clamp cases: primary owner + perpendicular Screen Edge remain one
   coherent field;
3. no separate-looking blob below/behind the popup;
4. all four attachment edges are symmetric;
5. upstream-relative profile preserves the same topology.

Until that visual evidence is accepted, do not replace
`ConnectedSurfaceFrame`/`ConnectedSurfaceJoinFlares` in production. Waffle
remains out of scope and `SurfaceMotion` remains slide-only.

---

## Latest continuation — production composition domain

A source-side architecture audit found one additional constraint before the
production phase.

At exact upstream iRiS v2.31.0, `IrisBar.qml` aggregates Island, Control
Center, Stage/card and Dock records into one `fieldShapes` registry and renders
them through one full-output `IrisField` in the same `barWindow`. Card-owner
joins therefore assume a shared paint/composition domain, not merely matching
coordinates.

Hadalis does not currently have that topology: Bar and physical ScreenEdges are
Top-layer owners while `StyledPopup` is a separate full-output Overlay
surface. The current PoC also paints its owner/frame records, so **do not paste
the PoC wrapper directly into `StyledPopup`**; doing so can double-paint the
owners in Overlay and cover/change existing Bar or Screen Edge presentation.

The existing live matrix remains the first hard gate and is unchanged:

```sh
HADALIS_IRIS_POC_OUTPUT=<output-name> \
HADALIS_IRIS_POC_PROFILE=diagnostic \
scripts/iris-corner-poc/capture-matrix.sh

HADALIS_IRIS_POC_OUTPUT=<output-name> \
HADALIS_IRIS_POC_PROFILE=upstream-relative \
scripts/iris-corner-poc/capture-matrix.sh
```

If those matrices pass, the **next** experiment is still developer-only: model
Hadalis' split composition and test exact iRiS shape/join math with owner records
kept in output-local coordinates but a popup/junction-limited shader paint
viewport (plus the existing attachment reveal boundary). This is a rendering
scissor/domain concern, not a per-corner branch.

Production cutover is not approved until that split-composition experiment also
shows:

- no duplicate Bar or Screen Edge paint;
- no Bar-module occlusion;
- no physical Screen Edge shadow/material discontinuity;
- symmetric top/bottom/left/right joins and both clamp extremes;
- unchanged slide-only `SurfaceMotion`, popup input/focus and fractional-scale
  behavior.

Do not modify Bar/ScreenEdges geometry to satisfy this gate, do not add helper
windows or corner flags, and do not touch Waffle.

### Source-side viewport result

The exact iRiS shader confirms that the proposed G2 paint scissor is technically
valid: it reconstructs output-space `p` from `viewport.xy/zw` while every
shape stays in output pixels. A future isolated split-composition PoC can
therefore keep full owner records for SDF joins and rasterize only a
popup/junction-local `ShaderEffect` viewport.

Do not treat the upstream wrapper's all-shape `bounds` calculation as a shader
requirement. For G2, local paint bounds must expand generically by the active
join/fuse reach and follow the animated popup.

Input and shadow are separate G2 gates. `Region` cannot follow shader alpha and
the current mask contains old Bézier-strip connector approximations; do not keep
those merely to make the new renderer interactive. Likewise, preserve popup
shadow behavior without repainting/shadowing the Top-layer Bar or Screen Edge.

G1 is still unchanged and must run first on the real Wayland/Niri/GPU session.
