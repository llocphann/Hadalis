# Unified Surface Composition Research

Status: **research + isolated U1 PoC — no production integration is approved yet**

Last synchronized against `dev` at `2cbb6c235f7e98f8fd94179060674f526cfffa9a` on 2026-09-20.

## 1. Why this document exists

Hadalis needs Bar/Screen Edge connected popups, Sidebar, Dashboard, Settings Overlay and similar edge-attached surfaces to read as **one continuous material/silhouette**, closer to Caelestia.

The previous experiments attempted to synthesize the contact corners separately with:

- `ConnectedSurfaceJoinFlares`;
- Canvas/Bézier corner pieces;
- explicit `joinTop/joinBottom/joinLeft/joinRight` routing;
- mapped body geometry;
- contact-plane/inset calculations;
- seam-overlap compensation.

Those experiments could make some corners visible, but they repeatedly produced one or more of:

- a small gap at the Bar/Screen Edge seam;
- a shifted or floating corner;
- inconsistent results between Sidebar, Dashboard and Bar popups;
- corner disappearance after repeated hover/open-close cycles;
- consumer-specific offset logic;
- duplicated knowledge of Bar/Screen Edge thickness and seam ownership.

The user clarified the real product requirement:

> The contact corners should not look like corrective geometry painted around two unrelated rectangles. The connected Bar/Screen Edge and popup should behave like one common shape, and when a Bar module is reordered the connected popup topology should follow its new position automatically.

That requirement changes the architectural target. The desired result is not “better flares”; it is **unified surface composition**.

---

## 2. Revert/baseline status

The contact-corner experiment series was reverted by:

- `cef10e8923c24ef4cf4106237dfaa418c1abe4a9` — `revert: restore pre-contact-corner baseline`

The current production files involved in those experiments are byte-identical to the pre-experiment baseline at:

- `ad42c9326e34cdec6e2d7791a2a0664d8bbfb82f`

This was re-verified against current `dev` for all relevant paths, including:

- `modules/common/perimeter/ConnectedSurfaceJoinFlares.qml`
- `modules/common/perimeter/ConnectedSurfaceFrame.qml`
- `modules/common/perimeter/ConnectedSurfaceRevealClip.qml`
- `modules/bar/StyledPopup.qml`
- `modules/waffle/bar/BarPopup.qml`
- `modules/sidebar/SidebarHost.qml`
- Sidebar left/right visible surface files
- `modules/overview/Overview.qml`
- `modules/overview/OverviewDashboard.qml`
- `modules/onScreenKeyboard/OnScreenKeyboard.qml`
- `modules/settings/SettingsOverlay.qml`
- `modules/settings/SettingsFocus.qml`
- Sidebar config/default schema files
- perimeter/shell-surface regression scripts
- `README.md`

Any later `dev` commits after the revert were Code Workflow Editor work and did not reintroduce the corner experiment into those files.

### Do not resurrect the reverted patch stack

The following approaches are considered rejected as a production foundation:

1. Per-corner Canvas patches added on top of otherwise independent surfaces.
2. Generic `contactInset` inference.
3. Consumer-specific magic pixel offsets for Sidebar/Dashboard/Battery.
4. Shifting a mathematical contact plane merely to hide compositor/AA cracks.
5. A growing matrix of `joinTop/joinBottom/joinLeft/joinRight` plus special cases as the primary topology model.
6. Treating Screen Edge/Bar and Popup as separate silhouettes and attempting to fake a unified contour afterward.

The existing connected-surface helpers may remain as baseline code until a replacement is proven, but they must not constrain the new architecture.

---

## 3. What Caelestia actually does

Relevant Caelestia source areas examined:

- `modules/drawers/ContentWindow.qml`
- `modules/drawers/Panels.qml`
- `modules/bar/Bar.qml`
- `modules/bar/popouts/Wrapper.qml`
- `modules/bar/popouts/ClipWrapper.qml`
- `plugin/src/Caelestia/Blobs/blobgroup.*`
- `plugin/src/Caelestia/Blobs/blobshape.*`
- `plugin/src/Caelestia/Blobs/blobrect.*`
- `plugin/src/Caelestia/Blobs/blobinvertedrect.*`
- `plugin/src/Caelestia/Blobs/blobmaterial.*`
- `plugin/src/Caelestia/Blobs/shaders/blob.frag`
- plugin CMake/QML module packaging files.

### Core model

Caelestia does not draw an independent “join corner” between two windows.

Conceptually:

```text
one visual scene
└── BlobGroup
    ├── BlobInvertedRect   # screen/frame/border domain
    ├── BlobRect           # panel/popout A
    ├── BlobRect           # panel/popout B
    └── ...
         ↓
    SDF smooth union / sink
         ↓
    one resulting silhouette
```

Each participating shape contributes an SDF. The shader/material combines those fields. The curved shoulder at a contact point is therefore **the boundary of the union itself**, not a separate decorative object.

### Border sink

Caelestia's inverted frame participates in the same field. A panel entering the border can cause the border contour to yield/sink around it. This is why a popout can appear to grow naturally from an edge/frame instead of looking like one rounded rectangle touching another.

### Why module reordering works naturally

Caelestia's Bar popout placement follows the live source item position. The important semantic flow is:

```text
Bar module Item
    ↓ live mapToItem()/position binding
currentCenter / source rect
    ↓
popout rect position
    ↓
BlobRect position
    ↓
BlobGroup recomputes the common field
```

If the module is reordered, the source item moves. The popout rect moves. The SDF topology changes automatically.

The renderer does **not** need:

```text
if module is near right edge:
    draw a right contact corner
```

It only consumes the new rectangles.

This exactly matches the Hadalis requirement that moving a Bar module should cause its popup contact shape to follow automatically.

---

## 4. Existing Hadalis pieces worth keeping

The research does **not** imply rewriting the entire shell.

### 4.1 StyledPopup's source/anchor semantics are useful

`StyledPopup.qml` already owns valuable semantic behavior:

- `hoverTarget` points to the real source control;
- `_anchorWindow` and `_anchorScreen` derive ownership from that source;
- `_anchorRect()` explicitly touches target geometry and `QsWindow.windowTransform` because Quickshell mapping calls are not fully reactive by themselves;
- popup placement already follows module movement/output transforms;
- support exists for `anchorRect`, centered large surfaces and horizontal/vertical Bar ownership;
- hover-transfer/retract lifecycle is already solved separately from visual shape.

This anchor/ownership logic should be retained and adapted into a **shape registration feed**, not discarded.

### 4.2 ScreenEdges.FrameWindow is an important existing host candidate

The current Screen Edge implementation already has a full-output visual window with several useful properties:

- one instance per output;
- mapped persistently;
- click-through/input ignored;
- full-output coordinate space;
- frame geometry already represents the locked Screen Edge silhouette;
- Bar can be represented as a thicker edge in the same conceptual perimeter model;
- load ordering/stacking constraints are already documented because Niri can change same-layer stacking when surfaces are remapped.

This does **not** prove that ScreenEdges.FrameWindow must become the final unified host, but it makes it the strongest first candidate for a Bar/Screen Edge composition domain.

### 4.3 Current module-reorder infrastructure is sufficient as an input

Hadalis Bar modules are driven from configured layout/zone data. Reordering changes the real QML Item positions. Because popup ownership is already tied to the source Item, the future unified renderer can consume **live output-space rectangles** rather than storing contact-corner state.

---

## 5. Critical Qt/Quickshell constraint: one SDF cannot span independent scenegraphs

This is a fundamental constraint and must shape the architecture.

Each `QQuickWindow` has its own scenegraph/content root. Current Hadalis surfaces are often independent layer-shell windows:

```text
ScreenEdges FrameWindow  -> Top
Bar PanelWindow          -> Top
StyledPopup PanelWindow  -> Overlay
Sidebar PanelWindow      -> Overlay
Overview PanelWindow     -> Overlay
Settings PanelWindow     -> Overlay
```

The compositor receives the already-rendered textures/surfaces and composites them later.

Therefore a real GPU SDF union cannot be computed by placing one SDF shape in the Bar window and another SDF shape in the Popup window. They are already separate render targets by then.

### Consequence

All shapes that are supposed to form **one silhouette** must have a representation inside **one visual QQuickWindow/scenegraph**.

The interaction/content window may remain separate, but the common background/material silhouette needs a shared visual host.

This leads to the split:

```text
Visual host
  owns unified material / SDF silhouette

Content/input windows
  own controls, focus, pointer handling, keyboard input, semantic lifecycle
```

This is a promising hybrid architecture because Hadalis does not need to move all interactive content into a single monolithic window.

---

## 6. Visual composition domains, not necessarily one global host

A single global host for every shell surface is probably wrong.

### Why

Layering/scrim semantics differ.

