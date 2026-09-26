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
2. Prove a single deterministic contour using Qt Quick Shape/CurveRenderer.
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
