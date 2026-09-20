# Shell Surface Contracts

This document records the stabilization contracts that should be checked during a local acceptance pass on `dev`.

## Connected bar popouts

- Existing bar popouts continue through `modules/bar/StyledPopup.qml`; no parallel popup framework is introduced.
- ii `StyledPopup` composes `ConnectedSurfaceGeometry`, `ConnectedSurfaceRevealClip`, `ConnectedSurfaceIrisFrame`, `ConnectedSurfaceContentHost`, and `ConnectedSurfaceBodyMask` from `modules/common/perimeter/`. Waffle retains its legacy shared-frame path.
- Attachment works from top, bottom, left, and right bars.
- The visible ii popup is not a detached rounded card or Bézier shoulder patch. Exact iRiS SDF smooth-union math treats popup and Bar/Screen Edge owner records as one silhouette while split-composition scissoring prevents Overlay from repainting Top-layer owners.
- The popup body uses the active Classic Bar surface family rather than the old generic popup-card material.
- Opening and closing are pure attachment-axis slides under the fixed owner seam; no scale/fade/morph stage is introduced before the loader is released.
- Hover popouts stay resident during the short retract tail so the pointer can cross the Bar↔popup seam into the body without collapsing the surface.
- The iRiS body welds under joined owners by `irisWeldDepth = 3`; field/shadow/input scissoring still begins at the actual owner boundary, so the weld cannot repaint or steal input from Bar/Screen Edge pixels.
- Bar popup shadows use the same public Screen Edge shadow controls and Material `m3shadow` ink as the physical frame; owner-side clipping still suppresses shadow across joined Bar/Screen Edge pixels.
- Popup input is body-only through `ConnectedSurfaceBodyMask`; shader fillets and transparent full-output regions do not steal pointer input. The old connector Canvas and connector-strip mask are retired entirely, including from Waffle.
- Transparent regions outside the visible popup shape remain click-through.
- Focused connected popouts preserve Niri layer-shell focus and the existing Hyprland compositor focus grab.
- Media volume HUD, expanded bar Media controls, tray overflow, taskbar window previews, and the existing battery/resources/weather/clock/timer/update popouts all use the shared connected path. Context menus remain context menus rather than being forced into this presentation contract.
- Connected popup presentation is independent of the retired broad `iiPerimeter` composition runtime; that runtime must not be reintroduced as a popup prerequisite.

## Classic Bar geometry

- Hug is the only supported Classic Bar corner/surface geometry.
- Float, Rectangle, and Card are retired choices and must not be exposed as user-selectable Bar styles.
- The persisted `bar.cornerStyle` key is compatibility-only. Startup normalizes any legacy non-zero value to `0` (Hug), including before the Settings page is opened.
- Runtime Bar layout must not branch on `cornerStyle`, `floatStyleShadow`, or any retired Float/Card geometry path.
- Material palette/theme tokens may still change color, material, blur, and rounding, but they do not switch the Classic Bar away from Hug geometry.
- Connected bar popouts inherit the Hug-owned surface contract and must not reintroduce a retired corner-style branch.

## Dock

