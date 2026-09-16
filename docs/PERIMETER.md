# Connected Perimeter

The Connected Perimeter is Hadalis' shared geometry/composition layer for shell surfaces. The reusable infrastructure lives in `modules/common/perimeter/`, while Hadalis feature adapters live in `modules/perimeter/`.

Two related concerns must remain distinct during stabilization:

- **Connected-surface presentation** is already used by the existing bar popup architecture through `modules/bar/StyledPopup.qml`. This is the default popup presentation path and does not require a new setting or feature flag.
- **Full `iiPerimeter` composition ownership** is a broader panel cutover. It remains opt-in until its feature set is equivalent to the legacy composition; it must not be enabled merely to obtain connected popup geometry.

## Connected popup contract

`StyledPopup.qml` keeps the established popup role and composes the shared perimeter primitives instead of introducing a second popup framework.

The shared geometry supports every bar edge:

| Bar attachment | Popup inward direction |
|---|---|
| top | down |
| bottom | up |
| left | right |
| right | left |

`ConnectedSurfaceGeometry.qml` is the geometry authority for the popup body, connector, reveal progress, output bounds and attachment edge. `ConnectedSurfaceFrame.qml`, `ConnectedSurfaceConnector.qml`, and `ConnectedSurfaceMask.qml` consume that geometry for presentation and input shape.

The visual target is a bar-owned deformation rather than a detached card:

- the surface starts at approximately the real source control width and grows inward from that rendered anchor;
- the connector flares from the source through cubic Bézier shoulders into the wider body instead of rendering as a thin rectangular stem;
- the body expands on both its tangent and inward axes, so opening reads as one surface extruding from the bar;
- the outer shell uses the active Classic Bar surface family instead of the old generic popup-card material;
- close reverses the same geometry and keeps the loader resident until the body has retracted into the bar;
- hover-triggered popouts keep their short retract tail interactive so a pointer crossing the connected shoulder can enter the popup body without collapsing it;
- focused popouts retain layer-shell/compositor focus behavior rather than requiring a detached window implementation.

The seam/input contract is equally intentional:

- body and connector overlap by a device-pixel-aware amount;
- the connector overlaps the source edge as well as the popup body so fractional scale cannot expose a transparent gap;
- the input mask approximates the Bézier flare with a tighter union rather than treating the connector's transparent bounding rectangle as clickable;
- transparent portions of the full-output popup window remain click-through.

Current bar popouts using this shared shell include the existing battery, resources, weather, clock, timer, update and tray surfaces, plus the migrated Media volume HUD, expanded bar Media controls and taskbar window previews. Context menus retain context-menu semantics instead of being forced into the connected-popout presentation.

Do not add per-feature copies of this geometry. A bar popup that can use `StyledPopup.qml` should inherit the connected behavior there.

## Topology

The full perimeter runtime exposes eight placement slots:

| User-facing position | Slot ID |
|---|---|
| Top-left | `top.start` |
| Top-center | `top.center` |
| Top-right | `top.end` |
| Left edge | `left.center` |
| Right edge | `right.center` |
| Bottom-left | `bottom.start` |
| Bottom-center | `bottom.center` |
| Bottom-right | `bottom.end` |

A slot may be empty or contain one or more ordered module instances. Placement belongs to perimeter configuration, not to the module implementation itself.

## Current default composition

`PerimeterConfig.qml` provides the architecture preset used when no explicit perimeter placement overrides are present:

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

These are defaults, not hard bindings. Explicit slot configuration can reorder instances, move them to another valid slot, or leave a slot empty.

## Registered modules

`modules/perimeter/PerimeterFeatureRegistry.qml` currently registers these module IDs:

- `thinkfan`
- `system-monitor`
- `workspaces`
- `media`
- `weather`
- `left-sidebar`
- `right-sidebar`
- `dock`

The registry resolves module IDs to QML sources. Hosts consume instance descriptors and placement from `PerimeterConfig`; feature adapters do not choose their own permanent edge or slot.

## Configuration model

The typed `Config.qml` schema exposes a `perimeter` node with schema version `1`, shared instance descriptors, shared/default slot entries, and per-output overrides. `PerimeterConfig.qml` also accepts the older object/map representation when reading data, while the typed adapter-friendly representation uses lists.

A representative persisted shape is:

```json
{
  "perimeter": {
    "schemaVersion": 1,
    "instances": [],
    "defaultSlots": [
      {
        "slotId": "top.start",
        "instanceIds": ["thinkfan-main", "system-monitor-main"]
      },
      {
        "slotId": "top.end",
        "instanceIds": []
      }
    ],
    "outputs": []
  }
}
```

An omitted slot entry inherits the architecture preset. An explicit slot entry with an empty `instanceIds` array leaves that slot empty. An empty shared `instances` list uses the built-in descriptor catalog; removing a module from the rendered composition is therefore a placement operation, not a requirement to delete its descriptor.

Per-output entries may override slot placement and instance descriptors for a named output. Invalid slot IDs, duplicate descriptors, malformed output entries, unsupported schema versions, or unresolved configured module sources fail perimeter validation instead of being rendered blindly.

## Runtime and cutover

`modules/perimeter/PerimeterRuntime.qml` creates the per-output host and edge reservation surfaces. `PerimeterCutoverPolicy.qml` enables full perimeter ownership only when all of the following are true:

1. `iiPerimeter` is requested in `enabledPanels`;
2. the current legacy bar/dock policies are compatible with cutover;
3. the perimeter configuration validates for every connected output; and
4. every configured module resolves through the module registry.

If the perimeter was requested but one of those conditions is not satisfied, the cutover policy reports a fallback state instead of treating a partial composition as valid.

At the current `dev` defaults, full `iiPerimeter` ownership is not enabled by default. This is deliberate: the legacy composition keeps functionality that must not disappear during migration. Connected popup presentation through `StyledPopup.qml` does not depend on this cutover.

## Dock and Waffle

Dock's supported user-facing style is **Panel**. Legacy persisted Dock style values are normalized to `panel` during startup and the Dock settings page no longer exposes Pill/macOS/Island/M3 choices.

Waffle is not a Dock style. It remains a separate panel family and must not be folded into `dock.style` migration or styling logic.

## Sidebars

Left and right sidebars are registered perimeter modules. Their semantic feature/system state remains global, while perimeter placement controls where a sidebar presentation is available. Runtime routing also respects `sidebar.screenList` when choosing eligible connected outputs.

The edge host is not defined as a permanently full-height sidebar. Size, placement and input ownership are handled by the perimeter host/surface policies so the sidebar adapter can remain movable with the rest of the composition.

## Contributor rules

When extending the perimeter:

- reuse `StyledPopup.qml` for existing bar popups instead of creating a parallel popup framework;
- preserve the source-width morph, curved shoulder, reverse-retract, and shape-aware input contracts instead of replacing them with a floating card plus stem;
- add reusable composition behavior under `modules/common/perimeter/`;
- add Hadalis-specific module adapters under `modules/perimeter/`;
- register module IDs through `PerimeterFeatureRegistry` rather than hard-coding them into a host;
- keep module state/functionality separate from placement;
- preserve empty-slot and multiple-instance behavior;
- validate per-output configuration before rendering or reserving compositor space;
- preserve Waffle as its own panel family;
- keep legacy fallback behavior intact until the cutover policy explicitly considers the requested composition ready;
- do not add a user-facing Connected Perimeter appearance toggle just to control connected popup geometry.

The key flow is:

```text
module -> registry/config -> placement -> host -> rendered surface
```

not:

```text
component -> hard-coded screen position
```
