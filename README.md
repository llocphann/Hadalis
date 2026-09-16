# Hadalis Connected Perimeter

> **Status:** implemented on `dev`, active integration/stabilization  
> **Updated:** 2026-09-16  
> **Cutover:** opt-in; not yet the fresh-install default  
> **Release state:** not ready for `dev -> stable` until CI, documentation, packaging, and live acceptance gates are green

Hadalis is evolving from the older fixed panel composition into a **configurable per-output Connected Perimeter** while preserving the project’s existing services, compositor integration, routing, lifecycle, configuration, and Niri engineering.

Hadalis is **not** a source merge of Caelestia and iNiR.

- iNiR/Hadalis supplies the runtime, services, configuration, Niri integration, window lifecycle, and output routing foundations.
- Caelestia supplies architectural lessons around connected geometry, anchor-aware popouts, state coordination, and seamless surface composition.
- Hadalis owns the final visual language, topology, implementation, migration policy, and release contract.

The live code on `dev` is authoritative. Detailed Connected Perimeter behavior and contributor rules are documented in [`docs/PERIMETER.md`](docs/PERIMETER.md).

---

## Current implementation state

The Connected Perimeter foundation is implemented on `dev` and includes:

- eight configurable placement slots per output,
- module instances resolved through a registry rather than hard-coded slot children,
- shared/default placement plus per-output overrides,
- output-aware routing and anchor publication,
- reusable connected-surface geometry and masking primitives,
- edge reservation policy,
- cutover/fallback policy,
- perimeter presentation policy,
- Settings integration for placement, reordering, output overrides, and reset operations,
- regression contracts for topology, routing, settings, reservations, presentation, and cutover behavior.

The current implementation remains **opt-in**. Fresh/existing configurations continue to use the legacy composition unless `iiPerimeter` is explicitly requested and the cutover policy considers the requested composition valid.

If perimeter configuration, module resolution, output validation, or legacy compatibility requirements are not satisfied, the shell falls back instead of treating a partial Connected Perimeter as valid.

---

## Topology

Each output owns eight logical slots:

```text
┌─────────────────────────────────────────────────────────────────┐
│ TOP-LEFT                 TOP-CENTER                   TOP-RIGHT │
│                                                                 │
│                                                                 │
│ LEFT-EDGE                                            RIGHT-EDGE │
│                                                                 │
│                                                                 │
│ BOTTOM-LEFT             BOTTOM-CENTER              BOTTOM-RIGHT │
└─────────────────────────────────────────────────────────────────┘
```

Canonical slot IDs:

```text
top.start
top.center
top.end
left.center
right.center
bottom.start
bottom.center
bottom.end
```

The generic model is based on **edge + alignment**, not eight independent renderer implementations.

```text
edge: top | bottom | left | right
alignment: start | center | end
```

For left/right edges, `center` is currently the supported initial alignment.

Inward direction is derived from edge context:

```text
top    -> down
bottom -> up
left   -> right
right  -> left
```

This context is used by connected surfaces so placement does not depend on hard-coded module ownership.

---

## Default composition

`PerimeterConfig.qml` provides the architecture preset used when no explicit placement override is present:

| Slot | Default module instances |
|---|---|
| `top.start` | ThinkFan, System Monitor |
| `top.center` | Workspaces, Media, Weather |
| `top.end` | empty |
| `left.center` | Left Sidebar |
| `right.center` | Right Sidebar |
| `bottom.start` | empty |
| `bottom.center` | Dock |
| `bottom.end` | empty |

These are **defaults only**.

No module is permanently owned by a slot. A valid layout may leave slots empty, place multiple ordered instances in a slot, reorder instances, or move supported instances to another valid slot.

Placement belongs to perimeter configuration, not to feature implementation.

---

## Registered perimeter modules

`modules/perimeter/PerimeterFeatureRegistry.qml` currently registers:

- `thinkfan`
- `system-monitor`
- `workspaces`
- `media`
- `weather`
- `left-sidebar`
- `right-sidebar`
- `dock`

