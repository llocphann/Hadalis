# Codebase Structure

## Directory Layout

```text
inir/
├── shell.qml                     # Root entry — loads services and selects panel family
├── ShellIiPanels.qml             # Material ii panel family
├── ShellWafflePanels.qml         # Windows 11 panel family
├── GlobalStates.qml              # Runtime UI state
├── FamilyTransitionOverlay.qml   # Animated family switch
├── settings.qml                  # Settings GUI
├── waffleSettings.qml            # Waffle-specific settings GUI
├── welcome.qml                   # First-run wizard
├── killDialog.qml                # Process kill confirmation
├── modules/
│   ├── common/                   # Shared infrastructure
│   │   ├── Appearance.qml        # ii visual tokens
│   │   ├── Config.qml            # Central JsonAdapter config
│   │   ├── perimeter/            # Connected Perimeter core substrate
│   │   └── widgets/              # Reusable widgets + qmldir
│   ├── bar/                      # Classic Bar runtime
│   ├── background/               # Wallpaper + desktop widgets/items
│   ├── sidebarLeft/              # AI chat, music, widgets
│   ├── sidebarRight/             # Toggles, calendar, tools
│   ├── settings/                 # Config UI pages
│   ├── dock/                     # App dock
│   ├── overview/                 # Workspace overview + app search/task view
│   ├── wallpaperLauncher/        # Compact wallpaper carousel
│   ├── waffle/                   # Windows 11 family
│   │   ├── bar/                  # Bottom taskbar
│   │   ├── startMenu/            # Start menu with search
│   │   ├── actionCenter/         # Quick settings
│   │   ├── notificationCenter/   # Notification list + calendar
│   │   └── looks/Looks.qml       # Waffle visual tokens
│   ├── ii/                       # ii-family overlay/sidebar components
│   └── ...
├── services/                     # Runtime singletons (+ deferred services)
├── scripts/                      # Shell/fish/python helpers
├── sdata/                        # Install/update lifecycle and migrations
├── defaults/                     # Shipped default configuration/templates
├── translations/                 # i18n catalogs and maintenance tools
├── distro/                       # Packaging/distribution data
├── assets/                       # Icons, wallpapers, systemd unit, desktop entry
└── docs/                         # User documentation
```

The live tree intentionally has no Orbit, Mascot, Workspace Strip, `barM3`, Pill-Bar, Islands-Bar, Scenic-Bar, or Frame-Bar module directory. Those systems are retired, not optional renderers.

## Directory Purposes

**modules/:** all UI modules organized by panel family and feature area.

**modules/common/:** shared config, visual infrastructure, perimeter infrastructure, and reusable widgets. `Config.qml` owns the typed runtime schema and the custom-widget persistence workaround.

**modules/common/perimeter/:** Connected Perimeter core substrate: topology and slot configuration, module registry/hosting, anchor publication/lookup, transient-surface routing, and connected geometry/input helpers. Core presence does not mean every shell module or popup has already migrated to it; feature integration remains incremental.

**modules/bar/:** the sole ii-family Bar implementation. It supports top/bottom/left/right placement and Classic geometry modes (Hug, Float, Rectangle, Card). There is no Bar appearance-family selector.

**modules/waffle/:** Windows 11-style panel family with its own bottom taskbar, Start menu, action center, notification center, visual tokens, and settings. Waffle is a separate family rather than a Classic Bar appearance.

**modules/ii/:** ii-family-specific overlay/sidebar components.

**modules/background/:** per-output desktop surface, wallpaper renderer, desktop items, and desktop widgets.

**modules/overview/:** normal workspace overview/app search/task-view implementation. Orbit is not part of the live overview path.

**services/:** runtime singletons for audio, network, compositor IPC, theming, navigation, wallpaper, desktop layout, lyrics, and related backend behavior.

**scripts/:** CLI, theming, maintenance, and helper scripts.

**sdata/:** install/update lifecycle and append-only migration history.

**defaults/:** curated shipped defaults and platform/application templates.

**translations/:** JSON locale catalogs plus extraction/cleanup tooling. Translation keys come from live `Translation.tr(...)` call sites; retired-feature strings should not be kept merely for historical UI.

**assets/:** static icons, images, wallpapers, systemd units, desktop entries, and related packaged data.

**docs/:** user/developer Markdown documentation.

## Key File Locations

### Entry points
- `shell.qml` — root shell, services, IPC and family selection.
- `ShellIiPanels.qml` — ii-family loader.
- `ShellWafflePanels.qml` — Waffle-family loader.
- `settings.qml` — standalone Settings process/UI.
- `waffleSettings.qml` — Waffle settings.
- `welcome.qml` — first-run wizard.

