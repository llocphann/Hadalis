# Hadalis Connected Surfaces — Research Handoff

> **Status:** research / architecture handoff only  
> **Branch:** `dev`  
> **Research baseline:** `f8e254a7542eb22dd39c0dd3c3aba66692fc3451`  
> **Date:** 2026-09-15  
> **Functional implementation:** **not started**

This README intentionally replaces the previous project README for the current development handoff. The goal of this pass was to study Hadalis and Caelestia deeply enough to define a low-regression path toward connected Quickshell surfaces before changing functional QML.

The requested target is:

- Material ii **Classic Bar**.
- Bar at the **top**.
- Existing **hug-corner** language retained and extended.
- Bar popups should look physically attached to the bar rather than like independent floating cards.
- Sidebar should use the same connected geometry language.
- Clipboard should be **merged into the sidebar**, not remain a standalone full-screen overlay.
- Overview should become a **bottom-attached** surface.
- Dashboard should become a **bottom-attached** surface.
- These surfaces should share state, geometry rules, animation language, focus policy, and per-output routing.
- The Waffle family is outside this migration unless explicitly brought into scope later.

No functional Connected Surface code was changed during this research pass. The only intended repository modification in this pass is this handoff document.

---

## Executive decision

**Yes, Hadalis can reproduce the connected / seamless feel associated with Caelestia.** The correct adaptation is architectural, not a direct copy of Caelestia's popup QML.

Caelestia's result comes from several layers working together:

1. a per-screen composition window / coordinate space,
2. centralized surface and interaction state,
3. geometry-aware input regions,
4. coordinated panel deformation / clipping,
5. and, for the organic merged background, a native `Caelestia.Blobs` scene-graph implementation.

Hadalis already owns most of the difficult compositor-facing infrastructure that should **not** be discarded: per-output `PanelWindow`s, precise `Region` masks, target-output resolution, sidebar lifecycle management, focus handling, fullscreen/direct-scanout protection, blur regions, and Classic Bar hug corners.

Therefore the recommended migration is:

> **Keep Hadalis' window/lifecycle strengths, add a shared Connected Surface state + geometry layer, migrate surfaces incrementally, and only introduce a native blob renderer if QML-native geometry cannot meet the final visual fidelity target.**

This avoids turning a visual redesign into a high-risk rewrite of focus, input, monitor routing, and fullscreen behavior.

---

## What was studied

### Hadalis (`dev`)

Primary files and boundaries reviewed:

- `modules/bar/Bar.qml`
- `GlobalStates.qml`
- `modules/sidebar/SidebarHost.qml`
- `modules/sidebarRight/SidebarRight.qml`
- `modules/clipboard/ClipboardPanel.qml`
- `modules/overview/Overview.qml`
- `modules/overview/OverviewWindow.qml`
- `modules/dashboard/Dashboard.qml`
- `modules/ii/ShellIiPanelsImpl.qml`
- `ARCHITECTURE.md`
- `STRUCTURE.md`

### Caelestia Shell (`main`)

Primary reference files reviewed:

- `modules/drawers/ContentWindow.qml`
- `modules/drawers/Panels.qml`
- `modules/drawers/Interactions.qml`
- `modules/bar/BarWrapper.qml`
- `modules/bar/popouts/Wrapper.qml`
- `modules/bar/popouts/ClipWrapper.qml`
- `modules/nexus/common/BlobPopup.qml`
- `modules/nexus/common/ConnectedRect.qml`
- `plugin/src/Caelestia/Blobs/*`
- `plugin/src/Caelestia/Blobs/blobgroup.cpp`

The current Caelestia implementation studied is built around a side-oriented bar and therefore cannot be transplanted geometrically into Hadalis' top Classic Bar. Its **composition model** is the useful reference.

---

## Why Caelestia feels seamless

Caelestia does not achieve the effect by opening a normal rounded `PopupWindow` and placing it near the bar.

`modules/drawers/ContentWindow.qml` is effectively a full-screen per-output composition surface. Bar and drawers share the same coordinate system. The window uses a precise region mask instead of treating the transparent full-screen area as interactive. Surface state is shared, focus is coordinated, and drawer/popup geometry is known by one parent.

The connected background is then rendered through `Caelestia.Blobs`. A `BlobGroup` owns multiple shapes and coordinates smoothing / deformation between spatial neighbours. `PanelBg` instances for dashboard, launcher, session, sidebar, utilities and bar popouts participate in one visual system. Caelestia deliberately adds overlap in places where SDF joins could otherwise reveal seams.

