# Hadalis Connected Perimeter

> **Status:** implemented on `dev`, active integration/stabilization  
> **Updated:** 2026-09-16  
> **Cutover:** opt-in; not yet the fresh-install default  
> **Validation policy:** clean-clone local non-Nix validation is the primary maintainer gate during the current stabilization phase  
> **Maintainer workflow:** the daily-use checkout may remain on `stable`; validation clones `dev` into a temporary directory and must not mutate the stable working tree  
> **Release state:** not ready for `dev -> stable` until local validation, documentation, Arch packaging/install, and live acceptance gates are green

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

Perimeter contracts are invoked from the full QML validation path used by local acceptance. Hosted CI should mirror those checks where practical, but hosted status is diagnostic rather than the maintainer source of truth during this stabilization phase.

---

## Local validation policy and latest snapshot

During the current stabilization phase, the maintainer release signal is a **clean clone of `dev` followed by local build/regression validation**. Hosted GitHub Actions are useful diagnostics, but they do not override a reproducible local result. Dedicated Nix validation is temporarily outside the maintainer acceptance gate because the active environment does not use Nix; this does **not** claim that Nix support is currently green.

### Maintainer workflow

The normal desktop can remain on the `stable` branch while development validation happens independently:

```text
daily-use checkout: stable
        |
        |  untouched by validation
        v
local validator
        |
        +--> mktemp directory
        +--> clean clone of dev
        +--> build + non-Nix tests + docs + QML guards + staged install
        +--> log records the exact tested SHA
```

The validator must not `git switch`, `git checkout`, `git pull`, reset, or otherwise mutate the maintainer's existing `stable` working tree. Only the temporary `dev` clone is built and tested.

A result applies only to the exact SHA printed in the validation log. If `dev` advances after that SHA, the new HEAD is **unvalidated** until the clean-clone local suite is rerun. Bots may fix code and contracts on `dev`, but they must not claim the newer HEAD is green before a maintainer local rerun confirms it.

The latest completed clean-clone validation supplied by the maintainer was run against:

```text
724e06cb04b827aba89e242c029738b42334bc95
```

That snapshot passed:

- `make build` and tracked Bash/Fish/Python/JavaScript/JSON syntax checks;
- IPC registry generated-state and parser checks;
- battery/TLP helper runtime tests except the stale Settings UI contract described below;
- ThinkFan helper and lifecycle checks;
- News service contract;
- optional audio dependency and Equalizer boundary/service contracts;
- every Connected Perimeter cutover, compatibility-placement, family, route, settings, source, and runtime-health contract;
- full-tree QML project guards with no fatal issues;
- staged full install/build and staged runtime sanity checks.

The same snapshot reported eight top-level failures, which reduce to four independent issue groups:

1. **Localization/catalog drift — real release work.** Translation audit, source parity, cleaner tests, and documentation verification are red. Most shipped locales are only a few keys behind, while `tr_TR` is substantially stale and also fails placeholder/protected-term checks. Source parity also reports a large live/catalog mismatch. Documentation verification is red primarily because it includes the failing runtime locale validation.
2. **TLP Settings guard — stale test contract.** The test expects the old literal `category.pages.filter(index => index !== root.retiredTlpPageIndex)`, while the live registry now uses the broader `isHiddenLegacyIndex()` helper so all retired feature indexes remain filtered. The implementation preserves the intended behavior; the assertion needs to follow the current abstraction.
3. **Make-install lifecycle fixture — test setup defect.** The test explicitly notes that package installation does not create managed TLP drop-ins, then writes synthetic drop-ins into the staged TLP directory without creating that directory first. The fixture needs to create its staging directory before writing those files.
4. **Packaging aggregate contract — stale ordering assertion.** `make test-local` still includes optional-audio, Equalizer, News, and docs targets, but the packaging test searches for an older contiguous target sequence that no longer matches after `test-news-contract` was inserted.

QML validation on that snapshot emitted 10 advisory warnings and skipped the parser pass because the detected `qmlformat 1.0` is below the project’s supported parser threshold. Project-specific startup/architecture guards still ran and passed, but a future acceptance run on a modern Qt/QML parser should also exercise the parser pass.

### Current completion order

Until a newer local validation proves otherwise, repository completion work should be prioritized in this order:

1. reconcile translation catalogs/source parity and make documentation locale validation pass;
2. repair stale or broken local test contracts without weakening their intended behavior;
3. rerun the clean-clone local non-Nix validator and use its exact SHA as the next acceptance checkpoint;
4. exercise full QML parsing with a supported modern Qt/QML parser when available;
5. continue multi-output/hotplug/resume/focus/fullscreen/fractional-scale live acceptance and remaining transient-surface migration;
6. finish namespace/product migration and release documentation;
7. only then expand large optional presentation features.

