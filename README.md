# Hadalis Connected Perimeter — Architecture Handoff

> **Status:** architecture/source-of-truth handoff  
> **Branch:** `dev`  
> **Date:** 2026-09-15  
> **Functional Connected Perimeter implementation:** not started  
> **Baseline policy:** implementation must be built on the cleaned **Material ii / Classic-only** baseline and must not reintroduce retired appearance/features removed by the concurrent cleanup work.

This document supersedes the previous single-top-bar / single-bottom-host interpretation of the Connected Surfaces research.

The target is now a **configurable per-output perimeter system** inspired by Caelestia's connected-composition model while preserving Hadalis/iNiR's services, compositor integration, routing, lifecycle and Niri engineering.

Hadalis is **not** a source merge of Caelestia and iNiR. The intended combination is:

- iNiR/Hadalis supplies runtime/services/configuration/Niri integration/window lifecycle/output routing.
- Caelestia supplies architectural lessons for connected geometry, anchor-aware popouts, state coordination and seamless surface composition.
- Hadalis owns the final visual language, topology and implementation.

---

## 1. Non-negotiable target topology

Each output owns eight perimeter slots:

```text
┌─────────────────────────────────────────────────────────────────┐
│ TOP-LEFT              TOP-CENTER                    TOP-RIGHT    │
│                                                                 │
│                                                                 │
│ LEFT-EDGE                                         RIGHT-EDGE     │
│                                                                 │
│                                                                 │
│ BOTTOM-LEFT          BOTTOM-CENTER                BOTTOM-RIGHT   │
└─────────────────────────────────────────────────────────────────┘
```

Canonical logical form:

```text
Perimeter(output)
├── top
│   ├── start
│   ├── center
│   └── end
├── left
│   └── center
├── right
│   └── center
└── bottom
    ├── start
    ├── center
    └── end
```

The low-level renderer/layout engine should prefer **edge + alignment** over eight unrelated hard-coded implementations:

```text
edge: top | bottom | left | right
alignment: start | center | end
```

For left/right edges only `center` is part of the initial topology.

### Inward directions

```text
top    -> inward = down
bottom -> inward = up
left   -> inward = right
right  -> inward = left
```

Connected popups/drawers expand inward from their real module anchor.

---

## 2. Default Hadalis preset

The following is the **initial/default configuration only**:

```text
TOP-LEFT
- ThinkFan
- System Monitor

TOP-CENTER
- Workspaces
- Media
- Weather
- additional user-selected modules

TOP-RIGHT
- empty

LEFT-EDGE
- Left Sidebar
- vertically centered
- no max-size presentation mode

RIGHT-EDGE
- Right Sidebar
- vertically centered
- no max-size presentation mode

BOTTOM-LEFT
- empty

BOTTOM-CENTER
- Dock

BOTTOM-RIGHT
- empty
```

This preset must never become module ownership.

### Critical rule

> **No module is locked to any perimeter slot.**

Every perimeter slot must support:

- zero modules,
- one module,
- multiple ordered modules,
- add,
- remove from layout,
- reorder within the slot,
- move to another slot,
- being completely empty.

The system must not contain special rules such as:

```text
ThinkFan => top-left only
Dock => bottom-center only
Sidebar => side edge only
Weather => top-center only
```

Those are forbidden architectural assumptions.

A module may expose presentation capabilities or preferences, but placement remains configuration-driven.

---

## 3. Module instances, not hard-coded children

The perimeter should be populated from configuration through a module registry/factory.

Conceptual model:

```text
config
  -> slot definition
     -> ordered module instance IDs
        -> module registry
           -> instantiate module with perimeter context
```

Prefer instance-aware configuration so the architecture does not unnecessarily forbid multiple instances of the same module:

```yaml
perimeter:
  top:
    start:
      - instance: thinkfan-main
        module: thinkfan
      - instance: monitor-main
        module: systemMonitor
    center:
      - instance: workspaces-main
        module: workspaces
      - instance: media-main
        module: media
      - instance: weather-main
        module: weather
    end: []

  left:
    center:
      - instance: sidebar-left
        module: leftSidebar

  right:
    center:
      - instance: sidebar-right
        module: rightSidebar

  bottom:
    start: []
    center:
      - instance: dock-main
        module: dock
    end: []
```

Exact schema may differ after auditing the existing Hadalis config system. Do not invent an incompatible parallel configuration stack if the current config can be extended cleanly.

### Module context

A module should receive presentation context rather than infer its location from global state:

```text
outputName
instanceId
moduleId
edge
alignment
orientation
inwardDirection
slotRect
```

Useful derived orientation:

```text
top/bottom -> horizontal
left/right -> vertical
```

Modules should adapt to context where reasonable. A preferred orientation is advisory, not a placement lock.

---

## 4. Empty slots are first-class

An empty slot must not create useless compositor state.

If a slot contains no visible modules, it should have, wherever architecture permits:

- no background,
- no blur region,
- no hit region,
- no fake transparent visual surface,
- no unnecessary reserved space.

Do not keep invisible full-size windows merely to preserve an empty slot abstraction.

---

## 5. Connected-composition rules inherited from Caelestia research

The useful Caelestia reference is its **composition model**, not a direct QML transplant.

Hadalis should preserve these principles:

1. one geometry authority per output,
2. centralized route/conflict policy for transient surfaces,
3. anchor-aware popouts,
4. visible geometry and input geometry derived from the same source,
5. geometry animation rather than opacity-only animation,
6. connector/neck treated as part of the surface,
7. overlap/seam guards where separately composited pieces meet,
8. deliberate conflict policy between adjacent surfaces.

Do not begin by copying the native `Caelestia.Blobs` plugin. Start with QML-native geometry. Escalate to a Hadalis-native scene-graph/SDF renderer only if measured visual results require it.

---

## 6. Module anchors and connected popups

Every module capable of opening a transient surface must publish its **actual rendered anchor rectangle** in output-local coordinates.

Suggested anchor record:

```text
outputName
slotId
instanceId
moduleId
sourceItem/screenRect
edge
alignment
preferredPopupExtent
surfaceName
```

Popup placement must never be derived from hard-coded module ordering.

The same module should naturally invert its connected expansion according to the slot:

```text
TOP:       module -> popup grows downward
BOTTOM:    module -> popup grows upward
LEFT:      module -> popup grows rightward
RIGHT:     module -> popup grows leftward
```

The popup body may clamp to screen bounds, but the connector should remain aligned to the real source module as far as geometry allows.

---

## 7. Connected geometry primitives

Create shared QML-native primitives rather than separate implementations per edge.

Suggested family:

```text
modules/common/perimeter/
  PerimeterTokens.qml
  PerimeterContext.qml
  ConnectedSurfaceFrame.qml
  ConnectedSurfaceConnector.qml
  ConnectedSurfaceMask.qml
  AnchorRegistry.qml
  SurfaceRouteController.qml
```

Names are suggestions, not requirements. Reuse existing project conventions if better names/locations already exist.

The geometry layer should understand:

- edge,
- alignment,
- anchor rect,
- body rect,
- connector center,
- connector/concave radius,
- outer radius,
- seam overlap,
- blur expansion,
- border geometry,
- animation progress,
- input region.

Avoid four copies of the same renderer for top/bottom/left/right.

---

## 8. Route/controller model

Existing `GlobalStates` booleans and IPC/keybind contracts may need to remain temporarily for compatibility.

Add a coordinating authority for connected transient surfaces rather than allowing every module/window to fight independently.

Conceptual route:

```qml
surfaceRoute: ({
    output: "",
    family: "none",       // popup | sidebar | large | ...
    surface: "",
    page: "",
    sourceInstance: "",
    slot: "",
    edge: "",
    anchorRect: Qt.rect(0, 0, 0, 0)
})
```

Required behavior:

- per-output routing,
- deterministic Escape/backdrop/focus-loss behavior,
- explicit transient-surface conflicts,
- adjacency-aware conflict policy where useful,
- no accidental overlap caused by independent booleans,
- compatibility with existing output resolution until migration is complete.

Do not perform a big-bang rewrite of every existing state flag.

---

## 9. Top perimeter

Top is not a monolithic full-width hard-coded bar anymore. It contains three independent configurable slots:

```text
top.start   = top-left
top.center  = top-center
top.end     = top-right
```

The default preset happens to populate left and center and leave right empty.

Modules inside a slot form an ordered strip/cluster. Each module can independently become the anchor of a connected popup.

Classic/Hadalis hug-corner language remains the visual basis. Existing Classic behavior that is still valid after cleanup should be reused rather than discarded.

---

## 10. Side edges / Sidebar requirements

Initial defaults:

```text
left.center  -> Left Sidebar
right.center -> Right Sidebar
```

Both are **vertically centered** on the output.

Do not top-align or bottom-align the default sidebar presentation.

### No max-size presentation

The Connected Perimeter version must not use the previous max-size/full-height style as its target presentation.

Desired sizing model:

```text
content/config desired extent
  -> clamp only to safe available output bounds
```

not:

```text
available output height
  -> expand sidebar toward maximum height
```

