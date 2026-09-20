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

## Latest continuation update — U1 implemented, production still untouched

This section supersedes the older instruction above that said U1 was only
designed and must not yet be implemented. The maintainer subsequently explicitly
approved starting U1.

Current `dev` synchronization point when this update was written:

- `2cbb6c235f7e98f8fd94179060674f526cfffa9a`
- unrelated Code Workflow work continues in parallel, so refetch before every
  audit/write.

### U1 current state

The isolated PoC now exists under `scripts/unified-surface/`.

Production remains unchanged by the PoC:

- no production `ScreenEdges.qml` integration;
- no production Bar/`StyledPopup` integration;
- no Sidebar/Dashboard/Settings migration;
- no Canvas flare/contact-plane/contactInset resurrection;
- U1 is excluded from the runtime payload.

Important implementation commits:

- `b9f376318a2d541734a24208caa679d4fb07b456` — initial isolated SDF PoC
- `084e3fe16b4ed5f246e7a67205bc9841d706ce67` — canonical QSB artifact
- `2a788d71758dea370b288621c1575e665ec461a6` — semantic QSB verification
- `aea30452b881de85ebaf0e5c2fdbfa0b5415b682` — split CI lifecycle from GPU validation
- `4a75ab9d2492eb2af3f1ca6a7bd8acead6aa48ce` — nested-Niri topology validator
- `8bf0483b4ef9d0354930a370ced7020d0db226f4` — motion/reveal/fullscreen lifecycle gates

Dedicated U1 workflow result for `8bf0483...`: **PASS**.

It verifies QSB semantics, static U1 architecture, and headless control-mode
Top/Overlay lifecycle. It does not pretend the GitHub runner proves GPU pixels.

### Why CI no longer attempts SDF pixel validation

The initial headless pixel smoke reached the real renderer boundary and showed
that the hosted environment had no usable DRM/RHI path for ShaderEffect.
Forcing Pixman/software rendering would make a false renderer test.

The corrected split is:

```text
CI:
  QSB semantic equivalence
  + static architecture
  + QML/layer-shell control lifecycle

live nested Niri on real GPU:
  actual SDF pixels
  + topology
  + fractional scale
  + motion/reveal no-remap
  + fullscreen Top/Overlay lifecycle
  + performance
```

### Exact next action

Do **not** integrate a real popup yet.

On the maintainer's live Wayland/Niri-capable machine, run:

```sh
python3 scripts/unified-surface/validate-live-niri.py \
  --scales 1 1.25 1.5 1.75 2 \
  --benchmark
```

The script starts a separate nested Niri and does not edit/reload the host Niri
configuration.

Required evidence before U2:

1. all static bounded/full topology cases pass;
2. no persistent seam at fractional scales;
3. moving source captures remain one connected material;
4. motion/reveal each show one layer-surface creation only;
5. Top material returns after fullscreen exit without remap;
6. Overlay material remains above fullscreen;
7. bounded p95 <= 110% of control;
8. bounded missed-frame ratio <= control + 0.01;
9. bounded rendering remains materially preferable to full-output diagnostic at
   higher resolutions/scales.

If the live gate fails, fix the mathematical field/bounds/lifecycle assumption
inside U1 only. Do not patch production geometry.

If it passes, the next phase is U2: renderer-neutral dynamic shape registry plus
a real module-anchor feed, still before any broad production migration.


---

## Latest continuation update — corrected U1 morphology and production projection blocker

Current research sequence after the initial U1 implementation:

- `4b32d9b2396122e9af4e0a7752b245e930509e2c` —
  corrected junction field/corner-fill model;
- `6aea14f2b47a0bbf7f7b8528ff198fca175665ce` —
  enlarged diagnostic morphology (`popupRadius=32`, `smoothK=28`);
- `d23df5f4c30d828a9814b3c9fa7a4b9ee60be46c` —
  clamped synthetic popup to `frameInner` like production;
- `ab5c70206f9ce8af5bc23791ed11c499ca90709f` —
  matched the 50px padded inverted-frame construction;
- `88a5bf0d580477602b99d6a06b6971e2951e1eb3` +
  `a665f1379923978cc3f56cca240da09a7dde789a` —
  matched Caelestia border-facing SDF compression and canonical QSB;
- `40d24a6eb5ff36984f2dd41133baae10c5b15f37` —
  added explicit shoulder-position/taper acceptance.

The dedicated U1 workflow for `40d24a6...` passed QSB semantics, the static
architecture contract and headless Top/Overlay control lifecycle.

### Do not restore attachmentDepth

Current Caelestia really does extend an attached popout BlobRect beneath its Bar
with `extraWidth=0.2`, primarily to survive deformation/movement. A direct
scalar comparison showed that 0/18/44/60px of under-owner overlap produces the
same visible workspace shoulder once the popup is fully open.