Nix remains a deferred compatibility lane, not a reason to block progress in the current maintainer environment. It should not be deleted or declared supported/green without evidence.

---

## Legacy cleanup

The conversion is being built on the cleaned Material ii / Classic baseline.

Retired renderer/feature families removed from the live graph must not be reintroduced merely to satisfy old references. This includes the retired Bar M3, Pill, Orbit, Mascot, Workspace Strip, and related obsolete settings paths removed during the cleanup work.

Classic Bar remains part of the compatibility/fallback path while Connected Perimeter cutover is opt-in.

The project is still completing product/namespace cleanup. Runtime, package, and user configuration paths currently retain historical `inir` / `illogical-impulse` naming in places, so namespace migration must preserve backward compatibility rather than being performed as an unsafe global rename.

---

## Equalizer implementation status

Serpantinum is currently used only as an external interaction/design reference for the Media equalizer direction. Other Serpantinum features and other external UI references remain deferred.

### Implemented

- `EqualizerService.qml` provides the Phase 1 backend/service contract and is disabled by default.
- EasyEffects is an optional backend, with optional transport support; absence of the backend/transport does not block normal Media playback.
- the service boundary exposes capability/error/lifecycle state and preset/band mutation APIs without putting backend execution into Media presentation code;
- architecture, lifecycle/protocol, packaging, and optional-dependency contracts guard this Phase 1 boundary. A Nix contract also exists in-tree but is temporarily outside the maintainer local acceptance gate.

### Stabilizing

- backend capability detection and lifecycle/error behavior across supported EasyEffects installation modes;
- packaging/install/release behavior that keeps EasyEffects and its transport optional;
- interaction with Connected Media routing/lifecycle without coupling Equalizer execution to shell startup.

### Planned

Reference: `https://github.com/ilyamiro/serpantinum`

The planned presentation work is to take the **equalizer concept and interaction model** from Serpantinum and integrate it directly **below the existing Hadalis Media content** inside the current Connected Media popup. It should extend the current Hadalis Media surface rather than replace or redesign it.

Target behavior:

- preserve Hadalis' existing Media/MPRIS presentation and playback controls;
- place the equalizer below the current media content;
- provide multi-band gain controls and useful preset/apply/reset state based on the Serpantinum equalizer interaction model;
- use Hadalis' existing EasyEffects/service boundary instead of introducing a second audio-control stack;
- keep equalizer runtime/process work inactive when the Media surface is not using it;
- make absence of EasyEffects or a compatible audio path fail gracefully without breaking Media playback controls.

Serpantinum currently implements its Media equalizer around EasyEffects and an `equalizer.sh` helper. Prefer a Hadalis-native presentation integrated with the existing Media and EasyEffects boundaries rather than copying unrelated Serpantinum UI or architecture.

The full Equalizer UI, spectrum, preset surface, multi-band presentation redesign, Serpantinum bar design, Bluetooth popup, Dashboard, other popups, and all other external design experiments are **planned/deferred rather than current release prerequisites**.

---

## What remains before release

The project has moved beyond architecture/prototype work. The remaining work is primarily migration, hardening, and release preparation:

- migrate remaining transient surfaces onto the shared anchor/routing/lifecycle model where appropriate;
- finish feature parity needed before making Connected Perimeter the default;
- continue multi-output, hotplug, resume, focus, fullscreen, fractional-scale, and reservation hardening;
- make the clean-clone local non-Nix regression suite green, including localization/documentation, Arch packaging, install/uninstall, and release contracts;
- keep hosted CI aligned with the local acceptance suite where useful, while treating Nix as temporarily non-blocking for the current maintainer environment;
- complete product/namespace cutover with compatibility migration;
- keep README and architecture/release documentation synchronized with live behavior;
- run live acceptance on supported multi-monitor configurations;
- freeze `dev` and merge to `stable` only after the active release gates are green.

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

Caelestia remains the connected-composition architecture reference. Serpantinum is currently referenced only for the **Media equalizer behavior/design**. No Serpantinum bar, Bluetooth, Dashboard, or other popup work is planned at this time. These references do not change Hadalis' ownership of its final topology, routing, lifecycle, service boundaries, and QML integration.

### ThinkFan

Upstream: `https://github.com/vmatare/thinkfan`

ThinkFan integration is hardware control. Configuration mutation must remain validated, privileged only where necessary, non-blocking to QML, and fail-safe when compatible hardware/service state is unavailable.

---

## Architecture rule

> **Hadalis is a configurable connected perimeter, not a fixed top bar plus fixed sidebars plus a fixed dock.**
>
> The eight perimeter slots are layout locations. Modules are movable instances. Connected surfaces derive direction and geometry from slot context and their real rendered anchor. Documented placements are defaults only.