- Panel is the only supported user-facing Dock style.
- Dock uses `ConnectedSurfaceIrisEdgeSurface` for top/bottom/left/right attachment, so the visible body stops at the real Screen Edge inner boundary while the SDF weld makes it one connected block with Screen Edge.
- The painted Dock ignores layer-shell exclusion zones and stays in physical-output coordinates. Pinned workspace reservation is owned by a separate transparent/input-empty reservation surface; never put `exclusiveZone` back on the painted Dock or the Screen Edge reservation will displace the iRiS seam.
- Pinned reservation ends at the Dock body's inward edge (`dock.height + appearance.screenEdge.width`), while transparent free-edge window room expands to the configured Screen Edge shadow reach. Changing shadow size therefore cannot move the Dock body or alter workspace reservation.
- Dock, Sidebar and Dashboard use the same `appearance.screenEdge.physicalShadow` size/opacity and Material `m3shadow` ink as the physical Screen Edge.
- Dock reveal/retract remains slide-only through `SurfaceMotion`; the iRiS body follows that translation rather than introducing a second animation stage.
- Panel controls derive their size from Dock height plus requested icon size: the default remains 50px, thin Docks shrink controls/icons rather than overflowing, and large icons can grow only when the configured Dock height has room. Shell-layout resize previews feed the same live thickness into app buttons, separators and the Overview button, so controls resize with the iRiS body instead of snapping after commit. Runtime fallbacks stay aligned with the shipped 60px Dock height and 2px hover-reveal region.
- Automatic desktop-zone insets use the same physical boundary as the pinned reservation (`dock.height + appearance.screenEdge.width`); transparent elevation/shadow room is never counted as occupied Dock thickness.
- `separatePinnedFromRunning=false` is one continuous visual list with no separator; the separator exists only in explicit separated mode. Pin/unpin identity matching is case-insensitive, persisted duplicate/case-variant pinned ids collapse to one runtime entry, and an invalid user ignored-app regex is skipped instead of aborting the Dock rebuild.
- Hover preview capture is app-scoped: hovering one Dock icon requests only that app's live window ids from `WindowPreviewService`; it must not trigger a full-session screenshot batch.
- Legacy persisted values such as Pill, macOS, Island, or M3 normalize to `panel` during startup.
- Retired Pill/macOS renderer components are absent from the live Dock module; Panel behavior must not be hidden behind constant-false style branches.
- The settings UI must not expose the legacy style matrix again.
- Waffle remains a separate panel family and is not a value of `dock.style`.

## UI language

- Shell UI localization is English-only.
- `services/Translation.qml` exposes canonical `en_US` and loads `translations/en_US.json`.
- Legacy `language.ui` values normalize to `en_US` during startup.
- `translations/` contains no other locale JSON catalogs.
- Translator/application language features are separate from shell UI localization and are not implied by this contract.

## Regression guard

Run the focused static contract locally with:

```sh
python scripts/test-shell-surface-contracts.py
```

The canonical maintainer validator also discovers this `test-*.py` guard automatically. The guard checks architectural/source contracts; it does not replace live visual testing.

## Local visual acceptance

For the final local pass, verify at minimum:

1. open battery, resources, weather, clock/timer/update and tray overflow from a top bar and confirm each outer shell visually grows from the source control rather than appearing as a separate card;
2. open the Media wheel-volume HUD, expanded bar Media controls, and taskbar window preview and confirm they use the same connected shell rather than their previous detached `PopupWindow` presentation;
3. repeat representative popouts with bottom, left, and right bar placement and confirm the growth direction is inward from the owning edge;
4. close a popout and confirm the body/iRiS field retract back into the source edge rather than disappearing immediately;
5. for a hover popout, move the pointer from the bar control across the connected seam into the popup body and confirm it stays open;
6. at fractional scaling, inspect the source/body join for a transparent one-pixel seam, residual wedge, or closing sliver;
7. verify clicks in transparent areas outside the visible popup shape are not captured by the full-output host window;
8. verify expanded Media still receives keyboard focus/Escape correctly on the compositor in use;
9. restart with a legacy non-zero `bar.cornerStyle` and verify it normalizes to `0`, the Bar remains Hug, and Settings does not offer Float/Rectangle/Card;
10. restart with a legacy `dock.style` value and verify the persisted value is normalized to `panel` and only Panel UI is shown;
11. verify Waffle behavior is unchanged and is not presented as a Dock style;
12. restart with a legacy `language.ui` value and verify the shell remains English and normalizes it to `en_US`.

The retired full `iiPerimeter` composition must remain absent. Local acceptance should validate the supported connected-surface primitives and feature-owned bridges instead of treating the old runtime as an alternate path.


## Legacy corner retirement

`ConnectedSurfaceJoinFlares`, `PerimeterCornerShadow`, common `RoundCorner`
and fake screen-rounding paint are retired. Sidebar/Dashboard/Settings use the
shared iRiS edge adapter where curved contact is required; remaining
non-cutover surfaces use direct square seams. Do not restore a standalone
round-wedge painter.