Example: Settings Overlay currently includes an Overlay-layer scrim/glass backdrop plus the Settings card. If the Settings card's material background were drawn far below that in a Top-layer global host, the scrim would tint/cover it incorrectly.

So the correct abstraction is likely a **composition domain**:

> Shapes may union only when they share the same intended visual material/topology and can be rendered in a host at the correct stacking relationship.

Candidate domains:

### Domain A — ii edge material

Likely participants:

- Screen Edge frame;
- horizontal/vertical Bar material;
- Bar popout backgrounds;
- possibly Dashboard when directly attached;
- possibly Sidebar when directly attached.

This is the main Caelestia-like target.

### Domain B — Settings Overlay material

Possible participants:

- Settings card/body;
- a virtual/derived bottom owner edge when Overlay mode is attached to the physical perimeter.

It may require an Overlay-layer composition host or a local SDF composition inside the Settings Overlay window rather than the shared Top-layer edge host.

### Domain C — detached/non-unified surfaces

Examples may include context menus or windows that should not visually merge into the perimeter. They should not be forced into the common field.

This domain model needs more validation before implementation.

---

## 7. Renderer strategies evaluated

### Option A — Pure QML Shape/Canvas

**Recommendation: reject as the production architecture.**

Pros:

- easiest to prototype;
- no native ABI/package work;
- works with repo-copy immediately.

Cons:

- returns to hand-built geometry;
- hard to express robust many-shape smooth union;
- repeats the exact failure mode of the corner-flare experiments;
- topology becomes conditional QML rather than a field operation;
- difficult to guarantee identical results at arbitrary module positions and fractional scale.

It may be useful only for diagnostic sketches, not the target implementation.

### Option B — Full-screen QML ShaderEffect SDF

Hadalis already ships a compiled ShaderEffect example:

- `modules/common/widgets/FluidRipple.frag`
- `modules/common/widgets/FluidRipple.qsb`

So QSB assets already fit the runtime payload.

Pros:

- no C++ QML type required for a PoC;
- directly proves SDF math/topology;
- hot-reload friendly;
- compatible with repo-copy if the `.qsb` is committed;
- good way to validate frame + moving popup union before committing to native plugin infrastructure.

Risks:

- a full-output shader can be expensive, especially at high resolution/fractional scale;
- passing a dynamic registry of many rounded rects through ShaderEffect uniforms is awkward/limited;
- large fixed uniform arrays impose shape-count limits and work per fragment;
- full-screen fill-rate can dominate even when only small regions change;
- implementing efficient bounds/culling in pure QML is harder.

**Current view:** best minimal mathematical PoC, not automatically the final production renderer.

### Option C — Native QQuickItem/QSG material, Caelestia-style

Pros:

- strongest production direction;
- shape-specific/padded geometry can reduce fill-rate;
- natural dynamic shape registry;
- one material can consume multiple shape records;
- closest to Caelestia's proven architecture;
- can implement inverted frame + rounded rect smooth union cleanly;
- allows explicit scenegraph batching/culling and future shadow integration.

Risks:

- Hadalis currently has no native QML rendering plugin;
- Qt ABI/version compatibility matters;
- adds CMake/build/package complexity;
- repo-copy update cannot merely copy source if a binary module must be rebuilt;
- Arch package can no longer remain architecture-neutral for that capability;
- Nix default currently uses `stdenvNoCC` for the shell;
- installation/discovery of a QML plugin must be made reliable for Quickshell.

**Current view:** likely production renderer if PoC proves the topology and packaging work is designed first.

### Option D — Hybrid

Recommended research direction:

1. validate math/topology with a small QML/QSB PoC;
2. define the registry/domain API independent of renderer;
3. only then implement the same API with native QSG if performance/shape-count requires it.

This reduces the risk of building packaging infrastructure before the surface model itself is proven.

---

## 8. Packaging and runtime implications

### Current repo-copy model

The installed shell payload is primarily synchronized files under the runtime root. QML and committed `.qsb` assets work naturally with this.

A native `.so` QML plugin changes that assumption:

- it must be built for the current architecture;
- against a compatible Qt;
- installed at a QML import path;
- rebuilt when plugin source/Qt ABI changes.

### Arch precedent already exists

Hadalis now has a native optional capability for Code Workflow:

- `distro/arch/inir-workflow-parser/PKGBUILD`
- packages `qmljs.so`;
- architecture-specific `x86_64`;
- source shell remains architecture-neutral.

This proves the project can manage optional native artifacts, but that parser is loaded through Python/ctypes, **not** imported as a Qt QML plugin.

A surface renderer would need stronger QML import integration.

### Nix precedent

`nix/workflow-parser.nix` separately builds a native parser capability while the default shell can remain parser-free.

Again, this shows native capability packaging is feasible, but a QML renderer plugin would need to be added to:

- the Qt QML import search path;
- wrapper environment;
- closure/build inputs.

### Current Nix shell

The default shell package currently uses a no-compiler style packaging path and wraps QML import/plugin paths from dependencies. A native renderer likely requires a separate derivation/module package and then a wrapped shell variant, similar in spirit to the workflow parser split but using Qt CMake/QML tooling.

### Required packaging research before native implementation

Do not begin a production C++ renderer until these questions have concrete answers:

1. Where will the plugin live for repo-copy installs?
2. Will `inir update` detect source/plugin ABI mismatch?
3. Who builds it for repo-copy users?
4. Is it an optional package plus capability detection, or mandatory?
5. How is `QML2_IMPORT_PATH`/Qt 6 import discovery configured consistently for:
   - repo-copy;
   - Arch;
   - Nix;
   - source/developer runs?
6. How will Qt/Quickshell upgrades trigger rebuilds?
7. What is the fallback if the plugin is missing or incompatible?

No “download/build during shell startup” path should be introduced.

---

## 9. Blur/material/shadow is a major unresolved design area

Moving the visual background out of the content window affects more than color.

Current Bar and popup implementations can own:

- compositor blur region;
- local wallpaper fallback blur;
- opacity/transparency;
- border;
- material effects;
- shadow;
- input mask.

A unified visual host must define ownership explicitly.

### Recommended separation to investigate

```text
Unified visual host:
- fill/material silhouette
- common border if any
- common shadow
- compositor blur request for the union if host/layer allows it

Content windows:
- controls/content
- focus
- hover/click
- keyboard
- semantic open/close lifecycle
- transparent background
- shape-aware input region
```

### Important difficulty

If the visual host is on `Top` but a popup content window is on `Overlay`, blur/material may visually align but stacking around other Overlay surfaces must be tested.

Settings Overlay is the clearest example where a Top-layer host is insufficient because of scrim ordering.

Blur support therefore may force different visual domains/hosts by layer.

---

## 10. Input/mask architecture

A unified **visual** host should ideally remain input-transparent.

The content/input windows should continue to own:

- `MouseArea`/`HoverHandler`;
- keyboard focus;
- close-on-outside-click catcher;
- popup masks;
- sidebar interaction;
- Settings interaction.

This preserves the mature interaction lifecycle while replacing only the way backgrounds are composed.

The future registry should not use input geometry as its source of truth. It should consume visual/output-space rectangles registered from the same semantic surface controllers.

---

## 11. Proposed PoC architecture — no production cutover yet

### Goal

Prove one invariant:

> A Bar/source module can move/reorder and its attached popup background remains one smoothly-unioned silhouette with the edge/frame without any corner-specific code.

### Minimal PoC graph

```text
OutputSurfacePrototype
├── UnifiedSurfaceRegistry
│   ├── frame record
│   ├── bar record
│   └── popup record
│
├── UnifiedSurfaceRenderer
│   └── SDF union
│
└── live anchor adapter
    └── a real Bar module Item or controlled fake item
```

### Shape record draft

Keep the registry renderer-agnostic.

Each shape record should describe something close to:

```text
id
domainId
kind: frame | roundedRect
outputName
rect in output logical coordinates
radius
enabled
materialRole
z/topology role only if mathematically required
```

Avoid:

```text
joinTop
joinBottom
joinLeft
joinRight
topLeftFlare
rightContactInset
```

Those are symptoms of the old architecture.

### Coordinate system

Use **output-local logical coordinates** as the registry contract.

Conversion rules:

1. Source Item/controller maps its live rect into output/window coordinates.
2. Registry stores logical coordinates.
3. Renderer receives device-pixel ratio separately and handles AA in the rendering layer.
4. Fractional scaling tests must verify the same silhouette at DPR 1.0 and fractional output scales.
5. Never bake AA compensation into semantic rects.

### Frame record

The prototype frame should reproduce the locked Screen Edge/Bar silhouette numerically but must not modify production `ScreenEdges.qml`.

The PoC may derive the same configured:

- screen-edge width;
- screen rounding;
- Bar thickness/orientation;
- Bar visibility/ownership.