Feature adapters consume perimeter context; they do not choose their permanent edge or output.

The default preset currently places ThinkFan/System Monitor at top-left, Workspaces/Media/Weather at top-center, sidebars at the side centers, and Dock at bottom-center.

---

## Core architecture

Reusable Connected Perimeter infrastructure lives under:

```text
modules/common/perimeter/
```

Important components include:

```text
AnchorPublisher.qml
AnchorRegistry.qml
ConnectedSurfaceConnector.qml
ConnectedSurfaceFrame.qml
ConnectedSurfaceGeometry.qml
ConnectedSurfaceMask.qml
ModuleRegistry.qml
PerimeterAnchorPublisher.qml
PerimeterConfig.qml
PerimeterContext.qml
PerimeterCutoverPolicy.qml
PerimeterModuleHost.qml
PerimeterOutputHost.qml
PerimeterSlotHost.qml
PerimeterSlotModel.qml
PerimeterTokens.qml
PerimeterTopology.qml
SurfaceRouteController.qml
```

Hadalis-specific feature adapters live under:

```text
modules/perimeter/
```

The key ownership flow is:

```text
module
  -> registry/config
     -> placement
        -> perimeter host
           -> rendered surface / connected route
```

not:

```text
component
  -> hard-coded screen position
```

---

## Configuration model

The typed configuration exposes a `perimeter` node with schema version `1`.

The model supports:

- shared module instance descriptors,
- shared/default slot entries,
- per-output slot overrides,
- per-output instance overrides,
- validation of slot IDs and configured sources,
- reset to default/shared placement,
- compatibility handling for older persisted object/map representation.

An omitted slot may inherit the architecture preset. An explicitly configured empty slot remains empty.

Malformed output entries, duplicate descriptors, unsupported schema versions, invalid slots, or unresolved module sources must fail validation rather than being rendered blindly.

---

## Routing and connected surfaces

Connected popups use the real rendered module anchor instead of deriving position from assumed module ordering.

Routing is output-aware and coordinated through the shared route/controller layer so transient surfaces do not compete through unrelated state flags indefinitely.

The migration target is:

- deterministic output ownership,
- deterministic Escape/backdrop/focus-loss behavior,
- explicit transient-surface conflicts,
- anchor-aware popup geometry,
- visible/input geometry derived from the same authority,
- correct inward expansion for all supported edges,
- click-through transparent regions,
- no bogus reservation or hit region for empty slots.

Media and Weather already have Connected Surface adapters. Routing and anchor infrastructure are implemented, while migration of the wider transient-surface set remains ongoing.

---

## Sidebars and Dock

Left and right sidebars are registered perimeter modules.

Their semantic feature/system state remains global, while perimeter placement controls where their presentation is available. Output routing also respects configured sidebar screen eligibility.

The Connected Perimeter target is not a permanently full-height sidebar host. Presentation size, placement, input ownership, and edge relationship are handled by perimeter policies while preserving useful existing sidebar lifecycle/compositor behavior.

Dock is a normal perimeter module instance. `bottom.center` is its default placement, not architectural ownership.

---

## Settings / layout editing

`modules/settings/ShellLayoutConfig.qml` contains the Connected Perimeter layout controls.

Current Settings support includes:

- enabling/disabling the perimeter cutover request,
- shared/default versus per-output placement scope,
- selecting valid slots,
- moving module instances,
- reordering instances within a slot,
- resetting per-output overrides,
- resetting shared/default placement,
- live shell layout editing integration.

A future custom preset library may extend this model, but placement is already centrally editable and is not implemented as independent hard-coded `position` controls inside every module.

---

## Cutover and fallback

`PerimeterCutoverPolicy.qml` enables perimeter ownership only when the requested composition is safe to activate.

The policy currently evaluates conditions including:

1. `iiPerimeter` is requested in `enabledPanels`;
2. current legacy bar/dock policies are compatible with cutover;
3. perimeter configuration validates for connected outputs;
4. configured modules resolve through the registry.

