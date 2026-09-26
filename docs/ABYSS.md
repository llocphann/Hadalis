# Abyss — Perimeter Liquid Shell

## Phase 0 audit

Audit baseline: `b66aaf32037e7fe7436fc4f0f3a3a3d16ff78e61` on `dev`.
The desktop concept is a geometry reference; its wallpaper, labels and cyan
palette are not data or configuration requirements.

The repository was surveyed across entry points, modules, services, defaults,
install/update and packaging paths, documentation and regression scripts.
Focused reads covered:

- `shell.qml`, `GlobalStates.qml`, `FamilyTransitionOverlay.qml`,
  `ShellIiPanels.qml`, `ShellWafflePanels.qml`, both critical compositions and
  `modules/ii/ShellIiPanelsImpl.qml`;
- `Config.qml`, `Directories.qml`, settings registry, Modules, Bar, Dock,
  welcome profiles and family-related service/CLI consumers;
- `ScreenEdges.qml`, `ScreenCorners.qml`, `docs/PERIMETER.md`, the common
  perimeter manifests, iRiS field adapter/shader, Bar/BarContent/Workspaces,
  Dock/DockApps and SidebarHost;
- ResourceUsage demand leases, MPRIS, Notifications, clipboard model,
  TaskbarApps/AppSearch, Niri workspace/output APIs, GameMode and theme pipeline;
- canonical maintainer validator, family/critical isolation, input lifecycle,
  perimeter, module manifests, startup, IPC generation and packaging contracts.

Findings:

1. Families currently enter through URL-based critical/deferred loaders. Several
   ii boundaries use `!== waffle`; a third family requires explicit selection.
2. Material's physical Screen Edge is geometry-locked. It paints one rounded
   workspace hole per output and reserves work area with transparent windows.
   Its painter, corners, insets and fullscreen mapping must remain unchanged.
3. The existing connected field wraps upstream iRiS. It joins separately owned
   overlay bodies and crops their paint at owner boundaries. Abyss needs a
   different composition: one final silhouette for all perimeter deformations.
4. Common IPC routers already live in the root. No new presentation component
   should register an existing target. Shared critical flows can be source-loaded
   behind Abyss panel IDs rather than copied.
5. Bar presets provide five zones in both orientations. Services and app/workspace
   identity are reusable; Material pill hosts and surface painters are not.
6. Expanded overlays must reserve zero space. Input must be the union of actual
   content rectangles, with the workspace hole excluded. Closing content must
   immediately release its input region, even while geometry retracts.
7. Resource polling is demand-driven. New consumers must balance keepAlive and
   releaseKeepAlive. Geometry/effect state must be stable at rest.
8. Local validation is authoritative for source contracts. Actual output hotplug,
   mixed DPI, suspend and desktop interactions require separate runtime evidence.

## Implementation plan

1. Add the `abyss` family boundary, safe lazy tree, panel IDs, migration,
   selection and a short input-free transition. Keep `ii` as the default and
   normalize unknown families to `ii`.
2. Prove a single deterministic SDF silhouette using one shared ShaderEffect.
   Intersecting perpendicular deformations require a real union; a sampled
   Shape contour would need an additional boolean-geometry implementation.
   Subtract one rounded workspace opening from the screen; deform that opening
   for edge-attached content. One silhouette owns fill, rim and optional shadow.
   Transparent reservations remain separate from the visual host.
3. Embed an Abyss-owned five-zone bar and reuse workspace, tray, media, weather,
   battery and system models through plain content controls.
4. Add dock retraction, one connected popup and sidebars through the same contour
   records. Validate their union before adding effects or secondary surfaces.
5. Add demand-loaded clipboard/launcher/notification content and transient OSD
   records; retain documented shared fallbacks for critical and specialist flows.
6. Add bounded motion, palette-derived material tokens, performance presets and
   focused settings. Real backdrop refraction requires evidence; an honest static
   absorption/specular fallback takes precedence over an expensive unproven pass.
7. Run behavioral geometry/family tests, parser/module checks, runtime captures
   and the canonical validator on the final committed SHA. Record each milestone
   and distinguish source validation from environment acceptance.

Topology precedes interaction, legibility, motion, glass and glow. Abyss is not
an iRiS Island implementation. No Material tree duplication or corner patches
are part of this plan.


## Foundation checkpoint (phases 1–2)

- Family skeleton: `69c90e79f`, pushed to `dev`. Three-family policy tests and
  existing transition/critical isolation tests pass. Qt 6.11.2 parses the new tree.
- Native foundation: original `AbyssField.frag(.qsb)`, `AbyssGeometry.js`,
  `AbyssStyle.qml`, `AbyssPerimeter.qml` and the Abyss critical entry. Config gains
  an isolated `abyss.*` namespace; existing palettes and Material geometry stay intact.
- Visual: [actual GPU topology capture](evidence/abyss/phase2-topology.png),
  Quickshell 0.3.1 / Wayland / OpenGL, 1100 × 700 logical pixels. The shader reports
  compiled. Perimeter, popup, sidebar and dock share one silhouette and shadow.
  This is a renderer capture, not multi-monitor or full desktop acceptance.