The transferable lessons are therefore:

- **One geometry authority per output.**
- **One active-route/state authority per surface family.**
- **Render visible geometry and input geometry from the same source.**
- **Animate geometry, not just opacity.**
- **Treat the connector/neck as part of the surface, not decoration drawn afterward.**
- **Keep source-anchor knowledge when moving between bar items and popouts.**
- **Centralize conflict rules between sidebar, dashboard, launcher, popouts, etc.**

The native blob plugin is an implementation detail of Caelestia's highest-fidelity organic deformation. Hadalis does not need to begin there.

---

## Hadalis baseline: what should be preserved

### 1. Classic Bar is already a strong host

`modules/bar/Bar.qml` already provides the critical primitives needed for a connected top bar:

- a `PanelWindow` per selected screen,
- top/bottom placement,
- exact input masking,
- blur regions tied to visible bar geometry,
- autohide / exclusive-zone behavior,
- and existing Classic Bar **hug-corner** decorators.

The present `hugCorners` path is especially important. It already disables incompatible native-blur behavior and renders concave corner decoration around the Classic background. The new popup system should extend this language rather than replace it.

**Decision:** do not rewrite `Bar.qml` first. Add anchor publication and a connected popup presentation layer around it.

### 2. SidebarHost contains valuable lifecycle engineering

`modules/sidebar/SidebarHost.qml` already solves problems that a visual rewrite could easily reintroduce:

- semantic left/right roles,
- output targeting,
- fullscreen awareness,
- edge-open regions,
- size modes and min/max sizing,
- resident-vs-unloaded content lifecycle,
- render suspension,
- resume/remap handling,
- direct-scanout-conscious mapping,
- exact click-through masks,
- focus-grab behavior,
- backdrop closing,
- and multiple animation modes.

**Decision:** keep `SidebarHost` as the compositor/window boundary. Connected geometry should become a presentation layer inside/around this host, not a replacement for the host.

### 3. GlobalStates already has the output resolver

`GlobalStates.qml` already contains focused-screen / primary-screen fallback logic and resolves presentation outputs for overview and both sidebar roles.

The current state model is boolean-heavy (`overviewOpen`, `dashboardOpen`, `clipboardOpen`, sidebar flags, etc.), but those booleans are also compatibility contracts for keybinds and IPC.

**Decision:** introduce a coordinating Connected Surface route while retaining legacy booleans during migration. Do not perform a big-bang state rewrite.

### 4. Overview and Dashboard currently own independent windows

`modules/overview/Overview.qml` creates a `PanelWindow` variant per screen and contains substantial Niri/Orbit state, search, screencopy and presentation logic.

`modules/dashboard/Dashboard.qml` currently uses a full-screen overlay `PanelWindow`, with the actual dashboard content centered inside it.

`modules/ii/ShellIiPanelsImpl.qml` loads Overview, Dashboard and Clipboard as independent on-demand panels.

**Decision:** keep their complex content implementations, but move outer presentation responsibility toward a shared bottom-surface topology. The owning windows — not individual overview preview delegates/cards — are the refactor boundary.

### 5. Clipboard is currently both view and window

`modules/clipboard/ClipboardPanel.qml` mixes two responsibilities:

- clipboard model/search/pin/copy/delete behavior,
- and a standalone full-screen overlay `PanelWindow` with its own exclusive keyboard focus.

**Decision:** do not embed `ClipboardPanel.qml` directly in a sidebar. First split reusable clipboard content/model behavior from window-host behavior. Clipboard then becomes a sidebar page/mode while `Cliphist` remains the underlying service.

---

## Target surface topology

The target is a **surface family**, not a collection of unrelated windows.

```text
TOP EDGE
┌──────────────────────────────────────────────────────────────┐
│            Classic Bar · top · existing hug corners          │
└───╮───────────────╭──────────────────────╮────────────────╭──┘
    │               │ connector / neck     │                │
    │               ╰───────╮      ╭───────╯                │
    │                       │ POPUP│                        │
    │                       ╰──────╯                        │
    │                                                       │
    │ ╭──────────────╮                     ╭──────────────╮ │
    │ │   SIDEBAR    │                     │   SIDEBAR    │ │
    │ │ normal page  │                     │ normal page  │ │
    │ │              │                     │ clipboard    │ │
    │ ╰──────────────╯                     ╰──────────────╯ │
    │                                                       │
    │        ╭────────────────────────────────────╮         │
    │        │ OVERVIEW or DASHBOARD (one route)  │         │
    └────────╯   bottom-attached + bottom hug     ╰─────────┘
BOTTOM EDGE
```