If the perimeter is requested but the composition is incomplete or invalid, fallback remains active instead of leaving the shell in a partially-owned state.

This fallback is intentional during migration and stabilization.

---

## Regression contracts

Connected Perimeter behavior is guarded by repository tests rather than documentation alone.

The test suite covers areas including:

- required core/feature files,
- module registry resolution,
- cutover policy state,
- output-specific placement,
- route ownership,
- settings placement behavior,
- reservation metadata and edge zones,
- click-through reservation surfaces,
- presentation lifecycle,
- disabled-module behavior,
- runtime/registry recovery,
- QML startup/static validation.

Perimeter contracts are also invoked from the full QML validation path used by CI.

---

## Legacy cleanup

The conversion is being built on the cleaned Material ii / Classic baseline.

Retired renderer/feature families removed from the live graph must not be reintroduced merely to satisfy old references. This includes the retired Bar M3, Pill, Orbit, Mascot, Workspace Strip, and related obsolete settings paths removed during the cleanup work.

Classic Bar remains part of the compatibility/fallback path while Connected Perimeter cutover is opt-in.

The project is still completing product/namespace cleanup. Runtime, package, and user configuration paths currently retain historical `inir` / `illogical-impulse` naming in places, so namespace migration must preserve backward compatibility rather than being performed as an unsafe global rename.

---

## Future design direction

The following items are **planned design direction**, not claims about current Hadalis implementation and not blockers for stabilizing the existing Connected Perimeter release. They should be implemented as Hadalis-native connected surfaces after the relevant runtime/service contracts are ready.

### Serpantinum-inspired connected popups

Reference: `https://github.com/ilyamiro/serpantinum`

Hadalis may use selected **popup/content interaction ideas** from Serpantinum. The Serpantinum bar itself is **not** a target and should not be copied. Any adopted presentation must remain compatible with Hadalis' movable perimeter modules, output-aware anchors, inward-direction rules, route controller, masks, focus semantics, and lifecycle policies.

Planned areas:

- **Bluetooth** — a connected Bluetooth popup inspired by Serpantinum's device presentation and interaction hierarchy. It should expose discovery, paired/connected state, connect/disconnect actions, useful device metadata, and battery/profile information when the backend provides it. The popup must originate from the actual triggering module anchor instead of from a fixed bar position.
- **Dashboard** — a Hadalis connected dashboard may combine calendar/date/schedule information, weather, and selected glanceable system information in one composition. Serpantinum's current dashboard preset provides a useful layout reference for weather and system-resource cards, while its calendar exists as a separate feature; Hadalis intentionally may combine those ideas rather than reproduce the preset literally.
- **Media** — evolve the existing Connected Media surface toward a richer presentation inspired by Serpantinum: MPRIS playback, artwork-driven presentation, audio visualization, and an optional equalizer/preset view. Serpantinum's current implementation uses Cava-style visualization and an EasyEffects-backed equalizer helper; Hadalis should audit its own audio/service boundary before selecting an equalizer backend instead of transplanting that implementation directly.

Visual reference supplied for the Media direction: `https://www.threads.com/@saadkhalidhere/post/Dbrd_L_CBns`.

The current Serpantinum source contains the corresponding Media/equalizer feature set, but the exact visual revision shown by the external video should be treated as a reference rather than as a guaranteed one-to-one representation of current `master`.

### Breezy Weather-inspired right sidebar

Reference: `https://github.com/breezy-weather/breezy-weather`

The future right-sidebar Weather experience may use Breezy Weather as a **visualization and information-hierarchy reference**, especially its Material 3 Expressive block model and dense but readable forecast presentation.

Candidate right-sidebar weather content includes:

- current conditions and feels-like temperature,
- compact hourly and daily forecast views,
- precipitation/next-hour information where supported by the selected data source,
- severe-weather alerts,
- wind, humidity, pressure, visibility, and UV,
- air-quality and pollen information where available,
- sunrise/sunset and moon information,
- compact chart views where they remain readable inside the sidebar.