The locked production frame remains untouched until cutover is explicitly approved.

### Popup record

The PoC popup rect should be driven from a live source anchor:

```text
module Item
  -> source/output mapping
  -> popup layout/clamp
  -> registry rect
```

Move/reorder the source and require that only the rect changes.

### Required topology tests

1. module centered on horizontal top Bar;
2. module near left side;
3. module near right side;
4. popup clamped to Screen Edge;
5. bottom Bar;
6. left Vertical Bar;
7. right Vertical Bar;
8. popup opening/closing while source moves;
9. fractional scale;
10. two simultaneous registered popup shapes for stress, even if production only allows one at first.

### Strict PoC rejection condition

Reject the design if the renderer needs source-specific code such as:

```text
if battery ...
if clock ...
if atRightEdge then draw corner ...
```

The only accepted special distinction should be generic shape types/material roles needed by the SDF model.

---

## 12. Animation contract

Animation should change **shape parameters/rects**, not swap corner assets.

For a connected popup:

- body rect slides from behind/inside the owner region into resting rect;
- SDF recomputes continuously;
- union shoulder emerges naturally;
- no bounce/overshoot that visually detaches the silhouette.

The previous discussion preferred monotonic connected motion. That remains a good target, but do not modify current production animation until the new renderer is proven.

Bar module reorder should be treated as live geometry movement. The union should follow continuously without explicit corner transitions.

---

## 13. Shadow strategy

Caelestia's common-surface model makes a strong case for **one shadow for the resulting union**, rather than separate Screen Edge and popup shadows that must meet perfectly.

For the PoC:

- first validate fill silhouette with no shadow;
- then add a shadow from the union alpha/SDF;
- compare with current locked Screen Edge shadow visually;
- do not change production shadow ownership during PoC.

A production migration gate should require equivalent or better:

- no double shadow at joins;
- no shadow gap;
- no shadow discontinuity during module movement;
- acceptable GPU cost.

---

## 14. Blur strategy to research next

This remains unresolved and is one of the top three blockers.

Questions:

1. Can a full-output input-transparent Top-layer visual host request compositor blur only inside the union shape via a Quickshell `BackgroundEffect.blurRegion`/mask that follows the renderer?
2. Does Niri honor dynamic complex blur regions at the required cadence?
3. If blur region can only be described with ordinary regions/items, can the SDF host expose a conservative rectangle union without visibly blurring outside material?
4. Is the current Material default usually opaque enough that unified blur can be deferred?
5. How should Settings Overlay handle blur behind its Overlay-layer scrim/card domain?

PoC should begin with opaque Material fill so SDF correctness is isolated from blur.

---

## 15. Native renderer/API research to do before coding it

If the QSB PoC passes, study a minimal native plugin rather than copying all Caelestia physics/features.

Likely minimal types:

```text
Hadalis.Surface
├── SurfaceGroup
├── SurfaceRect
├── SurfaceFrame / SurfaceInvertedRect
└── internal SurfaceMaterial
```

Do not initially port:

- spring deformation;
- velocity physics;
- unrelated blob effects;
- general feature registries;
- arbitrary legacy compatibility.

Production renderer requirements:

- dynamic child shape discovery/registration;
- dirty flags only when shape/material data changes;
- bounded geometry around affected regions where possible;
- one material/shader per composition domain;
- deterministic logical->device coordinate transform;
- no source-module-specific branches;
- stable hot reload behavior;
- explicit missing-plugin fallback.

License note: both Hadalis and Caelestia repositories are GPL-family compatible for adaptation, but copied/adapted source must retain the appropriate notices and attribution. Re-check exact per-file headers before porting code.

---

## 16. Native vs QSB PoC recommendation

Recommended sequence:

### Phase U0 — research completion

No production changes.

Close the remaining questions:

- Niri visual-host stacking/lifetime;
- compositor blur ownership;
- package/import path for native plugin;
- exact minimal SDF equations needed from Caelestia;
- performance budget.

### Phase U1 — isolated QSB PoC

Create a non-production prototype that:

- uses one visual window/domain;
- draws frame + one moving rounded popup rect;
- does smooth union/sink;
- consumes a live/fake moving anchor;
- has no corner-specific code;
- measures GPU/frame cost.

The prototype may use a fixed small shape array because it is a math/topology experiment, not the final registry implementation.

### Phase U2 — dynamic registry PoC

Only after U1 passes:

- define renderer-independent registry;
- test module reorder and multiple rects;
- validate DPR/fractional scaling and multi-monitor mapping.

### Phase U3 — choose renderer

If QSB cost/API is acceptable, a pure shader host may remain viable.

If not, implement minimal native QSG module behind the **same registry contract**.

### Phase U4 — first production cutover

Cut over only:

- Screen Edge/Bar visual background;
- one class of `StyledPopup`.

Keep content/input windows unchanged.

No Sidebar/Dashboard/Settings migration yet.

### Phase U5+

Migrate each surface class only after the previous class passes visual/runtime gates.

---

## 17. Production migration gates

Each cutover must pass all applicable gates.

### Visual

- one continuous silhouette;
- no 1 px seam in light or dark theme;
- no floating/offset corners;
- no double border;
- no double shadow;
- popup contact follows live module movement;
- correct topology near every screen edge;
- correct fractional scale.

### Runtime

- no popup hover/open-close regression;
- no blank Bar after fullscreen;
- no remap/stacking regression on Niri;
- hotplug/multi-monitor stable;
- no stale geometry after Bar reorder;
- no input interception by visual host.

### Performance

Establish baseline and candidate measurements:

- idle GPU cost;
- opening animation;
- module reorder;
- one popup;
- multiple shapes;
- 1080p/1440p/4K if practical;
- fractional scale.

Do not accept a visually correct full-screen shader if it creates unacceptable continuous fill-rate cost.

### Packaging

Before native renderer promotion:

- repo-copy lifecycle is specified;
- Arch package exists;
- Nix package/variant exists;
- plugin discovery is deterministic;
- missing/incompatible plugin fails clearly;
- no runtime compilation/download.

### Rollback

Every production phase should remain switchable back to the current baseline until that phase is certified.

Do not delete old connected-surface implementation in the same commit that first enables the new renderer.

---

## 18. Parts likely to remain vs retire

### Likely to remain

- Bar module layout/reordering logic;
- source Items and hover targets;
- `StyledPopup` semantic open/close state;
- anchor/output ownership logic;
- click-outside/focus handling;
- content windows;
- Screen Edge configuration tokens;
- current locked physical dimensions/radii as input parameters;
- Sidebar/Dashboard/Settings content trees.

### Likely to change

- ownership of Bar/Screen Edge/popup backgrounds;
- popup visual background path;
- shadow ownership;
- blur ownership;
- surface/background masks.

### Likely to retire after successful cutover

- `ConnectedSurfaceJoinFlares` as the contact topology solution;
- explicit corner/edge join routing used solely to synthesize shoulders;
- contact-inset/contact-plane compensation logic;
- duplicate per-consumer seam fixes;
- any corner asset whose only job is to fake union between independent silhouettes.

Do not retire them before the new composition domain has proven production parity.

---

## 19. Open questions

### Highest priority

1. **Niri stacking/lifetime**
   - Can the proposed visual host remain below all content windows it supports without remap-related reorder?
   - Is `Top` sufficient for Bar popouts that currently use `Overlay`, or does the visual background need its own Overlay-domain host?

2. **Blur/material**
   - How to transfer native compositor blur from current Bar/popup windows to a unified visual host without over-blurring the output?
   - How to handle transparent Material configurations and wallpaper fallback effects?

3. **Native plugin lifecycle**
   - What exact package/import strategy preserves the simplicity of `inir update`?
   - Should repo-copy users require a separately installed `inir-surface-renderer` package?

### Secondary

4. How much of Caelestia's border-sink shader is needed for Hadalis' locked frame geometry?
5. Can a bounded ShaderEffect prototype render only an affected strip/union bbox instead of full output?
6. How should auto-hidden Bar geometry participate while hidden/revealing?
7. How should Settings Overlay form a local composition domain under its scrim?
8. Should Dashboard visually union with Screen Edge through the global edge domain, or a local domain whose host is correctly layered?
9. How many simultaneous shapes must production support?
10. How should shadow and blur bounds expand the renderer's dirty/bounding geometry?

---

## 20. Immediate next research tasks

Do these **before writing production code**:

1. Trace exact layer-shell stacking and remap behavior for:
   - ScreenEdges FrameWindow;
   - Bar;
   - StyledPopup;
   - a hypothetical visual host.
2. Prototype/inspect Quickshell blur-region possibilities for an input-transparent visual host.
3. Design native plugin install/import lifecycle for repo-copy, Arch and Nix.
4. Extract the minimum Caelestia SDF equations/data layout required for:
   - rounded rect;
   - inverted frame;
   - smooth union;
   - border sink.