Important interpretation: Overview and Dashboard cannot literally remain attached to a top bar across the whole screen without creating a giant visual bridge. Their "connected" requirement should mean **shared geometry language, routing, motion, color/blur tokens and edge-hug behavior**, while their physical attachment is to the **bottom edge**.

---

## Proposed architecture

### A. Connected Surface controller

Add one coordinating state owner for Material ii, preferably as a small singleton/service rather than expanding ad-hoc boolean coupling.

Conceptual state:

```qml
surfaceRoute: ({
    output: "",
    family: "none",      // none | barPopup | sidebar | bottom
    surface: "",         // volume | network | clipboard | overview | dashboard | ...
    page: "",
    source: "",
    anchorRect: Qt.rect(0, 0, 0, 0)
})
```

This route does **not** need to replace existing `GlobalStates` flags immediately. During migration it should synchronize with them and become the authority for conflict/transition rules.

Required policies:

- only one anchored bar popup per output,
- one bottom surface per output (`overview` **or** `dashboard`),
- clipboard routes to the system sidebar page rather than its own window,
- opening a bottom surface closes transient bar popouts,
- sidebar/bar-popup transitions on the same output should be deliberate rather than accidental overlap,
- Escape/backdrop/focus-loss should close the current route through one policy path,
- output targeting must use the existing `GlobalStates.resolveOutputName()` family of helpers.

Suggested future name: `ConnectedSurfaces.qml` or `SurfaceFamilyController.qml`.

### B. Anchor registry

Bar modules that can open a connected popup must publish their visual source rectangle in screen-local coordinates.

Suggested fields:

```text
outputName
anchorId
sourceItem
screenRect
preferredAlignment
preferredWidth
surfaceName
```

The popup should animate from the source location and keep the connector centered/clamped around that source. This is the equivalent of Caelestia retaining `currentCenter`/active popout geometry.

Do not derive popup position from hard-coded module ordering. The Classic Bar is configurable; the anchor must come from the actual rendered item.

### C. Connected Surface tokens

Create one token source derived from `Appearance` so every connected surface uses the same geometry vocabulary:

- outer radius,
- concave connector radius,
- neck width,
- neck minimum/maximum clamp,
- edge inset,
- overlap/seam guard,
- elevation/shadow margin,
- border width,
- blur expansion,
- enter/exit duration and curves.

Suggested path: `modules/common/surfaces/ConnectedSurfaceTokens.qml`.

### D. Connected Surface frame / renderer

Phase 1 should be QML-native and deliberately conservative.

Suggested primitives:

- `ConnectedSurfaceFrame.qml`
- `ConnectedSurfaceConnector.qml`
- `ConnectedSurfaceMask.qml`
- `BottomConnectedFrame.qml`

The renderer should own **both visible shape and hit shape**. Avoid a beautiful visual shape with a larger rectangular input surface behind it.

For the top bar, render a popup body plus a short neck/bridge that overlaps the bottom edge of the Classic Bar enough to avoid fractional-scale hairlines. Concave corners around the neck should match the existing hug-corner vocabulary.

If QML-native geometry cannot eliminate seams at fractional scaling or cannot reproduce the desired organic morphing, escalate after the prototype to either:

1. a single per-output visual canvas, or
2. a Hadalis-native scene-graph / SDF blob renderer inspired by the architecture of Caelestia's `Blobs` plugin.

Do **not** start by importing the C++ plugin. That would add CMake/plugin packaging, ABI, shader and deployment work before validating that Hadalis actually needs it.

### E. Optional single visual canvas — Phase 2 escalation

Caelestia's strongest continuity comes from drawing connected backgrounds inside one full-screen window. Hadalis can adopt this concept later without immediately surrendering the existing window hosts.

A low-regression variant would split responsibility:

- existing Bar/Sidebar/Overview/Dashboard hosts retain interaction, focus, exclusive-zone and lifecycle responsibilities,
- a per-output `ConnectedSurfaceCanvas` renders the shared backgrounds/bridges in one coordinate space,
- host backgrounds become transparent while their content stays in place,
- the canvas mask remains empty/click-through because interaction still belongs to the existing hosts.