### Configuration
- `modules/common/Config.qml` — typed `JsonAdapter` schema and persistence handling.
- `defaults/config.json` — curated default file.
- `Config.options.path.to.key` — runtime reads.
- `Config.setNestedValue("path.to.key", value)` — runtime writes.

Retired Bar keys such as `appearanceStyle`, `bar.m3`, `bar.pill`, and Bar-specific Islands state are not part of the live schema. Shared `m3*` Material color tokens, generic pill-shaped UI, and shared island skins remain valid where consumed by unrelated features.

### Classic Bar
- `modules/bar/` — Classic Bar runtime.
- `modules/settings/BarConfig.qml` — Classic Bar settings.
- `bar.bottom` + `bar.vertical` — placement.
- `bar.cornerStyle` — Hug/Float/Rectangle/Card geometry.
- `bar.blurBackground` — native compositor blur controls.
- `bar.autoHide.showWhenPressingSuper` — Super-key reveal behavior.

### Connected Perimeter core
- `modules/common/perimeter/PerimeterTopology.qml` — canonical edge/alignment slot topology.
- `modules/common/perimeter/PerimeterConfig.qml` — perimeter configuration adapter.
- `modules/common/perimeter/ModuleRegistry.qml` and `PerimeterModuleHost.qml` — module registration/hosting contract.
- `modules/common/perimeter/AnchorRegistry.qml` and `AnchorPublisher.qml` — rendered-anchor publication and lookup.
- `modules/common/perimeter/SurfaceRouteController.qml` — transient-surface route coordination.
- `modules/common/perimeter/ConnectedSurfaceGeometry.qml`, `ConnectedSurfaceFrame.qml`, `ConnectedSurfaceConnector.qml`, and `ConnectedSurfaceMask.qml` — shared connected geometry/render/input primitives.

These files are the shared substrate. Concrete Bar/Dock/Sidebar/module migration is allowed to remain incremental while the core contract stabilizes.

### Overview and task view
- `modules/overview/Overview.qml` — workspace/window overview and navigation.
- `GlobalStates.qml` — live task-view/overview state.
- `shell.qml` — `taskview` IPC route to the normal task-view state.

### Settings
- `modules/settings/SettingsPageRegistryData.qml` — page metadata/search data.
- `modules/settings/SettingsPageRegistry.qml` — page compatibility routing.
- Historical retired page indices remain hidden compatibility slots; TLP index 28 still redirects to System.

### Core services
- `modules/common/Appearance.qml` — ii visual tokens/style dispatch.
- `modules/waffle/looks/Looks.qml` — Waffle visual tokens.
- `services/DevNavigation.qml` — semantic dev navigation/IPC.
- `services/GlobalActions.qml` — global actions.
- `services/CompositorService.qml` — Niri/Hyprland detection.

### Tests/checks
- `.github/workflows/ci.yml` — repository CI definition.
- `scripts/test-local-distribution.sh` — local distribution test script.
- Translation tooling lives in `translations/tools/`.

## Naming Conventions

**Files**
- QML components: `PascalCase.qml`.
- Services: `PascalCase.qml`.
- Scripts: existing shell/python naming conventions in their owning directory.
- Config JSON: `config.json`.
- Translation files: `ll_CC.json`.

**Directories**
- Keep the established module names (`sidebarLeft/`, `sidebarRight/`, `actionCenter/`, etc.).
- Waffle-owned surfaces stay under `modules/waffle/`.
- Shared components belong under `modules/common/` only when they are genuinely family-independent.

## Where to Add New Code

**New shared QML component:** `modules/common/widgets/`.

**New module-specific component:** the owning live module directory.

**New service:** `services/` as a `PascalCase.qml` singleton, registered in `services/qmldir` when required.

**New script:** the appropriate existing `scripts/` category.

**New migration:** `sdata/migrations/` using the next sequential number. Existing migrations are append-only history.

**New config key:** update `modules/common/Config.qml`, every live consumer, and the owning Settings UI together; use `defaults/config.json` only for curated fresh-install differences.

**New translation:** wrap the live literal in `Translation.tr(...)`, then synchronize/audit locale catalogs.

**New Waffle component:** place it under `modules/waffle/` and keep its taskbar/settings contract separate from Classic Bar.

**New Classic Bar component:** place it under `modules/bar/`; do not introduce a renderer-family selector as part of ordinary Bar changes.

## Connected Perimeter Status

The live shell currently supports both the ii and Waffle panel families, while `dev` also contains the shared Connected Perimeter substrate under `modules/common/perimeter/`. Topology/config, module hosting, anchor routing and connected geometry/input primitives exist; migration of concrete modules and surfaces is incremental and must be judged from the live code rather than assumed complete.