5. Define a renderer-neutral registry API and shape-count budget.
6. Specify an isolated U1 PoC that does not touch current production surfaces.

No commit beyond documentation should be made until those points are understood well enough to choose the PoC implementation deliberately.


---

## 21. U0 blocker resolution — 2026-09-20 continuation

This section records the research performed after the initial handoff. It is still
**research/design only**. No production surface, renderer, package, or geometry was
changed by this work.

Research was resumed from \`dev\` at:

- \`7ae39986719b0127c24c10ade9b8ec1ad84c32fb\`
- \`docs(surface): capture unified composition research handoff\`

That commit is exactly one commit above the research synchronization point
\`c233d1c4aaac911d7fd2e8daac9fb3857f740860\`, and its only changed files are:

- \`docs/UNIFIED_SURFACE_HANDOFF.md\`
- \`docs/UNIFIED_SURFACE_RESEARCH.md\`

Therefore the handoff commit itself did not alter any production file and did not
resurrect the reverted Canvas/flare/contact-plane work.

### 21.1 Niri/Smithay same-layer lifetime is not stack-neutral

Current Niri maps layer surfaces through Smithay's \`LayerMap\`. Smithay stores
mapped layer surfaces in an insertion-ordered \`IndexSet\`:

- \`map_layer()\` inserts a newly mapped surface;
- \`unmap_layer()\` removes it with \`shift_remove()\`;
- a later remap inserts it again at the end;
- Niri reverses the layer iterator to obtain its render/input order.

Niri's own render code explicitly says that \`LayerMap\` returns layers in reverse
stacking order and applies \`.rev()\` for rendering. Its input lookup uses the same
reversed ordering.

Architectural consequence:

> A visual host whose relationship to other same-layer Hadalis surfaces matters
> must remain mapped. Shape enable/disable, opacity and registry membership may
> change; the host's Wayland surface lifetime must not be used as an animation or
> visibility mechanism.

This independently validates the existing Hadalis fullscreen lifecycle locks on
\`ScreenEdges.FrameWindow\` and the Bar.

Upstream references inspected:

- Niri \`src/handlers/layer_shell.rs\`, current main during research:
  \`7256ccf6274a1f953c6987ade34ea1c0e4944c27\`
- Niri \`src/niri.rs\`, especially \`layers_in_render_order()\`
- Smithay \`desktop/wayland/layer.rs\`, \`LayerMap::{map_layer,unmap_layer,layers_on}\`

### 21.2 Top cannot be the sole visual domain for an Overlay popout

Current Hadalis layering is materially different between the perimeter and
popouts:

- \`ScreenEdges.FrameWindow\`: \`WlrLayer.Top\`
- Classic Bar: Top-layer panel semantics
- \`StyledPopup\` presentation window: \`WlrLayer.Overlay\`
- \`StyledPopup\` click-outside catcher: \`WlrLayer.Overlay\`
- Settings overlay: normally \`WlrLayer.Overlay\`, with deliberate temporary
  transitions to Bottom/Top for native-dialog/Polkit semantics.

Niri renders Overlay above the rest of the normal shell composition. It can render
fullscreen/overview content above Top while Overlay remains above it. Therefore a
Top-only material host cannot be the complete visual background for a popup whose
content intentionally remains Overlay: during fullscreen/overview the popup
content could remain visible while its Top-layer material disappears underneath
the client.

Rejected for the first production design:

1. moving existing Overlay popout content down to Top merely to share a host;
2. moving the persistent physical Screen Edge host permanently to Overlay;
3. repeatedly mapping/unmapping a second visual host to chase popup lifetime.

The preferred domain split is now:

\`\`\`text
Top base domain
  persistent physical perimeter / Bar material

Overlay attached-surface domain
  popup-local unified material
  = virtual owner edge/frame representation + popup rounded rect
  rendered inside the same Overlay scenegraph as the popup when possible
\`\`\`

The phrase "virtual owner edge/frame representation" does **not** mean a contact
patch. It is a generic frame/owner shape record evaluated by the same SDF as the
popup. The shader never selects a left/right contact corner. The popup's live
output-space rectangle is the only moving topology input.

For \`StyledPopup\`, the strongest first production candidate is therefore to keep
its full-output Overlay \`PanelWindow\` and let that window eventually render the
local unified SDF material behind its existing content. This avoids introducing a
second same-layer visual/content ordering relationship. The persistent Top frame
continues underneath; the Overlay domain draws only the affected attachment
region and visually occludes the identical material below it.

A separate persistent Overlay visual host remains possible later for domains with
multiple content windows, but it needs an explicit creation-order contract and
tests against other Overlay surfaces. It is no longer required for U1.

### 21.3 Blur is surface-owned protocol state, not shader-alpha state

Quickshell's \`BackgroundEffect.blurRegion\` is a client request through
\`ext-background-effect-v1\`. The protocol attaches the effect to one
\`wl_surface\` and accepts a copied \`wl_region\` in surface-local coordinates.
The blur region is double-buffered with the surface commit.

Niri's current implementation caches that blur region as rectangles and uses it as
a transformed subregion for the background effect.

Quickshell \`Region\` can compose regions and supports rounded-rectangle/per-corner
radii, but the protocol payload is still a Wayland region rather than an arbitrary
SDF/alpha texture.

Consequences:

- the SDF result cannot simply be passed as \`blurRegion\`;
- a loose bounding rectangle is unacceptable for translucent material because
  transparent pixels outside the SDF fill would expose blur that should not exist;
- compositor blur must be requested by the same Wayland surface/layer that owns
  the visible translucent material;
- Top and Overlay composition domains therefore need their own blur requests.

The production abstraction should be:

\`\`\`text
one renderer-neutral shape registry
    ├── SDF projection     -> fill / border / common shadow
    └── Region projection  -> compositor blur request
\`\`\`

The Region projection is generic geometry derived from the same shape records. It
must not contain source-module names or corner/contact flags.

Exact SDF-to-\`wl_region\` fidelity is not required for U1. A later production
experiment may compare:

- ordinary rounded-rect Region union;
- a bounded scanline/rect decomposition of the final SDF;
- disabling compositor blur for configurations where an accurate dynamic region
  is too expensive.

U1 deliberately uses opaque fill and no compositor blur so that field topology is
measured independently.

### 21.4 Shadow ownership belongs to the unified renderer

Niri layer-rule shadows are surface-geometry shadows. The compositor sees layer
surface geometry, not Hadalis' arbitrary SDF alpha silhouette. They are therefore
not a correct source for the future common connected-surface shadow.

Production target:

- unified renderer owns one shadow derived from the union field/alpha;
- content windows own no competing connected-body shadow;
- current Screen Edge \`MultiEffect\` and connected-popup shadows stay untouched
  until an actual migration phase.

U1 order remains:

1. prove fill;
2. optionally prove a field-derived shadow in a separate U1b step;
3. do not migrate production shadow ownership.

### 21.5 Settings remains a local Overlay composition domain

\`SettingsOverlay.qml\` currently combines:

- a full-output Overlay window;
- optional full-screen \`GlassBackground\` backdrop blur;
- scrim dimming;
- click-outside interaction;
- a Settings card with its own existing depth treatment;
- special layer changes for native dialogs and Polkit.

Its card material must not be moved into the persistent Top edge domain. If/when
Settings receives SDF attachment behavior, it should be composed inside the
Settings Overlay domain so the ordering remains:

\`\`\`text
background/app
  -> Settings backdrop blur
  -> Settings scrim
  -> Settings unified card/edge material
  -> Settings content
\`\`\`

This closes the earlier question of whether one global visual host should own
Settings: it should not.

---

## 22. QSB versus native QSG — architecture decision for the PoC

### 22.1 U1 uses QSB

U1 should use a QML \`ShaderEffect\` with a committed precompiled \`.qsb\`.

Reasons:

- Hadalis already ships and loads \`FluidRipple.qsb\` by relative URL;
- Qt 6 \`ShaderEffect\` is explicitly designed to consume offline-compiled QSB
  shader packs;
- no new C++ QML module or ABI is required;
- repo-copy/source installs can consume a committed QSB exactly like the existing
  shader asset;
- U1 needs to validate field math and bounds, not a native registry implementation.

The shader compiler is a **developer/build-time** dependency only. Runtime must
never compile or download shader source.

### 22.2 Native QSG remains a production candidate, not a U1 prerequisite

Caelestia's current Blob implementation confirms the production benefits of native
QSG:

- bounded QSG geometry rather than one permanent full-output fragment pass;
- C++ shape/group registry;
- one custom QSG material with batched shape uniforms;
- dirty/polish updates localized to affected shapes;
- the inverted frame is rendered as four frame strips with an inner hole rather
  than a full-screen quad.

But this requires a compiled QML module. Caelestia builds \`Caelestia.Blobs\`
with \`qt_add_qml_module()\`, compiles shaders with \`qt_add_shaders()\`, and
installs the backing library, plugin, \`qmldir\`, and typeinfo under the Qt QML
import hierarchy.

Hadalis must not add that infrastructure merely to run U1.

### 22.3 Proposed native package boundary if U3 selects QSG

If U3 demonstrates that QSB cannot meet the production shape-count/fill-rate
budget, the native module should be a separate capability package:

\`\`\`text
URI: Hadalis.Surface

SurfaceGroup
SurfaceRect
SurfaceFrame
internal SurfaceMaterial
\`\`\`

Suggested installation boundary:

\`\`\`text
Arch:
  /usr/lib/qt6/qml/Hadalis/Surface/
    qmldir
    *.qmltypes
    plugin/backing .so files as generated by Qt CMake

Nix:
  <store>/lib/qt-6/qml/Hadalis/Surface/
\`\`\`

Use \`qt_add_qml_module()\` and \`qt_add_shaders()\`; do not hand-maintain plugin
metadata that Qt can generate.

The Code Workflow parser packaging is useful only as a **lifecycle pattern**:

- native capability has its own Arch/Nix package;
- runtime shell can remain separately deployable;
- developer-only build helper does not install into runtime.

It is **not** a direct technical template because the workflow parser is loaded as
a native grammar/library, not as a Qt QML plugin.

### 22.4 Repo-copy and fallback contract for a future native renderer

A future native renderer must not turn \`inir update\` into a compiler.

Recommended contract:

\`\`\`text
repo-copy/default capability:
  committed QSB renderer available

package-manager enhanced capability:
  optional/required Hadalis.Surface native QML module
  wrapper exposes deterministic capability flag/import path
\`\`\`

Do not statically import an optional native module from a QML file that must also
work without it. Keep native and QSB renderer implementations in separate lazily
loaded QML files, so the fallback file can load without parsing
\`import Hadalis.Surface\`.

Qt plugin compatibility also matters: Qt rejects plugins built against a higher
minor Qt than the runtime's lower minor, and binary compatibility assumes a
compatible toolchain/system environment. Arch/Nix packages should therefore
rebuild the renderer as part of normal Qt package rebuilds rather than treating
the plugin as a forever-compatible copied binary.

No runtime download/build path is approved.

---

## 23. Minimum Caelestia Blob model actually needed by Hadalis

Current Caelestia \`blob.frag\` contains substantially more behavior than Hadalis
needs initially. The minimum transferable mathematical model is:

### Rounded rectangle SDF

U1 needs one rounded rectangle distance function. Per-corner radii may be kept in
the shader API for future use, but the first popup can use one radius.

Conceptually:

\`\`\`text
dRect = sdRoundedBox(pixel, center, halfSize, radius)
\`\`\`

### Circular smooth union

Caelestia currently uses a circular smooth minimum whose support is local to the
two fields:

\`\`\`text
smin(a, b, k)
\`\`\`

U1 should use the same class of operation rather than a hand-drawn shoulder.

### Inverted frame

The physical perimeter is represented as outer box minus rounded inner workspace:

\`\`\`text
dOuter = sdBox(...)
dInner = sdRoundedBox(...)
dFrame = smooth-max(dOuter, -dInner, kFrame)
\`\`\`

\`kFrame\` must be clamped to the thinnest frame side so the smooth-max fillet
cannot exceed the available border thickness.

The locked Hadalis Screen Edge/Bar dimensions are inputs to this frame record.
U1 does not modify \`ScreenEdges.qml\`.

### Border sink

A plain union between a popup and an inverted frame is not always sufficient to
produce the Caelestia-style owner edge yielding around the entering body.

The minimum generic sink model is:

1. for each frame side, compute how far the popup's opposite edge has penetrated
   past the frame's inner wall;
2. clamp that penetration to the physical frame thickness;
3. weight it by lateral distance from the popup extent and perpendicular proximity
   to the relevant inner wall;
4. take the maximum generic sink contribution;
5. subtract it from \`dInner\`;
6. rebuild \`dFrame\`;
7. smooth-union the popup field with the frame field.

This may use four frame-side distance calculations because the frame itself has
four sides. It must not branch on popup/module identity, source position labels or
contact-corner flags.

### Bounding/fill-rate strategy

Caelestia does not rely on a permanent full-output fragment pass. Its native
inverted frame uses explicit frame-strip geometry and regular blob shapes use
padded bounds.

The QSB U1 analogue should be:

- one full-output **window/coordinate domain**;
- one **bounded ShaderEffect item** covering only the popup plus the neighboring
  owner-frame region, expanded by smoothing/AA/shadow padding;
- pass \`effectOrigin\` so the fragment shader still evaluates in output-local
  logical coordinates;
- include a diagnostic full-output mode only for correctness/performance
  comparison.

This preserves one scenegraph/field while avoiding full-screen fill rate in the
normal PoC path.

Do not split the contact into separate corner ShaderEffects.

---

## 24. Exact isolated U1 SDF PoC specification

U1 is now sufficiently specified to implement later, but this research commit does
**not** implement it.

### 24.1 Isolation boundary

Proposed location:

\`\`\`text
scripts/unified-surface/
  U1Shell.qml
  U1Surface.qml
  U1Surface.frag
  U1Surface.qsb
  README.md
  build-shader.sh      # developer-only; optional
\`\`\`

No production module imports U1.

No changes to:

- \`modules/screenCorners/ScreenEdges.qml\`
- \`modules/bar/Bar.qml\`
- \`modules/bar/StyledPopup.qml\`
- Sidebar/Dashboard/Settings production files
- existing connected-surface helpers

### 24.2 Host contract

U1 creates one full-output, input-transparent \`PanelWindow\` on one selected
output.

Required properties:

- transparent window color;
- \`ExclusionMode.Ignore\`;
- zero-size/click-through input mask;
- persistent mapping for the lifetime of the test;
- no \`visible\` toggling while shapes animate;
- no exclusive zone;
- explicit test layer chosen at launch.

Run the same PoC separately in:

- Top mode, to reproduce the perimeter host semantics;
- Overlay mode, to validate the local popup-domain semantics.

Do not change layer dynamically in one mapped instance because that would
confound the stacking/lifetime test.

### 24.3 Registry contract used by U1

U1 may use fixed properties rather than a dynamic model. The data contract still
matches the future registry:

\`\`\`text
outputSizeLogical

frame:
  outerRect
  innerRect
  innerRadius
  sideInsets

popup:
  enabled
  rect
  radius

material:
  color
  smoothK
\`\`\`

Coordinates are output-local logical coordinates.

Not allowed:

\`\`\`text
joinTop
joinBottom
joinLeft
joinRight
leftFlare
rightFlare
contactInset
moduleName
batterySpecialCase
\`\`\`

### 24.4 Shader uniforms

Minimum U1 uniforms:

\`\`\`text
qt_Matrix
qt_Opacity

effectOrigin
effectSize
outputSize

frameOuter
frameInner
frameRadius

popupRect
popupRadius
popupEnabled

smoothK
materialColor
\`\`\`

Fragment-space output coordinate:

\`\`\`text
pixel = effectOrigin + qt_TexCoord0 * effectSize
\`\`\`

The shader owns only SDF evaluation and material output. Popup placement/clamping
remains a controller/layout concern.

### 24.5 Moving source/anchor

The first test source can be synthetic:

\`\`\`text
fake module x/y
  -> ordinary popup placement/clamp function
  -> popup output-local rect
  -> shader uniform
\`\`\`

Animate/sweep the fake module through the Bar rather than dragging inside the
input-transparent visual host.

A second U1 run may feed a real Bar module anchor through the existing
\`StyledPopup\`-style mapping semantics, but still must not replace production
popup rendering.

The renderer sees only the resulting popup rectangle. It does not know which
module produced it.

### 24.6 Bounded effect rectangle

Normal mode computes a CPU/QML bounding box from:

- popup rect;
- the adjacent frame strip needed for the field interaction;
- \`2 * smoothK\` safety padding;
- one AA pixel in physical space;
- future shadow padding when U1b is enabled.

The effect rectangle may extend to the screen corner when the popup is near an
edge. This is enough for corner topology tests without shading the entire output.

Diagnostic mode renders the same equations full-output. For identical uniforms,
pixels inside the bounded region must match the full-output reference within the
normal AA tolerance.

### 24.7 Test matrix

Required geometry cases:

| Axis | Cases |
| --- | --- |
| Horizontal Bar | top-center, top-left, top-right, bottom-center, bottom-left, bottom-right |
| Vertical Bar | left-center, left-top, left-bottom, right-center, right-top, right-bottom |
| Clamp | popup unclamped, clamped to each applicable screen side |
| Motion | slow sweep, fast sweep, opening/closing while source moves |
| Scale | 1.0, 1.25, 1.5, 1.75, 2.0 where compositor setup permits |
| Resolution | 1080p, 1440p, 4K where available |
| Shape stress | one popup, then two generic popup records in diagnostic extension |

Top/bottom/left/right variants must be produced by frame/rect data, not separate
shader source variants.

### 24.8 U1 pass/fail gates

**Topology — PASS only if all hold**

- no visible transparent seam between frame and popup during static or moving
  attachment;
- no independently drawn corrective corner/flare exists;
- moving the source changes only popup placement data and the shoulder follows;
- near-screen-edge clamping does not require a topology flag;
- top/bottom/left/right use the same shader equations;
- bounded and full-output reference renders agree inside the bounded region.

**Scale/AA — PASS only if all hold**

- no persistent 1-physical-pixel gap appears at tested fractional scales;
- semantic logical rects are not modified by AA compensation;
- AA is derived from the field derivative/\`fwidth\`, not magic offsets.

**Lifetime/input — PASS only if all hold**

- visual host intercepts no pointer/keyboard input;
- moving/opening/closing test shapes never unmaps/remaps the host;
- Top-mode test survives enter/exit fullscreen without a blank/reordered PoC host;
- Overlay-mode test remains visually above fullscreen as expected.

**Performance — PASS only if all hold**

Measure a control scene, bounded U1, and diagnostic full-output U1 under the same
refresh/resolution.

- bounded U1 creates no sustained idle animation/redraw once geometry is still;
- moving-shape p95 frame time is no more than 10% above the control scene;
- missed-frame ratio increases by no more than 1 percentage point relative to the
  control scene;
- bounded U1 must materially outperform the full-output diagnostic at 1440p/4K;
  if it does not, investigate before U2;
- any configuration that only works acceptably by leaving a permanent full-output
  shader active is not automatically eligible for production.

The relative gates are intentional: they avoid inventing an absolute GPU
millisecond budget that would be meaningless across user hardware.

**Architecture — FAIL immediately if any hold**

- shader/QML code contains module-specific contact branches;
- a contact plane is shifted solely to hide AA/compositor cracks;
- the PoC requires production \`ScreenEdges\`, Bar or \`StyledPopup\` geometry to
  change;
- runtime needs \`qsb\`, a compiler, CMake, network access or a native plugin;
- blur correctness is used to excuse an SDF topology defect.

### 24.9 U1 rollback

U1 is additive under \`scripts/unified-surface/\`. Rollback is deletion of that
directory plus its research-only launch instructions.

Because no production file references U1, rollback must leave the installed shell
byte-identical to the pre-U1 production behavior.

---

## 25. Decision gates after U1

If U1 fails field topology, stop and revise the mathematical model. Do not proceed
to registry or package work.

If U1 passes topology but fails bounded performance, investigate a minimal native
QSG renderer under the same data contract.

If U1 passes both topology and performance, proceed to U2 and test a real dynamic
shape registry before deciding whether native QSG is necessary.

Only U3 may choose the production renderer.

Production cutover still requires explicit maintainer approval and remains
separate from this research/documentation work.


---

## 26. U0.5 and U1 implementation status — 2026-09-20

The maintainer explicitly approved starting the isolated PoC after the U0 research
phase. U1 now exists under `scripts/unified-surface/`; it is still not imported
by the production shell and remains excluded from the runtime payload.

### 26.1 What was implemented

Current U1 files include:

```text
scripts/unified-surface/
  shell.qml
  U1Shell.qml
  U1Surface.qml
  U1Surface.frag
  U1Surface.qsb
  build-shader.sh
  verify-shader-package.sh
  smoke-headless-sway.py
  validate-live-niri.py
  run-u1.sh
  README.md