This path must be tested carefully against direct scanout/fullscreen mapping. It is an escalation, not Phase 1.

---

## Surface-specific adaptation

### Classic Bar — top + hug corner

Keep the existing Classic Bar host and its top position. When a popup opens:

1. the source bar module publishes its actual screen rectangle,
2. the controller selects one active popup for that output,
3. popup geometry is clamped to the screen while preserving the source connector where possible,
4. the connector grows downward from the bar,
5. the body expands from the connector rather than fading in as an unrelated card,
6. the input/blur region follows the connected geometry,
7. closing reverses the geometry path back toward the source.

The first migration should target a small, self-contained bar popup. Do not migrate every popup simultaneously.

### Sidebar

Preserve `SidebarHost.qml` and its current per-output/window lifecycle.

The connected redesign should primarily change:

- internal frame/background geometry,
- top/bottom edge relationship,
- routing/page state,
- optional connector to the relevant bar/system anchor,
- and motion between sidebar pages.

The sidebar should not lose edge-open behavior, resume remapping, full-screen protection or exact masks.

### Clipboard → Sidebar

Recommended sequence:

1. extract clipboard model/view logic from `ClipboardPanel.qml` into reusable content (`ClipboardView.qml` / `ClipboardPage.qml`),
2. preserve `Cliphist` refresh/search/pin/copy/delete semantics,
3. add a `clipboard` page to the system sidebar,
4. change clipboard keybind/IPC route to open the correct sidebar on the target output and select that page,
5. keep the legacy `clipboardOpen` property temporarily as a compatibility trigger that redirects to the sidebar,
6. once callers are migrated, stop loading the Material ii standalone `ClipboardPanel` from `ShellIiPanelsImpl.qml`.

The Waffle clipboard state is a separate family and should not be changed by this work unless explicitly requested.

### Overview — bottom

`Overview.qml` is complex and should not be gutted. Preserve search, screencopy, workspace/window models and Orbit-specific logic.

Refactor its outer presentation so the active output presents Overview through a bottom-attached body with bottom hug corners. The connected frame should be independent of individual `OverviewWindow.qml` preview cards.

The initial bottom version should prioritize correctness over blob deformation. Once the host topology is stable, add shared motion/geometry tokens.

### Dashboard — bottom

`DashboardContent` and card internals should remain reusable. Replace the current centered full-screen-card presentation with the same bottom-surface host family used by Overview.

Overview and Dashboard should be mutually exclusive routes of the same bottom host. This prevents two independent overlays from fighting for focus, backdrop, animation and edge geometry.

---

## Window, mask, focus and blur rules

These are non-negotiable constraints for implementation:

### Input

- Transparent areas must remain click-through.
- `Region`/mask geometry must track the rendered connected shape.
- Do not use a full-screen interactive mask merely because the host window is full-screen.
- Backdrop close behavior must not steal clicks from unrelated surfaces when another sidebar role is intentionally open.

### Focus

- Bar popouts should avoid exclusive keyboard focus unless content actually requires text input/navigation.
- Sidebar keeps its existing focus policy and hold-open behavior.
- Bottom interactive surfaces can own focus while active, but they must release it deterministically on close.
- Avoid `OnDemand` as a catch-all solution; focus ownership should be explicit per route.

### Blur and borders

- Blur region must follow the visible connected geometry.
- Test Classic hug corners with native blur enabled/disabled paths.
- A connector spanning two separately composited windows needs a seam guard/overlap; do not assume identical rounded colors eliminate a 1 px fractional-scale line.
- Borders should be rendered from the same geometry source as the fill whenever possible.

### Fullscreen / direct scanout

- Preserve the existing sidebar behavior that can unmap/suspend transparent overlay hosts when fullscreen owns an output.
- Connected visual hosts must also disappear/unmap when the bar/surfaces are not supposed to render over fullscreen.
- Do not introduce a permanently mapped transparent full-screen window without measuring the direct-scanout consequence.

---

## Proposed file-level touch plan

This is a **future plan**, not a list of changes already made.

