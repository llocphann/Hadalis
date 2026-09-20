# Connected Surfaces

Hadalis 1.0 uses a shared connected-surface presentation layer, not the retired full `iiPerimeter` composition runtime.

## Authoritative renderers

ii Bar popouts use:

```text
StyledPopup.qml
  -> ConnectedSurfaceGeometry.qml
  -> ConnectedSurfaceRevealClip.qml
  -> ConnectedSurfaceIrisFrame.qml
       -> ConnectedSurfaceIrisField.qml
       -> IrisField.frag.qsb
  -> ConnectedSurfaceContentHost.qml
  -> ConnectedSurfaceBodyMask.qml
```

Existing feature-owned bodies that attach directly to Screen Edge use
`ConnectedSurfaceIrisEdgeSurface.qml`. It adapts an already-laid-out body into
the same iRiS field, welds only the SDF record under the owner with
`irisWeldDepth`, and clips field/shadow pixels at the real owner boundary.
Sidebar, Dashboard, Settings and Dock use this adapter.

ii Bar popup, Dock, Sidebar and Dashboard shadows share the public Screen Edge
shadow controls (`appearance.screenEdge.physicalShadow`) and raw Material
`m3shadow` ink. This keeps connected-edge depth visually aligned with the
physical perimeter while the existing owner clip prevents shadow from painting
across Bar/Screen Edge pixels. Settings/OSK keep their older connected-body
shadow owner.

The old standalone corner/wedge painters are retired and must remain absent:

- `ConnectedSurfaceJoinFlares`;
- `PerimeterCornerShadow`;
- `RoundCorner`;
- the `joinFlareRadius` / `joinFlareCrossScale` token family;
- fake screen-rounding paint in `ScreenCorners.qml`.

Waffle keeps its own non-iRiS `ConnectedSurfaceFrame` body/shadow renderer,
but direct-seam input is body-only through `ConnectedSurfaceBodyMask`.
The connector-only Canvas renderer and connector-strip mask are retired.
Search and OSK likewise keep direct square joined edges until explicitly moved to
an iRiS adapter.

## Screen Edge ownership

`modules/screenCorners/ScreenEdges.qml` is the only physical Screen Edge
renderer. Each output has one full-screen `FrameWindow`, one odd-even
`ShapePath`, exactly four circular `PathArc` segments for the rounded
workspace hole, and transparent reservation windows. Bar ownership changes only
the matching inner-frame inset.

`ScreenCorners.qml` is interaction-only: Sidebar hot corners, Orbit and
brightness/volume gestures. It must not paint fake rounded corners.

## Sidebar contract

`SidebarHost.qml` owns left/right placement and lifecycle. The content body
starts at the inner Screen Edge boundary; `ConnectedSurfaceIrisEdgeSurface`
owns the joined field. During close, `hiddenTranslateDistance` moves the body
past the complete native host plus iRiS/shadow overflow so neither body nor
field can remain visible as a sliver.

## Dashboard and Settings

Bottom-connected Dashboard and Settings surfaces use
`ConnectedSurfaceIrisEdgeSurface` with the real Screen Edge/Bar owner
thickness. Their local body rectangles are transparent while the iRiS field owns
the visible fill and shadow. No full-overlay wedge/flare helper is allowed.

## Contributor rules

- preserve `StyledPopup.qml` as the normal ii Bar-popout entry point;
- use iRiS for curved connected contact; do not recreate Canvas/Shape wedge patches;
- keep the physical Screen Edge renderer separate from Overlay surfaces;
- preserve output ownership, slide/retract lifecycle, focus and click-through input;
- keep Waffle supported without reintroducing legacy corner painters;
- do not reintroduce `modules/perimeter/`, `iiPerimeter`, cutover registries or feature-slot composition.

Static contracts do not replace live Niri acceptance at left/right/top/bottom
attachment and fractional scaling.