```

The implementation preserves the architecture constraints established above:

- one persistent input-transparent layer-shell visual host per test output;
- output-local logical geometry;
- bounded ShaderEffect by default plus full-output diagnostic mode;
- rounded-rect SDF + inverted frame + smooth union + generic border sink;
- no Canvas/contact flares;
- no `contactInset`, contact-plane offsets, manual join-corner selection or
  module-specific shader branches;
- source movement changes only generic popup placement data;
- no production `ScreenEdges`, Bar, `StyledPopup`, Sidebar, Dashboard or
  Settings files are imported or modified by U1.

### 26.2 QSB pipeline result

U1 stores GLSL source and a committed precompiled QSB. Runtime never needs
`qsb`, CMake, a compiler or a network connection.

An important build-system finding was that the Qt 6.4 QShader package container
is not byte-deterministic across equivalent bakes. Therefore raw QSB SHA equality
is not a valid reproducibility gate.

The accepted gate is semantic package equivalence:

- reflection metadata after JSON normalization;
- SPIR-V payload;
- GLSL ES 300 payload;
- GLSL 330 payload.

This gate is implemented by `verify-shader-package.sh` and passes in the
dedicated U1 workflow.

Relevant commits:

- `b9f376318a2d541734a24208caa679d4fb07b456` —
  `feat(surface): add isolated U1 SDF prototype source`
- `084e3fe16b4ed5f246e7a67205bc9841d706ce67` —
  `build(surface): update U1 shader artifact`
- `2a788d71758dea370b288621c1575e665ec461a6` —
  `test(surface): compare U1 shader semantics`

### 26.3 CI vs live-GPU validation split

The first headless attempt correctly exposed that a GitHub-hosted runner with a
Pixman-only headless compositor cannot honestly validate ShaderEffect pixels:
Qt Quick could not create the required RHI/GLES context.

The CI architecture was therefore corrected rather than hiding the failure:

- CI uses an owned Sway headless compositor + Pixman + Qt Quick software backend
  only for QML/layer-shell lifecycle in U1 `control` mode;
- QSB executable semantics are checked separately;
- actual SDF pixels/topology remain a local-GPU nested-Niri gate.

The dedicated `Unified Surface U1 Shader` workflow passed on
`8bf0483b4ef9d0354930a370ced7020d0db226f4`, including:

- canonical QSB semantic verification;
- static architecture contract;
- Top/Overlay control-mode layer-shell startup/lifetime smoke;
- QSB artifact upload.

The general repository CI may still fail or be cancelled because unrelated
baseline contracts/Code Workflow work run concurrently; do not reinterpret those
unrelated results as U1 renderer evidence.

### 26.4 Live nested-Niri validator

`validate-live-niri.py` starts a fresh nested Niri inside the current Wayland
session and never edits/reloads the host Niri config.

Static topology coverage:

- scales: 1.0, 1.25, 1.5, 1.75, 2.0 for the full matrix;
- edges: top, bottom, left, right;
- generic source positions: 0.02, 0.5, 0.98;
- bounded vs full-output reference rendering;
- strong-material connected-component test;
- bounded/full mask IoU;
- ordinary screen-edge clamp verification;
- DPR reporting without assuming DPR equals fractional output scale.

Lifecycle coverage added in
`8bf0483b4ef9d0354930a370ced7020d0db226f4`:

- source motion is traced while the Wayland client protocol log must show exactly
  one `get_layer_surface` creation for the U1 namespace;
- reveal animation likewise must not recreate the layer surface;
- moving captures at left/center/right must remain one dominant connected
  material component;
- a test-only normal `FloatingWindow` is fullscreened by the nested Niri IPC;
- Top mode must return to the same material after fullscreen exits;
- Overlay mode must remain visible above fullscreen content;
- fullscreen enter/exit must not remap the U1 layer surface.

The fullscreen probe is test-only and is created only when
`HADALIS_U1_FULLSCREEN_PROBE=1`.

### 26.5 Current gate

U0.5 is complete enough for implementation work.

U1 source/build/control-lifecycle gates are complete and passing.

**U1 is not yet accepted as topology/performance complete** until the live
nested-Niri GPU validator is run on real hardware and the required matrix passes:

```sh
python3 scripts/unified-surface/validate-live-niri.py \
  --scales 1 1.25 1.5 1.75 2 \
  --benchmark
