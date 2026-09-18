# Connected Surfaces

Hadalis 1.0 uses a **shared connected-surface presentation layer**, not the retired full `iiPerimeter` composition runtime.

The authoritative connected-popup path is:

```text
modules/bar/StyledPopup.qml
  -> modules/common/perimeter/ConnectedSurfaceGeometry.qml
  -> modules/common/perimeter/ConnectedSurfaceFrame.qml
  -> modules/common/perimeter/ConnectedSurfaceConnector.qml
  -> modules/common/perimeter/ConnectedSurfaceContentHost.qml
  -> modules/common/perimeter/ConnectedSurfaceMask.qml
  -> modules/common/perimeter/PerimeterTokens.qml
```

`ConnectedSurfaceGeometry.qml` also uses the small `PerimeterTopology.qml` edge utility for edge validation and inward-direction mapping. That utility is not a panel-composition runtime.

## What is retired

The broad `modules/perimeter/` runtime, feature adapters, registry, reservation/presentation policies and `iiPerimeter` cutover ownership were retired from the active shell. They must not be recreated to solve popup, Sidebar, Screen Edge or Overview geometry.

In particular:

- there is no supported `modules/perimeter/PerimeterRuntime.qml` owner;
- there is no supported `PerimeterFeatureRegistry` module-placement system;
- `iiPerimeter` is not a third panel family;
- normal Media, Weather, Sidebar, Dock or System Monitor UX must not depend on a perimeter cutover flag;
- Waffle remains its own supported panel family.

Some source-only helper/compatibility files may still remain under `modules/common/perimeter/` while cleanup is audited. They are **not** runtime authority and must not gain new callers merely because they still exist.

## Connected popup contract

`StyledPopup.qml` remains the entry point for existing bar popouts. Consumers provide their content and real source control through `hoverTarget`; the shared shell owns the geometry and presentation window.

The shared geometry supports top, bottom, left and right attachment:

| Source edge | Popup grows inward |
|---|---|
| top | down |
| bottom | up |
| left | right |
| right | left |

The presentation contract is:

- anchor/output ownership comes from the real source control and its window;
- connector width, length, seam overlap and radii come from `PerimeterTokens.qml`;
- body and connector morph from the source instead of rendering as a detached card plus stem;
- close reverses the same geometry and may keep the presentation resident briefly for reverse retract/hover transfer;
- transparent regions of the full-output presentation remain click-through;
- input masking follows the visible connected shape rather than the connector's rectangular bounding box;
- focused popouts preserve keyboard focus, Escape/close handoff and compositor focus behavior;
- outside-click catchers, when enabled, stay on the same output as the source popup.

Do not add per-feature connector geometry when the shared primitive can represent the surface.

## Screen Edge ownership

`modules/screenCorners/ScreenEdges.qml` owns the persistent visual Screen Edge.

Current invariants:

- Screen Edge is presentation-only and uses `exclusiveZone: 0` / `ExclusionMode.Ignore`;
- edge and corner windows are click-through;
- visual width/radius do not own Sidebar hit regions or compositor reservation;
- the exact edge occupied by an ii Bar is suppressed on that output so Bar and Screen Edge do not double-paint the same edge;
- the Screen Edge uses the Material Bar surface token on the supported ii path;
- rounded wallpaper-facing inner corners are visual overlays and do not change the rectangular physical edge bands.

## Sidebars

Left and right Sidebar bridges are owned inside `modules/sidebar/SidebarHost.qml`, not by a separate perimeter module or standalone bridge window.

The connector:

- shares the Sidebar's output, visibility and lifecycle;
- connects the left Sidebar to the left Screen Edge and the right Sidebar to the right Screen Edge;
- uses `ConnectedSurfaceConnector` and the canonical `PerimeterTokens` seam/width values;
- does not depend on top/bottom Bar placement.

Sidebar semantic state, resizing and routing remain owned by the existing Sidebar architecture.

## Overview

The Overview/dashboard remains in the existing Overview architecture. Its bottom attachment is a presentation bridge, not a perimeter-runtime route.

`modules/overview/Overview.qml` draws a shared `ConnectedSurfaceConnector` from the visible dashboard body to the inner boundary of the bottom Screen Edge, using the dashboard's actual body rect/color and the canonical connector/seam tokens.

## Context menus and other surfaces

Context menus keep context-menu semantics. They are not forced into `StyledPopup` merely for visual consistency.

Likewise, a feature that already owns an appropriate native surface should reuse the shared connector primitive directly when needed rather than creating a parallel popup framework.

## Contributor rules

When changing connected surfaces:

- preserve `StyledPopup.qml` as the normal bar-popout entry point;
- fix systemic connector/seam/input defects in the shared primitive instead of adding per-popup magic numbers;
- preserve source-screen ownership and top/bottom/left/right placement;
- keep transparent full-output regions click-through;
- preserve reverse retract, hover transfer, keyboard focus, Escape and outside-click behavior;
- use `PerimeterTokens.qml` for shared geometry constants;
- keep Screen Edge, Sidebar and Overview ownership in their existing feature architectures;
- do not reintroduce `modules/perimeter/`, `iiPerimeter`, feature registries, cutover toggles or panel-slot composition;
- preserve Waffle as a separate supported panel family.

Any remaining broad-runtime helper under `modules/common/perimeter/` should be removed only after exact caller auditing proves it is unused; do not delete the supported `ConnectedSurface*` primitives or `PerimeterTokens.qml` as part of that cleanup.