| Area | Likely action |
|---|---|
| `GlobalStates.qml` | compatibility bridge + target-output helpers for connected route |
| `modules/common/surfaces/` | new tokens, controller-facing geometry primitives, masks/connectors |
| `modules/bar/Bar.qml` | publish bar geometry / connected state; preserve Classic host and hug corners |
| bar module popup callers | route through common popup host instead of independent presentation |
| `modules/sidebar/SidebarHost.qml` | connected frame integration, page routing hook; preserve lifecycle |
| `modules/sidebarRight/*` | add system-sidebar page selection / clipboard page |
| `modules/clipboard/ClipboardPanel.qml` | split content from standalone window; later retire Material ii host |
| `modules/overview/Overview.qml` | move outer presentation to bottom host while preserving internals |
| `modules/dashboard/Dashboard.qml` | move presentation to shared bottom host; preserve `DashboardContent` |
| `modules/ii/ShellIiPanelsImpl.qml` | load shared connected hosts/routes instead of duplicate standalone hosts after migration |

Do not begin by changing every caller. Build the primitives and migrate one surface at a time.

---

## Implementation phases

### Phase 0 — completed by this handoff

- Research Hadalis and Caelestia architecture.
- Identify preservation boundaries.
- Replace the old README with this handoff.
- No functional QML migration.

### Phase 1 — foundation

- Add Connected Surface tokens.
- Add route/controller compatibility layer.
- Add source-anchor registry.
- Add QML-native connector/frame/mask primitives.
- Add geometry diagnostics under a debug flag.

Exit criterion: a static/prototype connected surface can be placed correctly on every output without breaking input masks.

### Phase 2 — first Classic Bar popup

- Choose one small popup.
- Register source anchor.
- Open through common popup state.
- Animate connector + body.
- Validate blur/mask/focus.
- Test fractional scale.

Exit criterion: the popup visually reads as one surface with the top Classic Bar and has no visible seam under the target scale matrix.

### Phase 3 — migrate remaining bar popups

- Move compatible popups incrementally.
- Keep one active popup per output.
- Add transitions between adjacent popup sources without close/reopen flicker.

### Phase 4 — Sidebar + Clipboard

- Add connected frame to current SidebarHost.
- Add sidebar page routing.
- Extract Clipboard view/content.
- Route clipboard trigger into system sidebar.
- Remove Material ii standalone clipboard window only after feature parity is verified.

### Phase 5 — Overview bottom host

- Refactor outer Overview presentation only.
- Preserve screencopy/search/Orbit state.
- Add bottom edge hug geometry and shared route.

### Phase 6 — Dashboard bottom host

- Reuse the same bottom host family.
- Preserve `DashboardContent`.
- Make Overview/Dashboard mutually exclusive with coherent transitions.

### Phase 7 — hardening

- multi-monitor,
- Niri and Hyprland,
- fractional scaling,
- fullscreen/GameMode,
- shell edit mode,
- animations disabled,
- screen lock/resume,
- bar autohide/exclusive zone,
- right + left sidebar coexistence,
- native blur on/off,
- panel keep-loaded/on-demand lifecycle.

### Phase 8 — optional native renderer

Only if QML-native connected geometry is visibly insufficient:

- prototype a Hadalis-native SDF/blob renderer,
- or adapt the conceptual `BlobGroup` model,
- measure GPU/CPU and packaging impact,
- retain a non-native fallback.

---

## Acceptance criteria

The migration is not complete because the corners look similar. It is complete when all of the following are true:

- Classic Bar stays at the top and retains correct hug-corner behavior.
- A bar popup opens from its real source item and visually attaches to the bar.
- No hairline seam at common fractional scales (at minimum 1.0, 1.25, 1.5 and 2.0 where the compositor/output setup supports them).
- Popup movement between source modules does not flash a detached rectangle.
- Transparent host regions are click-through.
- Blur/border/mask agree with visible geometry.
- Per-output targeting follows the output that initiated the action.
- Sidebar preserves current edge-open, resize, focus, fullscreen and resume behavior.
- Clipboard opens as a sidebar page and retains search, pin, copy, delete, image/rich-content behavior expected from the current implementation.
- Material ii no longer needs a second standalone Clipboard window after migration.
- Overview is bottom-attached without breaking screencopy, search or Orbit flows.
- Dashboard is bottom-attached while reusing existing content.
- Overview and Dashboard do not overlap as independent full-screen overlays.
- Escape, backdrop click and focus loss have deterministic route-specific behavior.
- Lock/resume and fullscreen transitions do not leave invisible mapped surfaces behind.
- Waffle remains functionally unchanged unless separately scoped.