```

Do not begin U2 production integration merely because CI is green. The next
decision must be based on the live report:

- topology/AA/lifecycle PASS + bounded performance PASS -> proceed to U2 dynamic
  registry research/PoC;
- topology failure -> revise SDF math only;
- bounded performance failure -> evaluate minimal native QSG behind the same
  renderer-neutral contract;
- any need for module-specific contact patches -> reject the direction before
  production integration.


---

## 27. U1 junction morphology correction and exaggerated diagnostic preset

A follow-up visual report showed that the old production Canvas shoulder could
appear below the popup rather than at the owner seam. That production path is
still intentionally untouched during this research pass; moving the Canvas
would only recreate the rejected contact-plane/flare patch cycle.

The isolated U1 model was re-audited against current Caelestia Blob behavior.
Two corrections are now considered essential:

1. the resting popup rectangle is flush with the inverted frame's inner boundary;
   there is no permanent attachment-depth penetration;
2. effective popup corner radii are derived from each corner's signed distance
   to the inverted frame inner box, matching Caelestia's inverted-frame
   `cornerFill` behavior. Corners at the visible junction reduce toward the
   minimum radius while free/deep-workspace corners retain their normal radius.

A scalar/raster comparison of the same equations at `smoothK=20`, `26`, and
`32` confirmed that the visible outward shoulder width is controlled primarily
by the smooth-union radius, not by increasing popup radius alone. For easier live
inspection without changing topology, U1 therefore uses an intentionally
exaggerated diagnostic default:

```text
frameRadius = 25    # unchanged physical-frame baseline
popupRadius = 32    # +4 for clearer free-corner transition
smoothK = 28        # larger visible junction shoulder
```

These numbers are **not production values**. They exist only to make placement
errors unmistakable during U1 validation. The shader equations, registry
contract and forbidden-token rules are unchanged.

The corrected shader was baked by the dedicated workflow from commit
`4b32d9b2396122e9af4e0a7752b245e930509e2c`. The freshly baked QSB is 7248
bytes with SHA-256
`a06771d24e1e135103343adc0fe7a7002b2d7556c7f3e5f1cc99f2a85f71579a`.
That artifact is now the canonical U1 package for this corrected field model.

### 27.1 Production-faithful tangent clamp

A second U1 fidelity audit found that the synthetic placement controller still
clamped tangent geometry to the output outer rectangle (`0..width/height`).
Production `StyledPopup` does not do that: it passes
`screenMargin = screenEdgeThickness` to `ConnectedSurfaceGeometry`, so the
body stops at the physical Screen Edge's inner boundary.

U1 now clamps tangent placement and maximum popup extent to `frameInner`.
The live validator's extreme-source assertion uses the same inner bounds.
This is important because a popup at x=0 is a different SDF topology from a
production popup at x=screenEdgeThickness; keeping the former would make corner
validation near the display edge misleading.

### 27.2 Padded outer frame fidelity

U1 originally set `frameOuter = outputRect`. That differs from both current
Caelestia and Hadalis production geometry. Caelestia expands
`BlobInvertedRect` by 50px, while `ScreenEdges.qml` locks
`outerPadding = 50` and subtracts the same inner workspace hole.

The difference is mathematically relevant. With an unpadded outer rect and a
10px Screen Edge, U1's global minimum frame thickness forces `frameK` down to
roughly 9px. With a 50px padded outer rect, the off-screen frame thickness is
large enough for the full diagnostic `smoothK=28` to shape the inner wall.

U1 now uses a generic `outerPadding` input with default 50. The output-local
window/effect bounds are unchanged; only the SDF outer rectangle extends beyond
the clipped output. No production geometry is modified.

### 27.3 Border-facing SDF compression

The corrected static junction still omitted one current Caelestia behavior:
while a BlobRect is near an inverted border, its SDF is compressed on the axis
facing that border. Caelestia derives this entirely from rectangle/frame
distances and the local SDF gradient/face direction; the maximum boost is 3
(`scale <= 4`).

U1 now mirrors that operation as `borderFacingScale()`. It is deliberately
applied to the popup distance field, not to semantic popup geometry.

At the fully-open resting position the relevant border proximity is zero, so
the static diagnostic shoulder (`smoothK=28`) is unchanged. During
reveal/retract, compression narrows the circular-smin influence while the popup
rectangle is inside/behind the owner band, reducing residual workspace bulge
without inventing a close-state offset or contact-side branch.

This closes another fidelity gap between U1 and the actual Caelestia Blob field.
The remaining acceptance question is live pixel behavior, not another geometry
patch.

### 27.4 Explicit shoulder-position acceptance gate

The original topology validator could prove connectivity while still accepting
the maintainer's reported visual defect: a corrective corner may be connected
but buried underneath the popup body.

The live validator now measures **junction morphology** from the rendered GPU
mask. For every free tangent side it samples two cross-sections:

1. near the owner seam at `0.25 * smoothK`, where a real unified circular
   shoulder must extend visibly outside the popup side;
2. deeper in the body near `0.95 * smoothK`, where that extension must have
   tapered back toward the ordinary popup edge.

At the current enlarged research preset (`smoothK=28`), a scalar reference of
the exact U1 equations gives about 9 logical pixels of exposure at the near
sample and approximately 0px by the deep sample. The live GPU capture is still
authoritative; these values only informed conservative relative thresholds.

The validator infers whether a tangent side is Screen-Edge-clamped from
`frameInner` and popup geometry. The renderer itself remains free of join flags.

This converts the reported visual requirement into an acceptance property:
**the shoulder must live at the owner/popup junction and taper there, not merely
exist somewhere underneath the popup.**

Next acceptance remains live nested-Niri GPU validation. If the enlarged
diagnostic morphology still places the shoulder on the wrong side of the popup,
do not add offsets or resurrect `ConnectedSurfaceJoinFlares`; revert the U1
morphology experiment and continue field-model research.


### 27.5 Caelestia popout overlap does not justify attachmentDepth

The real Caelestia popout placement was traced from
`modules/drawers/ContentWindow.qml` and `modules/bar/popouts/ClipWrapper.qml`.

For the normal attached left-Bar popout, Caelestia's BlobRect is intentionally
wider than the visible popout:

```qml
property real extraWidth: panels.popouts.isDetached ? 0 : 0.2
x: ... + bar.implicitWidth - panels.popouts.width * extraWidth
implicitWidth: panels.popouts.width * (1 + extraWidth)
```

So the visual BlobRect extends under the owner Bar. The code comment states why:
the extra width prevents movement/deformation from partially detaching the panel
from the Bar.

That overlap is **not evidence that Hadalis U1 should restore the rejected
`attachmentDepth`**.

A scalar comparison using the exact current U1 field at the enlarged
`smoothK=28` tested owner overlap depths of 0, 18, 44 and 60 logical pixels.
Once the popup reaches the visible owner seam, all four produced the same
workspace-side shoulder profile:

- about 20.5px outward exposure 1px inside the seam;
- about 9px at 7px depth;
- about 3.5px at 14px depth;
- approximately 0px by 24px depth.

The under-owner extension matters for deformation/reveal retention, but not for
the static visible shoulder in the minimal non-deformed U1 model. Therefore:

- keep U1's semantic resting edge flush with `frameInner`;
- do not reintroduce a magic penetration/contact offset;
- if later production deformation needs hidden backing extent, model that as a
  generic **visual field extent**, separate from content/input geometry and
  separate from the owner seam.

### 27.6 Production Overlay projection requirement

A production-specific issue is now explicit.

`StyledPopup` is a full-output **Overlay** layer-shell window. The real
Screen Edge frame is **Top**, and Bar foreground/modules are also owned below the
popup Overlay domain. If the eventual Overlay SDF renderer outputs the complete
unified field, its opaque owner-band pixels would cover Bar icons/modules.

The correct hybrid-domain rule is therefore:

```text
evaluate:
  complete unified field
  = virtual owner frame + animated popup rect