Hadalis does not need to reproduce Breezy Weather's Android application architecture or its large weather-provider matrix. The target is a Hadalis-native QML sidebar presentation backed by the shell's own weather service/data contracts.

### Provenance and implementation rules

These references are architectural/visual inspiration, not an instruction to merge source trees.

- Do not copy Serpantinum's bar design.
- Prefer clean Hadalis-native QML implementations that reproduce desired interaction/design principles through existing Hadalis services.
- Future popups must use Connected Perimeter anchors/routes rather than introduce new fixed-position popup ownership.
- Keep backend/service behavior separate from presentation so future designs remain movable and replaceable.
- Serpantinum is AGPL-3.0-or-later and Breezy Weather is LGPL-3.0; any future direct code or asset reuse must be reviewed for license/attribution implications before it enters Hadalis. Design inspiration alone should not become an accidental source-code transplant.

---

## What remains before release

The project has moved beyond architecture/prototype work. The remaining work is primarily migration, hardening, and release preparation:

- migrate remaining transient surfaces onto the shared anchor/routing/lifecycle model where appropriate;
- finish feature parity needed before making Connected Perimeter the default;
- continue multi-output, hotplug, resume, focus, fullscreen, fractional-scale, and reservation hardening;
- stabilize CI, documentation, Nix, Arch packaging, install/uninstall, and release contracts;
- complete product/namespace cutover with compatibility migration;
- keep README and architecture/release documentation synchronized with live behavior;
- run live acceptance on supported multi-monitor configurations;
- freeze `dev` and merge to `stable` only after release gates are green.

The Connected Perimeter should **not** be treated as release-complete merely because the core runtime exists.

---

## Development rules

When extending the perimeter:

- add reusable composition behavior under `modules/common/perimeter/`;
- add Hadalis-specific adapters under `modules/perimeter/`;
- register module IDs through `PerimeterFeatureRegistry`;
- keep feature state/functionality separate from placement;
- preserve empty-slot and multiple-instance behavior;
- carry output identity through anchors, routes, placement, and input regions;
- validate per-output configuration before rendering/reserving compositor space;
- preserve fallback behavior until cutover policy explicitly considers the requested composition ready;
- do not restore retired renderer families or appearance selectors;
- prefer small, atomic changes on current `dev`.

---

## References

### Hadalis

- [`docs/PERIMETER.md`](docs/PERIMETER.md)
- [`ARCHITECTURE.md`](ARCHITECTURE.md)
- [`STRUCTURE.md`](STRUCTURE.md)
- [`docs/INSTALL.md`](docs/INSTALL.md)
- [`docs/PACKAGES.md`](docs/PACKAGES.md)
- [`docs/RELEASING.md`](docs/RELEASING.md)
- `modules/common/perimeter/`
- `modules/perimeter/`
- `modules/settings/ShellLayoutConfig.qml`
- `modules/ii/ShellIiPanelsImpl.qml`

### Architectural references

- Caelestia shell: `https://github.com/caelestia-dots/shell`
- Serpantinum: `https://github.com/ilyamiro/serpantinum`
- Breezy Weather: `https://github.com/breezy-weather/breezy-weather`

Caelestia is primarily a connected-composition architecture reference. Serpantinum is a future popup/content design reference, explicitly excluding its bar design. Breezy Weather is a future weather visualization/information-hierarchy reference for the right sidebar. None of these references changes Hadalis' ownership of its final topology, visual language, routing, lifecycle, and implementation.

### ThinkFan

Upstream: `https://github.com/vmatare/thinkfan`

ThinkFan integration is hardware control. Configuration mutation must remain validated, privileged only where necessary, non-blocking to QML, and fail-safe when compatible hardware/service state is unavailable.

---

## Architecture rule

> **Hadalis is a configurable connected perimeter, not a fixed top bar plus fixed sidebars plus a fixed dock.**
>
> The eight perimeter slots are layout locations. Modules are movable instances. Connected surfaces derive direction and geometry from slot context and their real rendered anchor. Documented placements are defaults only.