Therefore the overlap is not a reason to resurrect Hadalis
`attachmentDepth`, `contactInset` or a shifted contact plane. U1 remains
flush to the physical `frameInner` seam.

### New production blocker: Overlay must not paint over Bar foreground

A complete SDF rendered in `StyledPopup`'s Overlay window would cover the real
Top-layer Bar modules if it also outputs owner-band pixels.

The next isolated research step is a **workspace projection** PoC:

- mathematically evaluate the complete owner-frame + popup union;
- in Overlay mode, output only pixels inside the base rounded
  `frameInner`/workspace domain;
- keep a test-only high-contrast Top owner probe visible underneath;
- require the same enlarged shoulder-position/taper gate to pass;
- compare workspace projection against the full-field reference inside the
  workspace.

Do not put the material shader inside `ConnectedSurfaceRevealClip`. The
material field must evaluate the owner representation; only popup **content**
should retain the fixed reveal clip.

Production `StyledPopup`, `ConnectedSurfaceFrame`, Bar and ScreenEdges are
still untouched by U1. Do not create the production cutover commit until both
the live GPU matrix and the owner-projection gate are accepted.


---

## Latest continuation update — projection PoC implemented and CI-clean

Current isolated U1 projection commits:

- `2120903bdf60c6cb96f368198dd554bcc2d996f8` —
  workspace projection + Top owner foreground probe;
- `1b7ca94cfea983a0bc9fd4a2d834a6f9f55a5fec` —
  canonical projection QSB.

The dedicated U1 workflow for `1b7ca94...` is **PASS**:

- QSB semantic verification;
- U1 static architecture contract;
- Top/Overlay headless control lifecycle;
- artifact bake/upload.

Production is still untouched.

### Current model

The Overlay popup renderer computes the full virtual owner-frame + popup SDF but
may output only the portion inside the **base rounded frameInner workspace**.
This preserves Top-layer Bar/Screen Edge foreground while retaining the same
workspace-side shoulder field.

The new test-only `U1OwnerProbe.qml` will verify on live nested Niri that:

- full Overlay field hides a Top probe;
- workspace projection leaves the Top probe visible;
- projected workspace pixels match the full-field reference;
- shoulder position/taper remains correct.

### Final production placement if live gate passes

Do not place the shader inside `ConnectedSurfaceRevealClip` and do not retrofit
SDF into the legacy join-flag/flare implementation.

Preferred structure:

```text
full-output Overlay popup window
  -> shared ConnectedSurfaceField material
     (full field evaluation + workspace projection)
  -> existing reveal-clipped content
  -> geometry-only body/input proxy
  -> existing Region-based input mask
```

Only two runtime consumers currently instantiate `ConnectedSurfaceFrame`:
ii `StyledPopup` and Waffle `BarPopup`. Plan one shared material replacement
for both.

Do not keep `RectangularShadow` as the final unified-surface shadow. The
eventual shadow must come from the full signed-distance field before workspace
projection, otherwise the seam or shoulder will be wrong.

### Remaining hard gate

Run on a real Wayland/Niri GPU session:

```sh
python3 scripts/unified-surface/validate-live-niri.py \
  --scales 1 1.25 1.5 1.75 2 \
  --benchmark
```

Do not write the production cutover commit until that run passes. If it fails,
fix/revert isolated U1 rather than adding production offsets or flares.


### First production attempt is ii-only

A material audit after the projection PoC found that ii and Waffle cannot safely
share the same first cutover:

- ii owner + popup both use Material `colLayer0`;
- Waffle owner uses `bg0`, while its popup intentionally uses `bg1Base`;
- Caelestia BlobGroup itself is one-colour-per-group.

Therefore, after the live U1 matrix passes, migrate **ii StyledPopup only**.
Keep Waffle on the existing connected-surface renderer and preserve its palette.
Waffle is still supported and must not be labelled legacy.

Expected first production file scope:

```text
ADD:
  modules/common/perimeter/ConnectedSurfaceField.qml
  modules/common/perimeter/ConnectedSurfaceField.frag
  modules/common/perimeter/ConnectedSurfaceField.qsb

MODIFY:
  modules/common/perimeter/qmldir
  modules/bar/StyledPopup.qml
  focused ii popup/contracts/packaging tests

UNCHANGED:
  ScreenEdges.qml
  Bar.qml
  Waffle BarPopup.qml
  Sidebar/Dashboard/Settings
```

Do not globally delete `ConnectedSurfaceFrame` or
`ConnectedSurfaceJoinFlares` in that commit because Waffle still consumes that
presentation.