---

## Risks and open decisions

### Separate-window seam vs one visual canvas

Hadalis currently has robust independent hosts. The first prototype should preserve them. If identical geometry + overlap still produces visible seams with blur/fractional scale, the next escalation is a single visual canvas per output while retaining existing interaction windows.

Do not decide this from screenshots alone; test on the compositor at multiple scales.

### Native blob plugin

Caelestia's organic merging is powered by native code and shaders. Copying the idea at QML level is straightforward; matching every deformation characteristic is not.

A native plugin is justified only if the desired result explicitly requires metaball/SDF deformation rather than a precise connected neck + concave-corner shape.

### Overview complexity

Overview is far more than a card. Its Niri/Orbit state and screencopy pipeline make it a high-risk early migration target. Do it after the top popup and sidebar primitives are stable.

### Focus differences between compositors

Niri and Hyprland do not behave identically around layer-shell focus/focus grabs. Preserve current working host policies and introduce the new controller around them rather than normalizing everything prematurely.

---

## License / attribution boundary

Both repositories currently carry **GNU GPL v3** license files.

This research pass imported **no Caelestia source code** into Hadalis. Caelestia is being used as an architectural/reference source.

If a future implementation copies or closely adapts source-level code — especially the `Caelestia.Blobs` plugin/shaders — preserve the applicable GPL obligations, copyright notices and attribution, and document which files were adapted. Prefer a clean Hadalis-specific implementation when the requirement is only the architectural idea.

---

## Reference links

### Hadalis

- https://github.com/llocphann/Hadalis/blob/dev/modules/bar/Bar.qml
- https://github.com/llocphann/Hadalis/blob/dev/GlobalStates.qml
- https://github.com/llocphann/Hadalis/blob/dev/modules/sidebar/SidebarHost.qml
- https://github.com/llocphann/Hadalis/blob/dev/modules/clipboard/ClipboardPanel.qml
- https://github.com/llocphann/Hadalis/blob/dev/modules/overview/Overview.qml
- https://github.com/llocphann/Hadalis/blob/dev/modules/dashboard/Dashboard.qml
- https://github.com/llocphann/Hadalis/blob/dev/modules/ii/ShellIiPanelsImpl.qml
- https://github.com/llocphann/Hadalis/blob/dev/ARCHITECTURE.md

### Caelestia

- https://github.com/caelestia-dots/shell/blob/main/modules/drawers/ContentWindow.qml
- https://github.com/caelestia-dots/shell/blob/main/modules/drawers/Panels.qml
- https://github.com/caelestia-dots/shell/blob/main/modules/drawers/Interactions.qml
- https://github.com/caelestia-dots/shell/blob/main/modules/bar/popouts/Wrapper.qml
- https://github.com/caelestia-dots/shell/blob/main/modules/bar/popouts/ClipWrapper.qml
- https://github.com/caelestia-dots/shell/blob/main/modules/nexus/common/BlobPopup.qml
- https://github.com/caelestia-dots/shell/tree/main/plugin/src/Caelestia/Blobs

### Quickshell concepts to keep aligned with

- Panel/window edge attachment and exclusive zones
- Window `mask` / input `Region`
- Layer-shell namespace/layer/keyboard focus
- Popup anchoring where a real popup window is still appropriate

Documentation root: https://quickshell.outfoxxed.me/docs/

---

## Handoff checklist for the next implementation session

Before writing production code:

- confirm Material ii + Classic + top + hug-corner is the implementation scope,
- create the common surface primitives/controller first,
- select one small bar popup as the prototype,
- keep a debug overlay for anchor/body/connector/mask rectangles,
- validate at least one Niri multi-monitor setup before broad migration,
- record before/after focus and mask behavior,
- do not remove legacy state or ClipboardPanel until compatibility routing works,
- do not refactor Overview internals while changing its host,
- do not introduce the native blob plugin until the QML prototype has been evaluated visually and technically.

### Recommended first production change

The first implementation commit after this handoff should contain **only the Connected Surface foundation plus one prototype popup**. It should not include Sidebar, Clipboard, Overview and Dashboard in the same commit.

That sequencing gives a clean rollback point and answers the most important unresolved question early: whether Hadalis can reach the required seamless visual quality with its existing QML/window architecture, or whether a single visual canvas/native geometry renderer is actually necessary.
