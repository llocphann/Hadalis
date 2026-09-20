# Unified Surface Composition Research

Status: **research only — no production implementation is approved yet**

Last synchronized against `dev` at `c233d1c4aaac911d7fd2e8daac9fb3857f740860` on 2026-09-20.

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