Top domain:
  real Screen Edge / Bar material + Bar foreground remain authoritative

Overlay popup domain:
  output only the unified field's workspace-side projection
  (inside the base frameInner/workspace hole)
  + popup content/input
```

This is **not** a flare/contact patch. The renderer still evaluates one generic
frame/popup field with no module identity and no join flags. The projection only
decides which pixels this composition domain is allowed to own.

The workspace projection must use the base rounded `frameInner` SDF, before any
dynamic border-sink modification. That preserves the physical owner boundary
while allowing the popup/shoulder field to extend naturally into the workspace.

This also explains why putting the SDF directly inside the existing
`ConnectedSurfaceRevealClip` is wrong: that clip removes the owner-side field
before composition and cannot represent the full mathematical union. Content may
remain reveal-clipped, while the material field must evaluate outside that clip
and then apply its renderer-domain projection.

Before production cutover, add an isolated U1 owner-probe test:

1. persistent Top probe paints high-contrast owner foreground;
2. Overlay U1 evaluates the full field but uses workspace projection;
3. the Top owner probe must remain visible;
4. the workspace-side shoulder morphology gate must still pass;
5. workspace-projected pixels must match the full-field reference inside the
   workspace domain.

Do not modify `StyledPopup` until this projection gate and the existing
live-GPU matrix pass.


---

## 28. Workspace projection PoC result and production cutover boundary

The Overlay-domain blocker identified in section 27.6 now has an isolated
implementation.

Relevant commits:

- `2120903bdf60c6cb96f368198dd554bcc2d996f8` —
  `research(surface): add workspace projection owner probe`
- `1b7ca94cfea983a0bc9fd4a2d834a6f9f55a5fec` —
  `build(surface): update U1 projection shader artifact`

Dedicated `Unified Surface U1 Shader` workflow for `1b7ca94...`: **PASS**.

It confirms:

- canonical QSB semantic equivalence;
- static architecture contract;
- QML/control-mode Top and Overlay layer-shell lifecycle;
- the projection shader package is loadable by the existing U1 pipeline.

Live GPU pixels remain a separate gate.

### 28.1 Projection model

The shader now preserves two related distance fields:

```text
dWorkspace
  = base rounded frameInner SDF
  = physical owner/workspace ownership boundary

