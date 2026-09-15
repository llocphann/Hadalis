# iNiR Architecture

> A complete desktop shell built on [Quickshell](https://quickshell.org/) for the [Niri](https://github.com/YaLTeR/niri) Wayland compositor.

**Version**: 2.29.3 · **Stack**: QML (Quickshell), Bash, Python, Go

Originally forked from [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland) (illogical-impulse). Secondary Hyprland support is maintained.

---

## Entry Point

`shell.qml` → `ShellRoot` (Quickshell-specific root, not Item/Window).

Startup flow:
1. Environment pragmas configure Qt scale, WebEngine, etc.
2. Singleton services force-instantiated via dummy property bindings.
3. `Config.ready` triggers panel loading.
4. Theme and icon services are applied via `Qt.callLater`.
5. Hyprsunset, first-run wizard, and conflict killer are loaded.

## Panel Families

Two mutually exclusive UI families are switchable at runtime (`Super+Shift+W`):

| | **Material ii** | **Waffle** |
|---|---|---|
| Active when | `panelFamily !== "waffle"` | `panelFamily === "waffle"` |
| Visual tokens | `Appearance.*` | `Looks.*` |
| Global styles | material, cards, aurora, inir, angel, zzz, cookie | Single fluent style |
| Bar | **Classic Bar only** — top/bottom/left/right; Hug/Float/Rectangle/Card geometry | Bottom Windows 11-style taskbar |
| App launcher | Overview | StartMenu with search |
| Right panel | SidebarRight | ActionCenter + NotificationCenter |
| Panels | ii (`iiBar`, `iiDock`, `iiSidebarLeft`, ...) | w (`wBar`, `wStartMenu`, `wActionCenter`, ... + shared ii panels) |

The retired Bar renderer families (Islands, Scenic, Frame, M3 and Pill) are not runtime alternatives. Shared `island`, `pill` and `m3*` names may still appear where they describe unrelated live skins, widget shapes, Material color tokens, or other non-Bar behavior.

Each panel uses `PanelLoader` (LazyLoader wrapper):
```qml
PanelLoader {
    identifier: "iiBar"
    extraCondition: !(Config.options?.bar?.vertical ?? false)
    component: Bar {}
}
```

A panel loads only when `Config.ready`, its identifier is present in `enabledPanels`, and its `extraCondition` is true.

Style dispatch priority is **cookie > zzz > angel > inir > aurora > material**. Cards is a material variant rather than a separate dispatch family.

## Directory Structure

```text
shell.qml                     # Root entry — loads services, selects panel family
ShellIiPanels.qml             # Material ii family
ShellWafflePanels.qml         # Windows 11 family
GlobalStates.qml              # Runtime UI state
FamilyTransitionOverlay.qml   # Animated family switch
settings.qml                  # Settings GUI
waffleSettings.qml            # Waffle-specific settings GUI
welcome.qml                   # First-run wizard
killDialog.qml                # Process kill confirmation

modules/
├── common/                   # Shared infrastructure
│   ├── Appearance.qml        # ii visual tokens
│   ├── Config.qml            # Central JsonAdapter config
│   ├── perimeter/            # Connected Perimeter core substrate
│   └── widgets/              # Reusable widgets + qmldir
├── bar/                      # Classic Bar runtime
├── background/               # Wallpaper + desktop widgets/items
├── sidebarLeft/              # AI chat, music, widgets
├── sidebarRight/             # Toggles, calendar, tools
├── settings/                 # Config UI pages
├── dock/                     # App dock
├── overview/                 # Workspace overview + app search
├── wallpaperLauncher/        # Compact wallpaper carousel
├── waffle/                   # Windows 11 family
│   ├── bar/                  # Bottom taskbar
│   ├── startMenu/            # Start menu with search
│   ├── actionCenter/         # Quick settings
│   ├── notificationCenter/   # Notification list + calendar
│   ├── looks/Looks.qml       # Waffle visual tokens
│   └── ...
└── ...

services/                     # Runtime singletons (+ services/deferred/)
scripts/                      # Shell/fish/python helpers
sdata/                        # Install/update lifecycle and migrations
defaults/                     # Shipped defaults
translations/                 # i18n catalogs
assets/                       # Icons, wallpapers, systemd unit, desktop entry
docs/                         # User documentation
```

Orbit, Mascot, Workspace Strip, and the retired Bar renderer modules are intentionally absent from the live module graph.

## Config System

| Aspect | Details |
|--------|---------|
| Schema | `modules/common/Config.qml` — `JsonAdapter` |
| Defaults | `defaults/config.json` |
| User file | `~/.config/illogical-impulse/config.json` (legacy namespace from fork origin) |
| Read | `Config.options.path.to.key` |
| Write | `Config.setNestedValue("path.to.key", value)` |
| Ready gate | `Config.ready` |
| Hot reload | `watchChanges: true` |
| Debounce | 50 ms for reads and writes |

When adding a live config key, update together:
1. `modules/common/Config.qml` schema/default.
2. Consumer(s).
3. Settings UI for the owning family.
4. `defaults/config.json` only when the curated fresh-install preference differs.

Unknown/stale JSON keys are not schema-backed runtime features and must not recreate retired surfaces. `Config.qml` also intentionally keeps the custom-widget persistence workaround outside the `JsonAdapter`; do not collapse `customWidgetData` into the adapter without re-validating the VME crash workaround.

## Classic Bar Baseline

`modules/bar/` is the only ii Bar runtime. `modules/settings/BarConfig.qml` configures the same runtime rather than choosing a renderer family.

Supported baseline behavior includes:
- top, bottom, left, and right placement through `bar.bottom` + `bar.vertical`;
- Hug, Float, Rectangle, and Card geometry through `bar.cornerStyle`;
- height, rounding, background opacity, borderless and float-shadow controls;
- native compositor blur through `bar.blurBackground`, gated by `performance.compositorBlur`;
- Classic audio spectrum settings;
- auto-hide, edge reveal, push-windows, and Super-key reveal (`bar.autoHide.showWhenPressingSuper`);
- clock, module order, workspaces, tray, resources, media, notifications, and utility modules.

Waffle remains a separate panel family with its own taskbar settings and is not a Classic Bar appearance.

## Key Singletons

| Singleton | Domain |
|-----------|--------|
| `Config` | Shell-wide config read/write |
| `Appearance` | ii/shared visual tokens |
| `Translation` | Shell-wide i18n lookup |
| `GlobalStates` | Panel visibility state |
| `DevNavigation` | Development-only semantic navigation |
| `Looks` | Waffle visual tokens |
| `NiriService` | Niri IPC, workspaces, windows |
| `Audio` | PipeWire volume/mute/mixer |
| `CompositorService` | Niri/Hyprland detection |
| `Weather` | Weather polling and location |
| `Network` | NetworkManager integration |
| `Wallpapers` | Wallpaper management and theming |
| `DesktopItems` | Desktop item persistence + undo |
| `DesktopWidgetLayout` | Per-output desktop-widget layout |
| `LyricsService` | Synchronized media lyrics |

Wallpaper pickers apply through `Wallpapers.applySelectionTarget()`. Live preview goes through `Wallpapers.previewWallpaper()` and does not write config or regenerate colors. `modules/background/Background.qml` owns the per-output desktop surface; desktop widget instances are mapped through `Config.options.background.widgets.outputOverrides`, `screenList`, and `layerOrder`.

These are stability boundaries: verify all dependents before reshaping them.

## Settings Compatibility

Settings page indices can be persisted externally, so retired slots remain compatibility concerns even when their UI is gone. The registry keeps retired indices hidden and redirects legacy selections instead of exposing the old feature pages. Historical TLP page index **28** continues to redirect to **System**.

This compatibility layer must never revive Orbit, Mascot, Workspace Strip, or a retired Bar renderer.

## IPC System

Handlers are registered with `IpcHandler { target: "name" }` and invoked with:

```text
inir <target> <function> [args]
```

The always-instantiated `dev` target provides session-only semantic navigation for lazy UI:
- `list()` — registered destinations as JSON;
- `open(destination)` — navigate to a named surface/view;
- `close()` — close navigable surfaces;
- `current()` — current destination or `"closed"`.

All IPC functions declare return types. Full reference: [docs/IPC.md](docs/IPC.md).

`taskview` remains a live shell route and maps to the normal Overview/task-view state; it is not an Orbit compatibility route.

## Theming Pipeline

Colors flow:

`wallpaper image → generate_colors_material.py → colors.json → MaterialThemeLoader → Appearance tokens → UI`

Theme generation is orchestrated by `scripts/colors/applycolor.sh`, which updates supported terminal, prompt, launcher, GTK, browser/editor and related application themes.

Names such as `m3primary`, `m3surface`, etc. are Material color-token identifiers and are not the retired M3 Bar renderer.

## Distribution

```bash
git clone https://github.com/snowarch/inir.git
cd inir
./setup
./setup install -y
./setup update
./setup doctor
./setup rollback
```

Two install modes are tracked in `version.json`:
- **Repo-sync**: `./setup install` → syncs to `~/.config/quickshell/inir/`.
- **Package-managed**: `make install` → copies to `/usr/share/quickshell/inir/`.

User config for running QML remains at `~/.config/illogical-impulse/config.json`. Shell scripts/CLI default to `~/.config/inir/` with a legacy fallback; those namespaces are not yet unified.

## Migrations

Migrations live under `sdata/migrations/`.
- append-only;
- idempotent;
- never rename/reorder/delete an existing migration;
- choose the next number from the current highest migration.

## Daily Development

```bash
inir run
inir restart
inir logs | tail -50
inir status
inir doctor
inir settings

inir <target> <function> [args...]
inir overview toggle
inir audio volumeUp
```

Never run raw `qs kill -c inir` / `qs -c inir` by hand. iNiR runs under `inir.service` (`systemd --user`); `inir restart` is the supported forced restart path.

## Connected Perimeter Status

The cleaned Classic-only shell remains the compatibility baseline. Current `dev` now contains the shared Connected Perimeter core under `modules/common/perimeter/`: topology/config, module registry/hosting, anchor publication/lookup, route coordination, and connected geometry/input primitives. Concrete module and transient-surface integration is incremental and should be assessed from the live implementation rather than assumed complete.

## Known Harmless Warnings

These log messages are safe to ignore:
- `Failed to create DBusObjectManagerInterface for "org.bluez"` — no Bluetooth adapter;
- `failed to register listener: ...PolicyKit1...` — another polkit agent running;
- `QSGPlainTexture: Mipmap settings changed` — Qt cosmetic;
- `Cannot open: file:///...coverart/...` — missing album-art cache;
- `$HYPRLAND_INSTANCE_SIGNATURE is unset` — expected when running on Niri.