Preserve valuable existing `SidebarHost` lifecycle/compositor behavior where possible:

- target-output handling,
- focus policy,
- exact masks,
- fullscreen/direct-scanout protection,
- resume/remap handling,
- edge-open semantics if still desired,
- resident/on-demand lifecycle.

Change presentation and sizing without casually rewriting these proven boundaries.

Despite the default placement, Sidebar modules must not be permanently locked to left/right edge slots by the generic perimeter engine.

---

## 11. Bottom perimeter

Bottom mirrors top:

```text
bottom.start  = bottom-left
bottom.center = bottom-center
bottom.end    = bottom-right
```

Default preset:

```text
bottom.start  = empty
bottom.center = Dock
bottom.end    = empty
```

Dock is a normal configurable module instance from the perimeter engine's perspective, not a special hard-coded root surface.

Moving/removing Dock must be structurally possible through configuration.

Large transient surfaces such as Overview/Dashboard must not be modeled as permanent ownership of the whole bottom edge. If retained in the product, their launch/anchor/span policy must use the same route/geometry system and remain configurable rather than consuming `bottom.center` by architectural fiat.

---

## 12. ThinkFan default module

Reference upstream: `https://github.com/vmatare/thinkfan`.

Hadalis' default `top.start` cluster should include a ThinkFan integration intended to expose fan status/control, including the user's requested startup fan behavior/profile controls.

Implementation must audit the actual thinkfan configuration/service interfaces before choosing the write path. Do not assume a runtime API exists for every requested setting.

Required engineering constraints:

- separate read-only telemetry from privileged mutation,
- validate configuration before applying,
- surface service/config/fan availability states distinctly,
- do not claim a write succeeded until verified,
- preserve safe bounds and do not expose arbitrary unsafe raw values without validation,
- support graceful absence of thinkfan/hwmon/compatible hardware,
- avoid blocking the QML UI on privileged/system commands.

Upstream explicitly warns that unsafe fan/temperature configuration can damage hardware or shorten component lifetime. Treat this integration as hardware control, not a cosmetic slider.

ThinkFan remains movable like every other module; `top.start` is only its default placement.

---

## 13. System Monitor default module

System Monitor is the second default `top.start` module.

It should be implemented as a normal registry module and should be portable to any perimeter slot.

Telemetry sources and exact compact/expanded presentation should reuse existing Hadalis services where available instead of duplicating polling daemons.

---

## 14. Top-center defaults

Default `top.center` contains:

- Workspaces,
- Media,
- Weather,
- future/additional user-selected modules.

These are module instances in an ordered cluster, not mandatory fixed children of one special center component.

Each module that owns an expanded surface must publish its own actual anchor rect. The connector follows the clicked/active module, not the center of the overall slot.

---

## 15. Settings / configuration UX target

Do not add one independent `position` dropdown inside every module if the perimeter can be edited centrally.

Preferred model: a **Perimeter Layout editor** that exposes all eight slots and allows users to:

- add module instance,
- remove from layout,
- reorder,
- move between slots,
- leave slot empty,
- configure module-specific options.

Removing a module from a slot does not necessarily uninstall/disable the underlying feature/service.

The exact Settings UI should follow existing Hadalis Settings architecture and should not resurrect retired appearance selectors.

---

## 16. Window/input/blur requirements

These constraints remain non-negotiable:

### Input

- transparent areas stay click-through,
- hit region follows rendered geometry,
- no full-screen interactive mask solely because a visual host spans the screen.

### Blur/border

- blur follows visible connected geometry,
- border and fill derive from compatible geometry,
- connector/window joins use overlap/seam guards where necessary,
- validate fractional scales.

### Focus

- transient popups should not steal exclusive keyboard focus unless required,
- sidebars preserve intentional focus semantics,
- focused surfaces release focus deterministically on close.

### Fullscreen/direct scanout

- do not introduce permanently mapped transparent full-screen windows without measuring impact,
- preserve current fullscreen protection where still applicable,
- no invisible mapped leftovers after close, lock/resume or output changes.

---

## 17. Multi-output requirements

The perimeter is **per output**.

A module action on output B must resolve its connected surface on output B unless an explicit policy says otherwise.

Anchor records, routes, slot layouts and input regions must all carry output identity.

Do not regress the existing `GlobalStates` output resolver semantics while introducing the new system.

---

## 18. Cleanup boundary

Several agents are concurrently cleaning `dev` to produce a Classic-only baseline before Connected Perimeter implementation.

Connected Perimeter work must **not** reintroduce or depend on retired systems being removed by that cleanup, including obsolete bar appearance families and retired shell features.

In particular:

- do not restore removed appearance selectors/branches merely because old code references them,
- do not build the new architecture on Orbit/Mascot/Workspace Strip paths being removed,
- refetch `dev` before mutations,
- reconstruct changes on current HEAD if cleanup agents advanced the branch,
- prefer small atomic commits,
- never overwrite another agent's changes.

`README.md` is the architecture handoff; the live code on current `dev` is authoritative for exact surviving file paths and APIs.

---

## 19. Recommended implementation split

Two new implementation agents should work with explicit ownership.

### Agent A — Perimeter Core / Connected Geometry

Owns the shared substrate:

- eight-slot topology,
- slot configuration model,
- module instance registry/factory contract,
- perimeter context propagation,
- per-output geometry authority,
- anchor registry,
- connected frame/connector/mask primitives,
- route/controller infrastructure,
- core layout/settings schema hooks where unavoidable.

Agent A should not implement the full ThinkFan/System Monitor/Weather/Media/Dock/sidebar feature set.

### Agent B — Module & Surface Integration

Consumes Agent A's contract and integrates concrete modules/surfaces:

- default preset wiring,
- ThinkFan integration,
- System Monitor,
- Workspaces,
- Media,
- Weather,
- Dock,
- Left/Right Sidebar presentation migration,
- connected popup migrations for integrated modules,
- Settings presentation for module placement using the core contract.

Agent B should not fork or duplicate the perimeter engine, anchor registry, route controller or connected geometry primitives.

If Agent A's contract is not yet present on current `dev`, Agent B should perform research/preparation only or work on clearly independent adapters; it must not create a competing temporary architecture that will later need to be merged.

---

## 20. Implementation order

Recommended sequence:

1. finish/verify Classic-only cleanup baseline,
2. add perimeter slot/config/context substrate,
3. add anchor registry + route controller,
4. add orientation-agnostic connected geometry primitives,
5. render empty/default slots correctly per output,
6. wire the default preset,
7. migrate one small popup end-to-end as geometry proof,
8. integrate top-center/top-left modules incrementally,
9. migrate sidebars to centered/no-max-size presentation,
10. integrate Dock as normal bottom-center default module,
11. build/edit Perimeter Layout Settings,
12. harden multi-monitor/fractional-scale/fullscreen/resume behavior,
13. only then evaluate whether native SDF/blob rendering is necessary.

---

## 21. Acceptance criteria

The Connected Perimeter foundation is not complete until all of the following are true:

- eight logical slots exist per output,
- all eight slots can be empty,
- all eight slots can receive configured modules,
- modules are instantiated from configuration/registry rather than hard-coded into slot QML,
- module order is configurable,
- module movement between slots does not require source-code changes,
- top/bottom/left/right context produces correct inward direction,
- real module rects drive popup connectors,
- empty slots do not reserve bogus hit/blur/visual regions,
- default preset matches the documented mapping,
- Left/Right Sidebar defaults are vertically centered and do not use max-size presentation,
- Dock is the default bottom-center module but is movable/removable,
- ThinkFan is default top-left but is movable/removable,
- per-output routing remains correct,
- transparent areas stay click-through,
- connected geometry has no obvious seam at common fractional scales,
- cleanup-removed features/appearances are not reintroduced,
- no native Caelestia plugin dependency is introduced without an explicit later decision.

---

## 22. References

### Hadalis

- `modules/bar/Bar.qml`
- `GlobalStates.qml`
- `modules/sidebar/SidebarHost.qml`
- `modules/sidebarRight/`
- `modules/ii/ShellIiPanelsImpl.qml`
- `ARCHITECTURE.md`
- `STRUCTURE.md`

Exact paths may change during cleanup. Always inspect current `dev` before editing.

### Caelestia architectural references

- `modules/drawers/ContentWindow.qml`
- `modules/drawers/Panels.qml`
- `modules/drawers/Interactions.qml`
- `modules/bar/popouts/Wrapper.qml`
- `modules/bar/popouts/ClipWrapper.qml`
- `modules/nexus/common/BlobPopup.qml`
- `modules/nexus/common/ConnectedRect.qml`
- `plugin/src/Caelestia/Blobs/`

Reference repository: `https://github.com/caelestia-dots/shell`

### ThinkFan

- `https://github.com/vmatare/thinkfan`

---

## 23. Final architecture rule

> **Hadalis is a configurable connected perimeter, not a fixed top bar plus fixed sidebars plus a fixed dock.**
>
> The eight perimeter slots are layout locations. Modules are movable instances. Connected surfaces derive their direction and geometry from the slot context and their real rendered anchor. The documented placements are defaults only.