dInner
  = dWorkspace - generic borderSink(...)

dFrame + dPopup
  -> complete smooth union
  -> merged
```

`projection=full` outputs the complete field.

`projection=workspace` still computes the same complete field, but multiplies
the final alpha by the antialiased inside mask of **base** `dWorkspace`.

This distinction matters: using the sink-modified `dInner` as the projection
boundary would let the Overlay domain dynamically claim owner-band pixels,
which could cover Top-layer Bar foreground. The immutable base inner boundary
keeps visual ownership stable.

### 28.2 Owner foreground probe

`U1OwnerProbe.qml` is a test-only, input-transparent Top-layer window. It paints
a high-contrast green marker in the owner band near the popup source.

The live nested-Niri validator now runs, for top/bottom/left/right:

1. Overlay `projection=full` + Top owner probe;
2. Overlay `projection=workspace` + Top owner probe.

The gate requires:

- full projection to occlude the marker, proving the test is sensitive;
- workspace projection to preserve the marker;
- workspace-projected material inside the workspace to match the full-field
  reference with IoU >= 0.995;
- the explicit shoulder-position/taper gate to continue passing.

This directly validates the hybrid-domain architecture needed by Hadalis:
Overlay owns only popup/workspace pixels while Top keeps Bar/Screen Edge
foreground authority.

### 28.3 Production primitive audit

Runtime search shows only two actual QML consumers of
`ConnectedSurfaceFrame`:

- `modules/bar/StyledPopup.qml`;
- `modules/waffle/bar/BarPopup.qml`.

Both already use:

- a full-output Overlay `PanelWindow`;
- `ConnectedSurfaceGeometry`;
- a fixed `ConnectedSurfaceRevealClip`;
- `ConnectedSurfaceContentHost`;
- `ConnectedSurfaceMask`.

Therefore a final production migration can use one shared renderer for ii and
Waffle rather than maintaining separate corner systems.

### 28.4 Where the production field belongs

Do **not** put the SDF material inside `ConnectedSurfaceFrame` or inside
`ConnectedSurfaceRevealClip`.

`ConnectedSurfaceFrame` currently lacks the clean full-output/frame-domain
contract and still owns legacy `joinTop/joinBottom/joinLeft/joinRight`,
Canvas flares and body-only shadow. Forcing SDF into that component would
encourage the rejected offset/join metadata to leak into the renderer.

Instead, the final material item should live directly under the full-output
popup `PanelWindow`, outside the reveal clip:

```text
Overlay popup PanelWindow
├── ConnectedSurfaceField           # full-output coordinates, workspace projection
├── ConnectedSurfaceRevealClip
│   ├── geometry/input proxy         # no painted legacy body/flare
│   └── ConnectedSurfaceContentHost  # existing content motion/clip
└── ConnectedSurfaceMask             # existing input ownership
```

The field consumes only generic geometry:

- output dimensions;
- padded frame outer rect;
- base frame inner rect derived from Screen Edge + owning Bar thickness;
- frame radius;
- `geometry.animatedBodyRect`;
- popup radius;
- smoothing/material parameters;
- renderer-domain projection mode.

It must not consume direct-edge booleans or source module identity.

### 28.5 Input migration is separable from material migration

`ConnectedSurfaceMask` fundamentally needs geometry Items/Regions, not painted
pixels. Therefore the current body rectangle can be replaced by a transparent
geometry/input proxy without retaining the legacy painted body.

Hover ownership can likewise remain on that proxy and on
`ConnectedSurfaceContentHost`.

This means the final migration does not need Canvas alpha to drive input.

### 28.6 Shadow migration cannot remain body-only

Current `ConnectedSurfaceFrame` uses `RectangularShadow` around only the
rounded body. Keeping that as the final shadow would visually disagree with the
new SDF shoulder.

Also, applying a shadow to the **workspace-projected alpha** directly would
invent a false shadow boundary at the owner seam.

Correct future ownership is:

1. derive fill and shadow from the **complete merged signed-distance field**;
2. only after that, apply workspace-domain output projection;
3. let the persistent Top Screen Edge/Bar own its existing physical shadow.

This avoids both a body-only shoulder mismatch and a seam shadow.

A production cutover may temporarily keep shadow disabled for the new field
while its field-derived shadow is validated; it must not claim final parity while
using the legacy rectangular shadow as if it represented the unified silhouette.

### 28.7 Remaining blocker before production write

No production cutover is approved from CI alone.

The exact current live acceptance command remains:

```sh
python3 scripts/unified-surface/validate-live-niri.py \
  --scales 1 1.25 1.5 1.75 2 \
  --benchmark
```

That run now includes:

- bounded/full topology;
- frameInner clamp;
- enlarged junction morphology;
- shoulder position/taper;
- motion/reveal no-remap;
- fullscreen Top/Overlay lifecycle;
- owner foreground/workspace projection;
- performance.

If this live run fails, change only the isolated U1 field/projection model and
re-run. Do not start a production migration and do not compensate with contact
geometry.

If it passes, the final production commit can be prepared as one atomic renderer
replacement for ii + Waffle Bar popup material, with a clean rollback to the
current legacy `ConnectedSurfaceFrame` path.


### 28.8 First production cutover must be ii-only

A palette audit invalidated the earlier assumption that ii and Waffle should be
migrated in the same first production commit.

Current material ownership is intentionally different:

```text
ii Screen Edge / Bar owner:
  Appearance.colors.colLayer0

ii StyledPopup:
  Appearance.colors.colLayer0

Waffle Screen Edge / Bar owner:
  Looks.colors.bg0

Waffle BarPopup:
  Looks.colors.bg1Base
```

Current Caelestia `BlobGroup` has one `color` property and each BlobShape
material uses `m_group->color()`. In other words, its one-silhouette group is
also one material colour.

Therefore:

- ii has the correct material contract for the first unified-field cutover;
- Waffle has a deliberate elevated popup palette and must not be silently
  recolored merely to share the first renderer migration;
- Waffle remains a supported family on the existing connected-surface renderer
  until its material policy is explicitly designed/tested;
- do not classify the Waffle path as legacy/retired merely because ii advances
  first.

The eventual geometry/SDF implementation may still be reusable by Waffle, but a
future Waffle migration must choose one of these deliberately:

1. retain two visual material roles while sharing only topology math;
2. redefine Waffle owner/popup palette to one material as an explicit product
   change;
3. use separate composition groups where the visual design calls for elevation.

None of those choices belong in the ii corner-fix commit.

### 28.9 Exact first production cutover scope

If and only if the live nested-Niri U1 matrix passes, prepare one atomic ii
migration with this scope:

```text
ADD:
  modules/common/perimeter/ConnectedSurfaceField.qml
  modules/common/perimeter/ConnectedSurfaceField.frag
  modules/common/perimeter/ConnectedSurfaceField.qsb

MODIFY:
  modules/common/perimeter/qmldir
  modules/bar/StyledPopup.qml
  relevant ii connected-popup behavior/contract tests
  packaging/runtime shader-source contracts as required

DO NOT MODIFY:
  modules/screenCorners/ScreenEdges.qml
  modules/bar/Bar.qml
  modules/waffle/bar/BarPopup.qml
  Waffle palette/tokens
  Sidebar/Dashboard/Settings
```

The ii `StyledPopup` structure should become:

```text
full-output Overlay PanelWindow
├── ConnectedSurfaceField
│   ├── full virtual inverted frame evaluation
│   ├── animatedBodyRect
│   └── workspace projection
├── ConnectedSurfaceRevealClip
│   └── popup content / transparent geometry proxy
└── ConnectedSurfaceMask
```

For ii only, the material color should remain
`Appearance.colors.colLayer0`; this is already the popup and physical
perimeter contract.

The current `ConnectedSurfaceFrame` must stay available for Waffle during this
first migration. Do not delete `ConnectedSurfaceJoinFlares.qml` globally in
the same commit merely because ii no longer consumes it.

This is a deliberate staged replacement, not patch stacking: ii switches from
the old renderer to the new field renderer atomically, while the separate Waffle
family remains unchanged.