- Input: foundation host and reservation windows have empty input masks and no
  keyboard focus. Expanded content will add bounded regions in the next milestone.
- Geometry tests execute the production JS for four bar/dock directions and
  scales 1, 1.25, 1.5 and 2. Opposing deformations preserve the workspace center.
- A perpendicular placement rule keeps popup/dock content out of sidebars. It
  also prevents intersecting panels sealing an isolated corner workspace pocket.
  The renderer still computes the union; this is content placement, not corner paint.
- Idle: no timer or time uniform in the field; geometry and color bindings are
  unchanged at rest. One ShaderEffect per output, no per-module texture passes.
- Baseline validator on `b66aaf3` found pre-existing stale `IslandPanel` and update
  availability assertions (the latter also fails the aggregate distribution test).
  Baseline is not green. Parser probing also skipped because `/usr/bin/qmlformat`
  version detection fails; the explicit `/usr/lib/qt6/bin/qmlformat` parser works.
- Next: embedded content, bounded input, native bar, dock, sidebar and popup.


## Embedded bar checkpoint (phase 3)

Inspected the two orientation presets, workspace IDs/output resolution, tray
interaction, MPRIS metadata and resource polling leases. Added `abyss/bar/*` and
`AbyssButton`; the perimeter now hosts bar content and its five shallow bulges.
Shared services are reused and no bar module owns a surface background. The
transparent reservation includes the maximum 5 px bar bulge. Only the actual
bar bounds receive input; the center stays empty.

[GPU bar capture](evidence/abyss/phase3-bar.png) uses actual workspace, tray,
MPRIS and clock data. Runtime testing caught a final `AbstractButton.icon`
collision, then an `onSurface` token initialized as a handler-shaped name rather
than the intended color. The API now uses `textColor`/`textColorMuted`; the runtime
measured text contrast is 16.40:1 against the deep surface. Qt fonts and palette
are inherited. Five-zone ordering/deduplication/visibility use the tested pure
geometry policy. Resource consumers release their lease when hidden or destroyed.

A pre-existing `DateTime.qml` missing-root-id warning was exposed by the capture
and remains queued for an independent correction. Sidebar, dock and popup
content are the next milestone; this checkpoint does not claim functional core
acceptance yet. Native tray menus deliberately keep the existing shared control.


## Connected content checkpoint (phases 4–6)

Inspected DockApps/TaskbarApps and sorting demand, physical sidebar role routing,
MPRIS controls, brightness output resolution, Cliphist pin/copy/delete contracts
and LauncherSearch actions. `AbyssBodyHost` supplies a deformation record and a
clipped content rectangle without painting a body. `AbyssPerimeter` consumes all
records in the same field and unions only live content input rectangles.

- [Dock capture](evidence/abyss/phase4-dock.png): pinned/running app icons and
  launcher grow from the selected edge; right click toggles pinning through the
  existing service. No dock background, gap or second shadow is painted.
- [Sidebar capture](evidence/abyss/phase5-sidebar.png): shared CPU/RAM/GPU/storage,
  output brightness, audio, Wi-Fi/Bluetooth/DND, media, locations and weather
  appear as typography and fine separators inside a right-edge deformation.
- [Popup capture](evidence/abyss/phase6-popup.png): bar-origin media, sidebar and
  dock share one silhouette. Perpendicular placement keeps content and the
  workspace opening connected. Calendar/resources/weather/battery/audio use the
  same host, with content loaded only for the chosen kind.
- Tools navigation is native. AI chat and local music deliberately use the
  existing content implementation when their tabs are requested. These are
  specialist content fallbacks, not separately owned Material shell panels.
- Native clipboard reuses Cliphist history, search, text pins, copy/delete and
  two-step clear. Native launcher reuses LauncherSearch actions/prefixes and
  AppSearch, with output-local workspaces/window activation. Both enter through
  the bottom deformation and demand-load their existing deferred services.
- Every host releases input immediately on close while its contour retracts.
  Wayland runtime recorded live bounded rectangles and `0×0` for all closed
  hosts. Loader bodies were ready for dock, system sidebar, popup, launcher and
  clipboard. This does not substitute for manual click/drag/fullscreen acceptance.
- Bar auto-hide and dock edge reveal have thin bounded triggers and finite close
  timers. Dock sorting and resources use balanced demand leases. Body motion is
  bounded and observes disabled animations.

Qt 6.11.2 parsed the new QML. Production geometry and family tests pass. Real GPU
captures caught missing deferred-service imports, which are corrected. Existing
DateTime root-id and TaskbarApps initial binding-loop diagnostics remain under
review; the second notification-server warning comes from running the capture
alongside the installed shell. No notification backend is duplicated in Abyss.
Next: native notifications/OSD, effects, settings integration and complete local
validation. Full desktop and multi-output acceptance remain outstanding.
